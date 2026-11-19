import 'dart:async';

import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/features_list_widget.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة تعديل نوع اشتراك
class EditSubscriptionTypePage extends StatefulWidget {
  const EditSubscriptionTypePage({required this.type, super.key});
  final SubscriptionTypeEntity type;

  @override
  State<EditSubscriptionTypePage> createState() =>
      _EditSubscriptionTypePageState();
}

class _EditSubscriptionTypePageState extends State<EditSubscriptionTypePage>
    with SaveOperationMixin<EditSubscriptionTypePage> {
  final _formKey = GlobalKey<FormState>();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  late String _selectedDuration;
  late List<String> _features;
  late bool _isActive;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // للمدة المخصصة
  late final TextEditingController _customDaysController;
  late bool _isCustomDuration;

  // LayerLink و GlobalKey لعرض Overlay مقترحات
  final LayerLink _nameLayerLink = LayerLink();
  final GlobalKey _nameFieldKey = GlobalKey();

  // متغيرات البحث والمقترحات
  List<String> _suggestedNames = [];
  List<String> _allSuggestedNames = [];
  bool _isSearchingNames = false;
  bool _hasSearchedNames = false;
  final FocusNode _nameFocusNode = FocusNode();
  Timer? _nameDebounceTimer;

  final List<String> _durations = [
    'daily',
    'weekly',
    'monthly',
    'quarterly',
    'yearly',
    'custom',
  ];

  final Map<String, String> _durationLabels = {
    'daily': 'يومي',
    'weekly': 'أسبوعي',
    'monthly': 'شهري',
    'quarterly': 'ربع سنوي',
    'yearly': 'سنوي',
    'custom': 'مخصص',
  };

  @override
  void initState() {
    super.initState();
    // تهيئة الحقول بقيم النوع الحالي
    _nameController = TextEditingController(text: widget.type.name);
    _descriptionController = TextEditingController(
      text: widget.type.description,
    );
    _priceController = TextEditingController(
      text: _formattingService.formatNumber(widget.type.price),
    );
    _customDaysController = TextEditingController(
      text: widget.type.customDays?.toString() ?? '',
    );

    _selectedDuration = _durations.contains(widget.type.duration)
        ? widget.type.duration
        : 'monthly';
    _isCustomDuration = _selectedDuration == 'custom';
    _features = List.from(widget.type.features);
    _isActive = widget.type.isActive;

    _nameController.addListener(_onNameChanged);

    // إخفاء المقترحات عند فقدان التركيز
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && mounted) {
        _hideNameSuggestionsOverlay();
      }
    });
  }

  @override
  void dispose() {
    SuggestionsOverlay.hide();
    _nameDebounceTimer?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _customDaysController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  // دوال عرض وإخفاء الاقتراحات باستخدام SuggestionsOverlay
  void _showNameSuggestionsOverlay() {
    if (_suggestedNames.isEmpty || !_nameFocusNode.hasFocus) return;

    SuggestionsOverlay.hide();

    final suggestions = _suggestedNames.map((name) {
      final isExact = name == _nameController.text.trim();
      return SuggestionItem(
        value: name,
        isExactMatch: isExact,
        type: SuggestionType.custom,
      );
    }).toList();

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
      _searchTypeNames,
    );
  }

  Future<void> _searchTypeNames() async {
    final query = _nameController.text.trim();

    // البحث بعد كتابة 3 أحرف على الأقل
    if (query.isEmpty || query.length < 3) {
      if (mounted) {
        setState(() {
          _suggestedNames = [];
          _isSearchingNames = false;
        });
      }
      _hideNameSuggestionsOverlay();
      return;
    }

    // إذا لم يتم البحث من قبل، نحصل على جميع الأسماء
    if (!_hasSearchedNames) {
      if (mounted) {
        setState(() {
          _isSearchingNames = true;
        });
      }

      try {
        final bloc = context.read<SubscriptionBloc>();
        final repository = bloc.repository;

        final result = await repository.searchSubscriptionTypeNames(query: '');

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _allSuggestedNames = [];
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
            }
          },
          (names) {
            if (mounted) {
              setState(() {
                _allSuggestedNames = names
                    .where((name) => name != widget.type.name)
                    .toList();
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
              // تصفية النتائج بناءً على النص المكتوب
              _filterNames(query);
            }
          },
        );
      } on Exception catch (_) {
        if (mounted) {
          setState(() {
            _allSuggestedNames = [];
            _hasSearchedNames = true;
            _isSearchingNames = false;
          });
        }
      }
    } else {
      // تصفية النتائج محلياً
      _filterNames(query);
    }
  }

  void _filterNames(String query) {
    final filtered = _allSuggestedNames
        .where((name) => name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (mounted) {
      setState(() {
        _suggestedNames = filtered;
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
      drawer: const SubscriptionDrawer(currentRoute: 'edit_subscription_type'),
      body: BlocListener<SubscriptionBloc, SubscriptionState>(
        listenWhen: (previous, current) {
          return (previous is! SubscriptionOperationSuccess &&
                  current is SubscriptionOperationSuccess) ||
              (previous is! SubscriptionError && current is SubscriptionError);
        },
        listener: (context, state) {
          if (state is SubscriptionOperationSuccess && !_operationCompleted) {
            _operationCompleted = true;
            // ✅ شاشة تعديل كاملة: بعد نجاح
            // الحفظ تعود للشاشة السابقة
            completeSaveOperation(
              successMessage: 'تم التعديل بنجاح',
              navigateBackOnSuccess: true,
            );
          } else if (state is SubscriptionError && !_operationCompleted) {
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
                  'تعديل نوع اشتراك',
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
                  'نظام إدارة الاشتراكات الآشوري',
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
      title: 'تعديل نوع اشتراك',
      subtitle: 'تحديث معلومات نوع الاشتراك',
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
            title: 'معلومات نوع الاشتراك',
            icon: Icons.info_outline,
            children: [
              _buildNameFieldWithSuggestions(),
              _buildTextField(
                controller: _descriptionController,
                label: 'الوصف *',
                icon: Icons.description,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الوصف مطلوب';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _priceController,
                label: 'السعر *',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                inputFormatters: [_formattingService.getPriceInputFormatter()],
                suffixText: 'د.ع',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'السعر مطلوب';
                  }
                  if (double.tryParse(value.replaceAll(',', '')) == null) {
                    return 'أدخل رقم صحيح';
                  }
                  return null;
                },
              ),
              _buildDurationDropdown(),
              FeaturesListWidget(
                features: _features,
                onFeaturesChanged: (features) {
                  setState(() {
                    _features = features;
                  });
                },
              ),
              _buildActiveSwitch(),
            ],
          ),
          SizedBox(height: 24.h),
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, state) {
              final isLoading = state is SubscriptionLoading;
              return Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      text: 'حفظ التعديلات',
                      onPressed: _updateSubscriptionType,
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
        _suggestedNames.contains(_nameController.text.trim());

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
              labelText: 'اسم النوع *',
              prefixIcon: Icon(
                Icons.category,
                size: 20.sp,
                color: AssyrianTheme.primaryGold,
              ),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 20.sp),
                      onPressed: () {
                        _nameController.clear();
                        _hideNameSuggestionsOverlay();
                        _suggestedNames = [];
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
                return 'اسم النوع مطلوب';
              }
              return null;
            },
          ),
        ),

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
                  'يوجد نوع اشتراك آخر بنفس الاسم:',
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

  Widget _buildDurationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _durations.contains(_selectedDuration)
              ? _selectedDuration
              : null,
          decoration: InputDecoration(
            labelText: 'المدة *',
            prefixIcon: Icon(
              Icons.schedule,
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
          items: _durations.map((duration) {
            return DropdownMenuItem<String>(
              value: duration,
              child: Text(_durationLabels[duration] ?? duration),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedDuration = value;
                _isCustomDuration = value == 'custom';
                if (!_isCustomDuration) {
                  _customDaysController.clear();
                }
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'المدة مطلوبة';
            }
            return null;
          },
        ),
        if (_isCustomDuration) ...[
          SizedBox(height: 16.h),
          TextFormField(
            controller: _customDaysController,
            keyboardType: TextInputType.number,
            inputFormatters: [_formattingService.getQuantityInputFormatter()],
            decoration: InputDecoration(
              labelText: 'عدد الأيام *',
              prefixIcon: Icon(
                Icons.calendar_today,
                size: 20.sp,
                color: AssyrianTheme.primaryGold,
              ),
              suffixText: 'يوم',
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
            validator: (value) {
              if (_isCustomDuration) {
                if (value == null || value.isEmpty) {
                  return 'عدد الأيام مطلوب';
                }
                final days = int.tryParse(value.replaceAll(',', ''));
                if (days == null || days <= 0) {
                  return 'أدخل عدد أيام صحيح';
                }
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActiveSwitch() {
    return Row(
      children: [
        Icon(Icons.toggle_on, size: 20.sp, color: AssyrianTheme.primaryGold),
        SizedBox(width: 8.w),
        Text(
          'نشط',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
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
          activeTrackColor: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
          activeThumbColor: AssyrianTheme.primaryGold,
        ),
      ],
    );
  }

  Future<void> _updateSubscriptionType() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // تحديد عدد الأيام المخصصة إذا كانت المدة مخصصة
    int? customDays;
    if (_isCustomDuration && _customDaysController.text.isNotEmpty) {
      customDays = int.tryParse(
        _customDaysController.text.trim().replaceAll(',', ''),
      );
    }

    // الحصول على معرف المستخدم الحالي
    String? updatedBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        updatedBy = switchedUser['id'] as String;
      } else {
        updatedBy = currentUser.uid;
      }
    } on Exception catch (_) {
      updatedBy = currentUser.uid;
    }

    final updatedType = SubscriptionTypeEntity(
      id: widget.type.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(_priceController.text.trim().replaceAll(',', '')),
      duration: _selectedDuration,
      customDays: customDays,
      features: _features,
      isActive: _isActive,
      activationQuantity:
          widget.type.activationQuantity, // الحفاظ على التفعيلات المتاحة
      linkedSubscriptionsCount:
          widget.type.linkedSubscriptionsCount, // الحفاظ على العداد
      createdBy: widget.type.createdBy,
      createdAt: widget.type.createdAt,
      updatedBy: updatedBy,
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;

    // الحصول على مرجع لـ SubscriptionBloc قبل العملية غير المتزامنة
    final subscriptionBloc = context.read<SubscriptionBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        subscriptionBloc.add(UpdateSubscriptionTypeEvent(updatedType));
      },
      successMessage: 'تم تحديث نوع الاشتراك بنجاح',
      onSuccess: () => Navigator.of(context).pop(updatedType),
      loadingMessage: 'جاري تحديث نوع الاشتراك...',
    );
  }
}
