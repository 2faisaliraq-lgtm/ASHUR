import 'dart:async';

import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';

/// صفحة تعديل منتج
class EditProductPage extends StatefulWidget {
  const EditProductPage({required this.product, super.key});
  final ProductEntity product;

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage>
    with SaveOperationMixin<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _minQuantityController;
  late final TextEditingController _maxQuantityController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellingPriceController;

  late String? _selectedCategoryId;
  late String? _selectedShelfId;
  late String _selectedUnit;
  late bool _trackQuantity;
  late bool _isActive;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // LayerLink و GlobalKey لعرض Overlay مقترحات
  final LayerLink _nameLayerLink = LayerLink();
  final GlobalKey _nameFieldKey = GlobalKey();

  // متغيرات البحث والمقترحات
  List<ProductEntity> _suggestedProducts = [];
  List<ProductEntity> _allProducts = [];
  bool _isSearchingNames = false;
  bool _hasSearchedNames = false;
  final FocusNode _nameFocusNode = FocusNode();
  Timer? _nameDebounceTimer;

  final List<String> _units = [
    'قطعة',
    'كيلوغرام',
    'غرام',
    'لتر',
    'ملليلتر',
    'متر',
    'سنتيمتر',
    'صندوق',
    'علبة',
  ];

  @override
  void initState() {
    super.initState();
    // تهيئة الحقول بقيم المنتج الحالي
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(
      text: widget.product.description ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.product.barcode ?? '',
    );
    _quantityController = TextEditingController(
      text: _formattingService.formatStockQuantity(
        widget.product.quantity.round(),
      ),
    );
    _minQuantityController = TextEditingController(
      text: _formattingService.formatStockQuantity(
        widget.product.minQuantity.round(),
      ),
    );
    _maxQuantityController = TextEditingController(
      text: widget.product.maxQuantity != null
          ? _formattingService.formatStockQuantity(
              widget.product.maxQuantity!.round(),
            )
          : '',
    );
    _costPriceController = TextEditingController(
      text: widget.product.costPrice != null
          ? _formattingService.formatNumber(widget.product.costPrice!)
          : '',
    );
    _sellingPriceController = TextEditingController(
      text: _formattingService.formatProductPrice(widget.product.sellingPrice),
    );

    _selectedCategoryId = widget.product.categoryId;
    _selectedShelfId = widget.product.shelfId;
    _selectedUnit = widget.product.unit;
    _trackQuantity = widget.product.trackQuantity;
    _isActive = widget.product.isActive;

    _nameController.addListener(_onNameChanged);

    // إخفاء المقترحات عند فقدان التركيز
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && mounted) {
        _hideNameSuggestionsOverlay();
      }
    });

    // تحميل الفئات
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      context.read<InventoryBloc>().add(
        LoadCategories(organizationEmail: currentUser.email!),
      );
    }
  }

  @override
  void dispose() {
    _hideNameSuggestionsOverlay();
    _nameDebounceTimer?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    _maxQuantityController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  // دوال عرض وإخفاء الاقتراحات باستخدام SuggestionsOverlay
  void _showNameSuggestionsOverlay() {
    if (_suggestedProducts.isEmpty || !_nameFocusNode.hasFocus) return;

    SuggestionsOverlay.hide();

    final suggestions = _suggestedProducts
        .take(5)
        .map(
          (product) => product.toProductSuggestionItem(
            formatCurrency: _formattingService.formatCurrency,
          ),
        )
        .toList();

    SuggestionsOverlay.show(
      context: context,
      layerLink: _nameLayerLink,
      anchorKey: _nameFieldKey,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        _nameController.text = value;
        SuggestionsOverlay.hide();
      },
      maxHeight: 100.h,
    );
  }

  void _hideNameSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  void _onNameChanged() {
    _nameDebounceTimer?.cancel();
    _nameDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      _searchProductNames,
    );
  }

  Future<void> _searchProductNames() async {
    final query = _nameController.text.trim();

    // البحث بعد كتابة حرف واحد على الأقل
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _suggestedProducts = [];
          _isSearchingNames = false;
        });
      }
      _hideNameSuggestionsOverlay();
      return;
    }

    // إذا لم يتم البحث من قبل، نحصل على جميع المنتجات من InventoryBloc
    if (!_hasSearchedNames) {
      if (mounted) {
        setState(() {
          _isSearchingNames = true;
        });
      }

      try {
        final bloc = context.read<InventoryBloc>();
        final repository = bloc.repository;

        // جلب المنتجات من الـ repository مباشرة
        final result = await repository.getProducts(
          organizationEmail: FirebaseAuth.instance.currentUser!.email!,
        );

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _allProducts = [];
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
            }
          },
          (products) {
            if (mounted) {
              setState(() {
                _allProducts = products
                    .where((product) => product.name != widget.product.name)
                    .toList();
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
              // تصفية النتائج بناءً على النص المكتوب
              _filterProducts(query);
            }
          },
        );
      } on Exception catch (_) {
        if (mounted) {
          setState(() {
            _allProducts = [];
            _hasSearchedNames = true;
            _isSearchingNames = false;
          });
        }
      }
    } else {
      // تصفية النتائج محلياً
      _filterProducts(query);
    }
  }

  void _filterProducts(String query) {
    // ⚠️ أداء (تحقق يدوي 2026-10-12): queryLower مُخرَجة
    // من اللامدا — تُحسب مرة واحدة بدلاً من تكرارها لكل
    // منتج (نص ثابت لا يتغير) فالنتيجة متطابقة تماماً
    // والفلترة أسرع. لا تُعيد إدخالها داخل اللامدا.
    final queryLower = query.toLowerCase();
    final filtered = _allProducts
        .where(
          (product) =>
              product.name.toLowerCase().contains(queryLower) ||
              (product.barcode?.toLowerCase().contains(queryLower) ?? false),
        )
        .toList();

    if (mounted) {
      setState(() {
        _suggestedProducts = filtered;
        _isSearchingNames = false;
      });

      if (filtered.isNotEmpty && _nameFocusNode.hasFocus) {
        _showNameSuggestionsOverlay();
      } else {
        _hideNameSuggestionsOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const InventoryDrawer(currentRoute: AppRoutes.inventory),
      body: BlocListener<InventoryBloc, InventoryState>(
        listenWhen: (previous, current) {
          return current is InventoryOperationSuccess ||
              current is InventoryError ||
              (current is InventoryLoaded && current.error != null);
        },
        listener: (context, state) {
          if (state is InventoryLoaded &&
              state.error != null &&
              !_operationCompleted) {
            failSaveOperation(errorMessage: state.error!);
          } else if (state is InventoryOperationSuccess &&
              isSaving &&
              !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: 'تم تحديث المنتج بنجاح',
              navigateBackOnSuccess: true,
            );
          } else if (state is InventoryError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [_buildWelcomeCard(context), _buildFormCard(context)],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
          boxShadow: [
            BoxShadow(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          AssyrianTheme.getLamassuForBackground(
            isDarkBackground: true,
            hasCircularBackground: false,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعديل منتج',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'نظام إدارة المخزون الآشوري',
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 10,
                    ),
                    color: AssyrianTheme.ivoryWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return const DetailScreenHeader(
      title: 'تعديل منتج',
      subtitle: 'تحديث معلومات المنتج',
      icon: Icons.edit,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'معلومات المنتج',
            icon: Icons.info_outline,
            children: [
              _buildNameFieldWithSuggestions(),
              _buildTextField(
                controller: _descriptionController,
                label: 'الوصف (اختياري)',
                icon: Icons.description,
                maxLines: 3,
              ),
              _buildTextField(
                controller: _barcodeController,
                label: 'الباركود (اختياري)',
                icon: Icons.qr_code,
              ),
              _buildCategoryDropdown(),
              _buildShelfDropdown(),
              _buildUnitDropdown(),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'معلومات الكمية',
            icon: Icons.inventory_2,
            children: [
              _buildTrackQuantitySwitch(),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _quantityController,
                      label: 'الكمية الحالية *',
                      icon: Icons.inventory,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getQuantityInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الكمية مطلوبة';
                        }
                        if (double.tryParse(value.replaceAll(',', '')) ==
                            null) {
                          return 'أدخل رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildTextField(
                      controller: _minQuantityController,
                      label: 'الحد الأدنى *',
                      icon: Icons.warning,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getQuantityInputFormatter(),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الحد الأدنى مطلوب';
                        }
                        if (double.tryParse(value.replaceAll(',', '')) ==
                            null) {
                          return 'أدخل رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              _buildTextField(
                controller: _maxQuantityController,
                label: 'الحد الأقصى (اختياري)',
                icon: Icons.trending_up,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  _formattingService.getQuantityInputFormatter(),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'معلومات السعر',
            icon: Icons.attach_money,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _costPriceController,
                      label: 'سعر التكلفة (اختياري)',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getPriceInputFormatter(),
                      ],
                      suffixText: 'د.ع',
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildTextField(
                      controller: _sellingPriceController,
                      label: 'سعر البيع *',
                      icon: Icons.sell,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getPriceInputFormatter(),
                      ],
                      suffixText: 'د.ع',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'سعر البيع مطلوب';
                        }
                        if (double.tryParse(value.replaceAll(',', '')) ==
                            null) {
                          return 'أدخل رقم صحيح';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              _buildActiveSwitch(),
            ],
          ),
          SizedBox(height: 24.h),
          BlocBuilder<InventoryBloc, InventoryState>(
            builder: (context, state) {
              final isLoading =
                  state is InventoryLoading ||
                  (state is InventoryLoaded && state.isCreatingProduct);
              return Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      text: 'حفظ التعديلات',
                      onPressed: _updateProduct,
                      isLoading: isLoading,
                      icon: Icons.save,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AssyrianTheme.deepBlue,
                        side: const BorderSide(color: AssyrianTheme.deepBlue),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNameFieldWithSuggestions() {
    final hasExactMatch =
        _nameController.text.isNotEmpty &&
        _suggestedProducts.any(
          (product) => product.name == _nameController.text.trim(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _nameLayerLink,
          child: TextFormField(
            key: _nameFieldKey,
            controller: _nameController,
            focusNode: _nameFocusNode,
            decoration: InputDecoration(
              labelText: 'اسم المنتج *',
              prefixIcon: Icon(
                Icons.inventory_2,
                size: 20.sp,
                color: AssyrianTheme.primaryGold,
              ),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 20.sp),
                      onPressed: () {
                        _nameController.clear();
                        _hideNameSuggestionsOverlay();
                        _suggestedProducts = [];
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(
                  color: hasExactMatch
                      ? Colors.orange.shade400
                      : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  width: hasExactMatch ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(
                  color: hasExactMatch
                      ? Colors.orange.shade400
                      : AssyrianTheme.primaryGold,
                  width: hasExactMatch ? 1.5 : 1,
                ),
              ),
              labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'اسم المنتج مطلوب';
              }
              return null;
            },
          ),
        ),

        // مؤشر التحميل
        if (_isSearchingNames && _nameController.text.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              children: [
                SizedBox(width: 16.w, height: 16.h, child: LoadingWidget()),
                SizedBox(width: 8.w),
                Text(
                  'جاري البحث...',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

        // تحذير المطابقة التامة
        if (hasExactMatch)
          Container(
            margin: EdgeInsets.only(top: 8.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.orange.shade400, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.orange.shade800,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'تحذير: لا يمكن استخدام هذا الاسم!',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  'يوجد منتج آخر بنفس الاسم:',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.orange.shade900,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.orange.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block,
                        size: 14.sp,
                        color: Colors.orange.shade800,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _nameController.text.trim(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
        ),
        labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        var categories = [];

        if (state is InventoryLoaded) {
          categories = state.categories;
        }

        return DropdownButtonFormField<String>(
          initialValue: categories.any((cat) => cat.id == _selectedCategoryId)
              ? _selectedCategoryId
              : null,
          decoration: InputDecoration(
            labelText: 'الفئة *',
            prefixIcon: Icon(
              Icons.category,
              size: 20.sp,
              color: AssyrianTheme.primaryGold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
            ),
            labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
          ),
          items: categories.map((category) {
            return DropdownMenuItem<String>(
              value: category.id,
              child: Text(category.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الفئة مطلوبة';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildShelfDropdown() {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        var shelves = [];

        if (state is InventoryLoaded) {
          shelves = state.shelves ?? [];
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedShelfId,
          decoration: InputDecoration(
            labelText: 'الرف (اختياري)',
            prefixIcon: Icon(
              Icons.shelves,
              size: 20.sp,
              color: AssyrianTheme.primaryGold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
            ),
            labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
          ),
          items: [
            const DropdownMenuItem<String>(child: Text('بدون رف')),
            ...shelves.where((shelf) => shelf.isActive).map((shelf) {
              return DropdownMenuItem<String>(
                value: shelf.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(shelf.name, overflow: TextOverflow.ellipsis),
                    ),
                    if (shelf.zone != null) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          _formatZoneName(shelf.zone!),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AssyrianTheme.deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedShelfId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedUnit,
      decoration: InputDecoration(
        labelText: 'الوحدة *',
        prefixIcon: Icon(
          Icons.straighten,
          size: 20.sp,
          color: AssyrianTheme.primaryGold,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
        ),
        labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
      ),
      items: _units.map((unit) {
        return DropdownMenuItem<String>(value: unit, child: Text(unit));
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedUnit = value;
          });
        }
      },
    );
  }

  Widget _buildTrackQuantitySwitch() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.track_changes,
            size: 20.sp,
            color: AssyrianTheme.primaryGold,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تتبع الكمية',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'تفعيل تتبع كمية المنتج في المخزون',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _trackQuantity,
            onChanged: (value) {
              setState(() {
                _trackQuantity = value;
              });
            },
            activeTrackColor: AssyrianTheme.primaryGold,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSwitch() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 20.sp,
            color: AssyrianTheme.primaryGold,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'منتج نشط',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'المنتج متاح للبيع والعرض',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            activeTrackColor: AssyrianTheme.primaryGold,
          ),
        ],
      ),
    );
  }

  Future<void> _updateProduct() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار فئة للمنتج'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updatedProduct = widget.product.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      categoryId: _selectedCategoryId,
      shelfId: _selectedShelfId ?? widget.product.shelfId,
      quantity: double.parse(
        _quantityController.text.trim().replaceAll(',', ''),
      ),
      minQuantity: double.parse(
        _minQuantityController.text.trim().replaceAll(',', ''),
      ),
      maxQuantity: _maxQuantityController.text.trim().isEmpty
          ? null
          : double.parse(
              _maxQuantityController.text.trim().replaceAll(',', ''),
            ),
      unit: _selectedUnit,
      costPrice: _costPriceController.text.trim().isEmpty
          ? null
          : double.parse(_costPriceController.text.trim().replaceAll(',', '')),
      sellingPrice: double.parse(
        _sellingPriceController.text.trim().replaceAll(',', ''),
      ),
      isActive: _isActive,
      trackQuantity: _trackQuantity,
      updatedAt: DateTime.now(),
      updatedBy: currentUser.uid,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ InventoryBloc قبل العملية غير المتزامنة
    final inventoryBloc = context.read<InventoryBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        inventoryBloc.add(UpdateProduct(product: updatedProduct));
      },
      successMessage: 'تم تحديث المنتج بنجاح',
      loadingMessage: 'جاري تحديث المنتج...',
    );
  }

  /// تنسيق اسم المنطقة
  String _formatZoneName(String zoneId) {
    switch (zoneId) {
      case 'zone_a':
        return 'المنطقة أ';
      case 'zone_b':
        return 'المنطقة ب';
      case 'zone_c':
        return 'المنطقة ج';
      case 'zone_d':
        return 'المنطقة د';
      case 'storage':
        return 'مخزن';
      case 'display':
        return 'عرض';
      default:
        return zoneId;
    }
  }
}
