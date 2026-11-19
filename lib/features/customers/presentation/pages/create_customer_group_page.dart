import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/customer_group_entity.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';

/// صفحة إضافة مجموعة عملاء جديدة
class CreateCustomerGroupPage extends StatefulWidget {
  const CreateCustomerGroupPage({super.key});

  @override
  State<CreateCustomerGroupPage> createState() =>
      _CreateCustomerGroupPageState();
}

class _CreateCustomerGroupPageState extends State<CreateCustomerGroupPage>
    with SaveOperationMixin<CreateCustomerGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  String _selectedColor = 'FF6B73'; // اللون الافتراضي
  final List<String> _features = [];
  final _featureController = TextEditingController();
  bool _isActive = true;

  final List<String> _availableColors = [
    'FF6B73', // أحمر
    '4ECDC4', // تركوازي
    '45B7D1', // أزرق
    '96CEB4', // أخضر
    'FFEAA7', // أصفر
    'DDA0DD', // بنفسجي
    'F4A261', // برتقالي
    '2A9D8F', // أخضر داكن
    'E76F51', // أحمر برتقالي
    '264653', // أزرق داكن
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const CustomerDrawer(currentRoute: 'create_customer_group'),
      body: BlocListener<CustomerBloc, CustomerState>(
        listenWhen: (previous, current) {
          return current is CustomerGroupOperationSuccess ||
              current is CustomerError;
        },
        listener: (context, state) {
          if (state is CustomerGroupOperationSuccess && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: state.message,
              navigateBackOnSuccess: true,
            );
          } else if (state is CustomerError && !_operationCompleted) {
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
                  'إضافة مجموعة عملاء',
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
                  'نظام إدارة العملاء الآشوري',
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
      title: 'إضافة مجموعة عملاء جديدة',
      subtitle: 'إنشاء مجموعة جديدة وإضافتها إلى قاعدة البيانات',
      icon: Icons.group_add,
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
            title: 'معلومات المجموعة',
            icon: Icons.info_outline,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'اسم المجموعة *',
                icon: Icons.group,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'اسم المجموعة مطلوب';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _descriptionController,
                label: 'وصف المجموعة *',
                icon: Icons.description,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'وصف المجموعة مطلوب';
                  }
                  return null;
                },
              ),
              _buildColorPicker(),
              _buildFeaturesSection(),
              _buildActiveSwitch(),
            ],
          ),
          SizedBox(height: 24.h),
          BlocBuilder<CustomerBloc, CustomerState>(
            builder: (context, state) {
              final isLoading = state is CustomerLoading;
              return Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      text: 'إنشاء المجموعة',
                      onPressed: _createGroup,
                      isLoading: isLoading,
                      icon: Icons.group_add,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines ?? 1,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
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

  Widget _buildColorPicker() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لون المجموعة *',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _availableColors.map((color) {
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF$color')),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isSelected
                          ? AssyrianTheme.deepBlue
                          : Colors.grey[300]!,
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

  Widget _buildFeaturesSection() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مميزات المجموعة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _featureController,
                  decoration: InputDecoration(
                    hintText: 'أضف ميزة جديدة',
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
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                  ),
                  onSubmitted: _addFeature,
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: () => _addFeature(_featureController.text),
                icon: const Icon(Icons.add, color: AssyrianTheme.primaryGold),
              ),
            ],
          ),
          if (_features.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: _features.map((feature) {
                return Chip(
                  label: Text(feature),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _features.remove(feature);
                    });
                  },
                  backgroundColor: AssyrianTheme.primaryGold.withValues(
                    alpha: 0.1,
                  ),
                  deleteIconColor: AssyrianTheme.deepBlue,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveSwitch() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Icon(Icons.toggle_on, color: AssyrianTheme.primaryGold, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            'المجموعة نشطة',
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
            activeThumbColor: AssyrianTheme.primaryGold,
          ),
        ],
      ),
    );
  }

  void _addFeature(String feature) {
    if (feature.trim().isNotEmpty && !_features.contains(feature.trim())) {
      setState(() {
        _features.add(feature.trim());
        _featureController.clear();
      });
    }
  }

  Future<void> _createGroup() async {
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

    // الحصول على معرف المستخدم
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

    final group = CustomerGroupEntity(
      id: '', // سيتم إنشاء معرف قصير في repository
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      color: _selectedColor,
      features: _features,
      isActive: _isActive,
      createdBy: createdBy,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ CustomerBloc قبل العملية غير المتزامنة
    final customerBloc = context.read<CustomerBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        customerBloc.add(CreateCustomerGroupEvent(group));
      },
      successMessage: 'تم إنشاء مجموعة العملاء بنجاح',
      loadingMessage: 'جاري إنشاء مجموعة العملاء...',
    );
  }
}
