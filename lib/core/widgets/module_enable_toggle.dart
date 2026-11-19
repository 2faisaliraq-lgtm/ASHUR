import 'dart:async';


import '../../core/widgets/loading_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../navigation/navigation_service.dart';
import '../services/enabled_modules_service.dart';
import '../theme/assyrian_theme.dart';

/// Widget لتمكين/إيقاف قسم معين
class ModuleEnableToggle extends StatefulWidget {
  const ModuleEnableToggle({
    required this.moduleId,
    required this.moduleName,
    required this.moduleIcon,
    super.key,
    this.onChanged,
  });

  final String moduleId;
  final String moduleName;
  final IconData moduleIcon;
  final VoidCallback? onChanged;

  @override
  State<ModuleEnableToggle> createState() => _ModuleEnableToggleState();
}

class _ModuleEnableToggleState extends State<ModuleEnableToggle> {
  final _service = EnabledModulesService();
  bool _isEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadModuleStatus();
  }

  Future<void> _loadModuleStatus() async {
    setState(() => _isLoading = true);
    final isEnabled = await _service.isModuleEnabled(widget.moduleId);
    setState(() {
      _isEnabled = isEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleModule(bool value) async {
    setState(() => _isSaving = true);

    final modules = await _service.getEnabledModules();
    modules[widget.moduleId] = value;
    final success = await _service.saveEnabledModules(modules);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        setState(() => _isEnabled = value);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'تم تمكين القسم بنجاح. جاري تحديث التطبيق...'
                  : 'تم إيقاف القسم بنجاح. جاري تحديث التطبيق...',
            ),
            backgroundColor: value ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // استدعاء callback إذا كان موجوداً
        widget.onChanged?.call();

        // إعادة تحميل الأقسام المفعلة في NavigationService
        await Future.delayed(const Duration(milliseconds: 500), () async {
          if (mounted) {
            // مسح الـ cache وإعادة تحميل الأقسام
            final service = EnabledModulesService();
            service.clearCache();

            // إعادة تهيئة التنقل لتحديث الشريط السفلي والجانبي
            final navigationService = NavigationService();
            await navigationService.reloadNavigation();

            // العودة إلى الصفحة الرئيسية
            if (mounted) {
              await Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في حفظ الإعدادات'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: LoadingWidget(message: 'جاري التحميل...'),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: _isEnabled
              ? AssyrianTheme.primaryGold.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: _isEnabled
                    ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                widget.moduleIcon,
                color: _isEnabled ? AssyrianTheme.primaryGold : Colors.grey,
                size: 28.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.moduleName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _isEnabled ? 'القسم مفعّل' : 'القسم معطّل',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: _isEnabled ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (_isSaving)
              SizedBox(
                width: 24.w,
                height: 24.h,
                child: LoadingWidget(size: 24),
              )
            else
              Switch(
                value: _isEnabled,
                onChanged: _toggleModule,
                activeTrackColor: AssyrianTheme.primaryGold.withValues(
                  alpha: 0.5,
                ),
                activeThumbColor: AssyrianTheme.primaryGold,
              ),
          ],
        ),
      ),
    );
  }
}




