import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../domain/entities/permission_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/permission_group_card.dart';

/// صفحة إنشاء وتعديل الأدوار
class CreateEditRolePage extends StatefulWidget {
  // null للإنشاء، RoleEntity للتعديل

  const CreateEditRolePage({super.key, this.role});
  final RoleEntity? role;

  @override
  State<CreateEditRolePage> createState() => _CreateEditRolePageState();
}

class _CreateEditRolePageState extends State<CreateEditRolePage>
    with SaveOperationMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  List<String> _selectedPermissions = [];
  bool _isActive = true;

  bool get _isEditing => widget.role != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersBloc>().add(const LoadPermissionsEvent());
    });
  }

  void _initializeForm() {
    if (_isEditing) {
      final role = widget.role!;
      _nameController.text = role.name;
      _displayNameController.text = role.displayName;
      _descriptionController.text = role.description ?? '';
      _selectedPermissions = List.from(role.permissions);
      _isActive = role.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildResponsiveAppBar(context),
      drawer: const Drawer(
        child: ListTile(
          leading: Icon(Icons.people),
          title: Text('المستخدمين'),
          onTap: null,
        ),
      ),
      body: BlocListener<UsersBloc, UsersState>(
        listenWhen: (previous, current) {
          return current is UsersError ||
              current is RoleCreated ||
              current is RoleUpdated;
        },
        listener: (context, state) {
          if (state is UsersError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          } else if (state is RoleCreated && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: 'تم إنشاء الدور بنجاح',
              navigateBackOnSuccess: true,
            );
          } else if (state is RoleUpdated && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: 'تم تحديث الدور بنجاح',
              navigateBackOnSuccess: true,
            );
          }
        },
        child: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            var permissions = <PermissionEntity>[];

            if (state is UsersLoaded) {
              permissions = state.permissions.cast<PermissionEntity>();
            }

            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildWelcomeCard(context),
                  SizedBox(height: 16.h),
                  _buildFormCard(context, permissions),
                  SizedBox(height: 16.h),
                ],
              ),
            );
          },
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
                  _isEditing ? 'تعديل الدور' : 'إنشاء دور جديد',
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
                  'نظام إدارة المتاجر الآشوري',
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
          onPressed: _saveRole,
          icon: Icon(Icons.save, color: AssyrianTheme.primaryGold, size: 24.sp),
        ),
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
      title: 'إدارة الأدوار والصلاحيات',
      subtitle: 'إنشاء أو تعديل دور وصلاحياته',
      icon: Icons.security,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    List<PermissionEntity> permissions,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة المعلومات الأساسية
          InfoCard(
            title: 'معلومات الدور',
            icon: Icons.info_outline,
            children: [
              _buildNameField(),
              SizedBox(height: 16.h),
              _buildDisplayNameField(),
              SizedBox(height: 16.h),
              _buildDescriptionField(),
              SizedBox(height: 16.h),
              _buildIsActiveSwitch(),
            ],
          ),
          SizedBox(height: 16.h),
          // بطاقة الصلاحيات
          _buildPermissionsCard(context, permissions),
          SizedBox(height: 24.h),
          // أزرار الحفظ
          _buildActionButtons(context),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'اسم الدور *',
        hintText: 'أدخل اسم الدور',
        prefixIcon: const Icon(
          Icons.badge_outlined,
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
        if (value == null || value.isEmpty) {
          return 'اسم الدور مطلوب';
        }
        if (value.length < 3) {
          return 'اسم الدور يجب أن يكون 3 أحرف على الأقل';
        }
        return null;
      },
    );
  }

  Widget _buildDisplayNameField() {
    return TextFormField(
      controller: _displayNameController,
      decoration: InputDecoration(
        labelText: 'الاسم العرضي *',
        hintText: 'أدخل الاسم العرضي',
        prefixIcon: const Icon(Icons.title, color: AssyrianTheme.primaryGold),
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
        if (value == null || value.isEmpty) {
          return 'الاسم العرضي مطلوب';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'الوصف (اختياري)',
        hintText: 'أدخل وصف الدور',
        prefixIcon: const Icon(
          Icons.description_outlined,
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

  Widget _buildIsActiveSwitch() {
    return Row(
      children: [
        Icon(
          Icons.toggle_on,
          color: _isActive ? AssyrianTheme.emeraldGreen : Colors.grey,
          size: 32.sp,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حالة الدور:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              Text(
                _isActive ? 'نشط' : 'غير نشط',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.sp,
                  color: _isActive ? AssyrianTheme.emeraldGreen : Colors.grey,
                ),
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
          activeThumbColor: AssyrianTheme.emeraldGreen,
          inactiveThumbColor: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildPermissionsCard(
    BuildContext context,
    List<PermissionEntity> permissions,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AssyrianTheme.assyrianShadow,
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.security,
                  color: AssyrianTheme.primaryGold,
                  size: 32.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الصلاحيات',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'تحديد صلاحيات الدور',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${_selectedPermissions.length} محددة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // محدد الصلاحيات - تجميع حسب القسم
          _buildGroupedPermissions(permissions),
        ],
      ),
    );
  }

  Widget _buildGroupedPermissions(List<PermissionEntity> permissions) {
    // تجميع الصلاحيات حسب القسم
    final groupedPermissions = <String, List<MapEntry<String, String>>>{};
    final sectionIcons = <String, IconData>{
      'invoices': Icons.receipt_long,
      'customers': Icons.people,
      'inventory': Icons.inventory_2,
      'subscriptions': Icons.card_membership,
      'rentals': Icons.home_work,
      'expenses': Icons.money_off,
      'reports': Icons.analytics,
      'users': Icons.admin_panel_settings,
      'settings': Icons.settings,
      'dashboard': Icons.dashboard,
      'maintenance': Icons.build,
    };

    final sectionNames = <String, String>{
      'invoices': 'الفواتير',
      'customers': 'العملاء',
      'inventory': 'المخزون',
      'subscriptions': 'الاشتراكات',
      'rentals': 'الإيجارات',
      'expenses': 'المصروفات',
      'reports': 'التقارير',
      'users': 'المستخدمين',
      'settings': 'الإعدادات',
      'dashboard': 'لوحة التحكم',
      'maintenance': 'الصيانة',
    };

    for (final permission in permissions) {
      final category = permission.category;
      if (!groupedPermissions.containsKey(category)) {
        groupedPermissions[category] = [];
      }
      groupedPermissions[category]!.add(
        MapEntry(permission.name, permission.displayName),
      );
    }

    return Column(
      children: groupedPermissions.entries.map((entry) {
        final categoryName = entry.key;
        return PermissionGroupCard(
          groupName: sectionNames[categoryName] ?? categoryName,
          groupIcon: sectionIcons[categoryName] ?? Icons.folder,
          permissions: entry.value,
          selectedPermissions: _selectedPermissions,
          onPermissionsChanged: (selected) {
            setState(() {
              _selectedPermissions = selected;
            });
          },
          initiallyExpanded: false,
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: AssyrianTheme.cardGradient,
        borderRadius: BorderRadius.zero,
        boxShadow: AssyrianTheme.assyrianShadow,
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: ResponsiveHelper.responsiveBuilder(
        mobile: _buildMobileActionButtons(context),
        tablet: _buildTabletActionButtons(context),
        desktop: _buildDesktopActionButtons(context),
      ),
    );
  }

  Widget _buildMobileActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            onPressed: _saveRole,
            icon: Icon(Icons.save, size: 20.sp),
            label: Text(
              _isEditing ? 'تحديث الدور' : 'حفظ الدور',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.cancel, size: 20.sp),
            label: Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AssyrianTheme.crimsonRed,
              side: const BorderSide(color: AssyrianTheme.crimsonRed),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48.h,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.cancel, size: 20.sp),
              label: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AssyrianTheme.crimsonRed,
                side: const BorderSide(color: AssyrianTheme.crimsonRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: _saveRole,
              icon: Icon(Icons.save, size: 20.sp),
              label: Text(
                _isEditing ? 'تحديث الدور' : 'حفظ الدور',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 120.w,
          height: 48.h,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.cancel, size: 18.sp),
            label: Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AssyrianTheme.crimsonRed,
              side: const BorderSide(color: AssyrianTheme.crimsonRed),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        SizedBox(
          width: 160.w,
          height: 48.h,
          child: ElevatedButton.icon(
            onPressed: _saveRole,
            icon: Icon(Icons.save, size: 18.sp),
            label: Text(
              _isEditing ? 'تحديث' : 'حفظ',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _saveRole() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى تحديد صلاحية واحدة على الأقل'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // الحصول على معرف المستخدم
    String? createdByOrUpdatedBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdByOrUpdatedBy = switchedUser['id'] as String;
      } else {
        createdByOrUpdatedBy = FirebaseAuth.instance.currentUser?.uid;
      }
    } on Exception catch (_) {
      createdByOrUpdatedBy = FirebaseAuth.instance.currentUser?.uid;
    }

    if (!mounted) return;

    // الحصول على مرجع لـ UsersBloc قبل العملية غير المتزامنة
    final usersBloc = context.read<UsersBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        if (_isEditing) {
          // تحديث الدور الموجود
          usersBloc.add(
            UpdateRoleEvent(
              roleId: widget.role!.id,
              displayName: _displayNameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              permissions: _selectedPermissions,
              updatedBy: createdByOrUpdatedBy,
            ),
          );
        } else {
          // إنشاء دور جديد
          usersBloc.add(
            CreateRoleEvent(
              name: _nameController.text.trim(),
              displayName: _displayNameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              permissions: _selectedPermissions,
              createdBy: createdByOrUpdatedBy,
            ),
          );
        }
      },
      successMessage: _isEditing
          ? 'تم تحديث الدور بنجاح'
          : 'تم إنشاء الدور بنجاح',
      loadingMessage: _isEditing
          ? 'جاري تحديث الدور...'
          : 'جاري إنشاء الدور...',
    );
  }
}
