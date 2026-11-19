import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';

/// صفحة إضافة فئة جديدة
class CreateCategoryPage extends StatefulWidget {
  const CreateCategoryPage({super.key});

  @override
  State<CreateCategoryPage> createState() => _CreateCategoryPageState();
}

class _CreateCategoryPageState extends State<CreateCategoryPage>
    with SaveOperationMixin<CreateCategoryPage> {
  // حماية من الحفظ المتكرر
  bool _operationCompleted = false;

  final FormattingService _formattingService = FormattingService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  String? _selectedParentId;
  String? _selectedColor;
  String? _selectedIcon;
  bool _isActive = true;
  List<CategoryEntity> _parentCategories = [];

  // قائمة الألوان المتاحة
  final List<Map<String, dynamic>> _availableColors = [
    {'name': 'أزرق', 'value': '#2196F3', 'color': Colors.blue},
    {'name': 'أخضر', 'value': '#4CAF50', 'color': Colors.green},
    {'name': 'أحمر', 'value': '#F44336', 'color': Colors.red},
    {'name': 'برتقالي', 'value': '#FF9800', 'color': Colors.orange},
    {'name': 'بنفسجي', 'value': '#9C27B0', 'color': Colors.purple},
    {'name': 'وردي', 'value': '#E91E63', 'color': Colors.pink},
    {'name': 'بني', 'value': '#795548', 'color': Colors.brown},
    {'name': 'رمادي', 'value': '#9E9E9E', 'color': Colors.grey},
  ];

  // قائمة الأيقونات المتاحة
  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'فئة عامة', 'value': 'category', 'icon': Icons.category},
    {'name': 'طعام', 'value': 'restaurant', 'icon': Icons.restaurant},
    {'name': 'ملابس', 'value': 'checkroom', 'icon': Icons.checkroom},
    {'name': 'إلكترونيات', 'value': 'devices', 'icon': Icons.devices},
    {'name': 'كتب', 'value': 'book', 'icon': Icons.book},
    {'name': 'رياضة', 'value': 'sports', 'icon': Icons.sports},
    {'name': 'منزل', 'value': 'home', 'icon': Icons.home},
    {'name': 'سيارات', 'value': 'directions_car', 'icon': Icons.directions_car},
  ];

  @override
  void initState() {
    super.initState();
    _loadParentCategories();
  }

  void _loadParentCategories() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<InventoryBloc>().add(
        LoadCategories(organizationEmail: user.email!, isActive: true),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InventoryDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listenWhen: (previous, current) {
          return current is InventoryError ||
              (current is InventoryLoaded && isSaving);
        },
        listener: (context, state) {
          if (state is InventoryLoaded && !_operationCompleted) {
            // تحديث قائمة الفئات الرئيسية
            setState(() {
              _parentCategories = state.categories
                  .where((cat) => cat.isMainCategory)
                  .toList();
            });

            // إذا كنا في عملية حفظ، أكمل العملية بنجاح
            if (isSaving) {
              _operationCompleted = true;
              completeSaveOperation(
                successMessage: 'تم إنشاء الفئة بنجاح',
                navigateBackOnSuccess: true,
              );
            }
          } else if (state is InventoryError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                _buildWelcomeCard(context),
                const SizedBox(height: 6),
                _buildFormCard(context),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
                  'إضافة فئة جديدة',
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
                  'نظام إدارة المخزن الآشوري',
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
      title: 'إضافة فئة جديدة',
      subtitle: 'إنشاء فئة جديدة وإضافتها إلى قاعدة البيانات',
      icon: Icons.category_outlined,
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
            title: 'المعلومات الأساسية',
            icon: Icons.info_outline,
            children: [
              _buildNameField(),
              _buildDescriptionField(),
              _buildParentCategoryField(),
            ],
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'التخصيص',
            icon: Icons.palette,
            children: [
              _buildColorField(),
              _buildIconField(),
              _buildSortOrderField(),
            ],
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'الإعدادات',
            icon: Icons.settings,
            children: [_buildActiveSwitch()],
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'اسم الفئة *',
        hintText: 'أدخل اسم الفئة',
        prefixIcon: const Icon(
          Icons.category,
          color: AssyrianTheme.primaryGold,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يجب إدخال اسم الفئة';
        }
        if (value.trim().length < 2) {
          return 'يجب أن يكون اسم الفئة أكثر من حرف واحد';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'الوصف',
        hintText: 'أدخل وصف الفئة (اختياري)',
        prefixIcon: const Icon(
          Icons.description,
          color: AssyrianTheme.primaryGold,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildParentCategoryField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedParentId,
      decoration: InputDecoration(
        labelText: 'الفئة الرئيسية',
        hintText: 'اختر الفئة الرئيسية (اختياري)',
        prefixIcon: const Icon(Icons.folder, color: AssyrianTheme.primaryGold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
      items: [
        const DropdownMenuItem<String>(child: Text('فئة رئيسية')),
        ..._parentCategories.map(
          (category) => DropdownMenuItem<String>(
            value: category.id,
            child: Text(category.name),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedParentId = value;
        });
      },
    );
  }

  Widget _buildColorField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اللون',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableColors.map((colorData) {
              final isSelected = _selectedColor == colorData['value'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = isSelected ? null : colorData['value'];
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorData['color'],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AssyrianTheme.deepBlue
                          : Colors.grey.withValues(alpha: 0.3),
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 20.sp)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIconField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الأيقونة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableIcons.map((iconData) {
              final isSelected = _selectedIcon == iconData['value'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIcon = isSelected ? null : iconData['value'];
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AssyrianTheme.primaryGold
                          : Colors.grey.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    iconData['icon'],
                    color: isSelected
                        ? AssyrianTheme.primaryGold
                        : Colors.grey[600],
                    size: 24.sp,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortOrderField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: _sortOrderController,
        keyboardType: TextInputType.number,
        inputFormatters: [_formattingService.getQuantityInputFormatter()],
        decoration: InputDecoration(
          labelText: 'ترتيب العرض',
          hintText: 'أدخل رقم الترتيب',
          prefixIcon: const Icon(Icons.sort, color: AssyrianTheme.primaryGold),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AssyrianTheme.primaryGold,
              width: 2,
            ),
          ),
        ),
        validator: (value) {
          if (value != null && value.isNotEmpty) {
            final number = int.tryParse(value.replaceAll(',', ''));
            if (number == null) {
              return 'يجب إدخال رقم صحيح';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildActiveSwitch() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          const Icon(Icons.toggle_on, color: AssyrianTheme.primaryGold),
          const SizedBox(width: 8),
          Text(
            'فئة نشطة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          const Spacer(),
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

  Widget _buildSubmitButton() {
    return Row(
      children: [
        Expanded(
          child: LoadingButton(
            text: 'إنشاء الفئة',
            onPressed: isSaving ? null : _createCategory,
            isLoading: isSaving,
            icon: Icons.add,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : () => Navigator.of(context).pop(),
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
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createCategory() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // الحصول على UID الخاص بالمستخدم
    String createdBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdBy = switchedUser['id'] as String;
      } else {
        createdBy = currentUser.uid;
      }
    } on Exception catch (_) {
      createdBy = currentUser.uid;
    }

    final category = CategoryEntity(
      id: '', // سيتم إنشاؤه تلقائياً
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      parentId: _selectedParentId,
      color: _selectedColor,
      icon: _selectedIcon,
      sortOrder:
          int.tryParse(_sortOrderController.text.trim().replaceAll(',', '')) ??
          0,
      isActive: _isActive,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      organizationEmail: currentUser.email!,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ InventoryBloc قبل العملية غير المتزامنة
    final inventoryBloc = context.read<InventoryBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        inventoryBloc.add(CreateCategory(category: category));
      },
      successMessage: 'تم إنشاء الفئة بنجاح',
      loadingMessage: 'جاري إنشاء الفئة...',
    );
  }
}
