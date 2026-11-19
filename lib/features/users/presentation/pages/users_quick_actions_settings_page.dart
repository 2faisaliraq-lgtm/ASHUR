import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/navigation/navigation_service.dart';

/// صفحة إعدادات الإجراءات السريعة - اختيار الإجراءات المعروضة
class UsersQuickActionsSettingsPage extends StatefulWidget {
  const UsersQuickActionsSettingsPage({super.key});

  @override
  State<UsersQuickActionsSettingsPage> createState() =>
      _UsersQuickActionsSettingsPageState();
}

class _UsersQuickActionsSettingsPageState
    extends State<UsersQuickActionsSettingsPage> {
  // قائمة جميع الإجراءات المتاحة
  final List<Map<String, dynamic>> _allActions = [
    {
      'id': 'add_user',
      'title': 'إضافة مستخدم',
      'subtitle': 'مستخدم جديد',
      'icon': Icons.person_add_outlined,
      'color': AssyrianTheme.primaryGold,
      'permission': 'users_create',
      'enabled': false,
    },
    {
      'id': 'users_list',
      'title': 'قائمة المستخدمين',
      'subtitle': 'عرض جميع المستخدمين',
      'icon': Icons.list_alt_outlined,
      'color': Colors.teal,
      'permission': 'users_view',
      'enabled': false,
    },
    {
      'id': 'roles_management',
      'title': 'إدارة الأدوار',
      'subtitle': 'الصلاحيات والأدوار',
      'icon': Icons.security_outlined,
      'color': Colors.indigo,
      'permission': 'roles_manage',
      'enabled': false,
    },
    {
      'id': 'users_log',
      'title': 'سجل المستخدمين',
      'subtitle': 'تتبع العمليات',
      'icon': Icons.history_outlined,
      'color': Colors.purple,
      'permission': 'users_view',
      'enabled': false,
    },
    {
      'id': 'reports',
      'title': 'التقارير',
      'subtitle': 'إحصائيات مفصلة',
      'icon': Icons.analytics_outlined,
      'color': Colors.blue,
      'permission': 'users_reports_view',
      'enabled': false,
    },
    {
      'id': 'settings',
      'title': 'الإعدادات',
      'subtitle': 'إعدادات المستخدمين',
      'icon': Icons.settings_outlined,
      'color': Colors.orange,
      'permission': 'users_settings_manage',
      'enabled': false,
    },
    {
      'id': 'refresh',
      'title': 'تحديث',
      'subtitle': 'تحديث البيانات',
      'icon': Icons.refresh_outlined,
      'color': Colors.green,
      'permission': null, // متاح للجميع
      'enabled': false,
    },
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedActions();
  }

  /// تحميل الإجراءات المحفوظة
  Future<void> _loadSavedActions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedActions = prefs.getString('users_quick_actions');

    if (savedActions != null) {
      final List<dynamic> decoded = jsonDecode(savedActions);
      setState(() {
        for (var action in _allActions) {
          final savedAction =
              decoded.cast<Map<String, dynamic>>().firstWhere(
                    (a) => a['id'] == action['id'],
                    orElse: () => {},
                  );
          if (savedAction.isNotEmpty) {
            action['enabled'] = savedAction['enabled'] ?? true;
          }
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// حفظ الإجراءات
  Future<void> _saveActions() async {
    // التأكد من أن هناك إجرائين مفعلة فقط
    final enabledCount = _allActions.where((a) => a['enabled'] as bool).length;

    if (enabledCount > 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يمكنك اختيار إجرائين فقط',
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: 'Cairo',
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final actionsData = _allActions
        .map((a) => {'id': a['id'], 'enabled': a['enabled']})
        .toList();
    await prefs.setString(
      'users_quick_actions',
      jsonEncode(actionsData),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ الإعدادات بنجاح',
            style: TextStyle(
              fontSize: 14.sp,
              fontFamily: 'Cairo',
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // العودة للصفحة السابقة
      Navigator.of(context).pop(true);
    }
  }

  /// إعادة التعيين إلى الإعدادات الافتراضية
  Future<void> _resetToDefaults() async {
    setState(() {
      for (var action in _allActions) {
        // لا توجد إجراءات افتراضية - المستخدم يختار بحرية
        action['enabled'] = false;
      }
    });
    await _saveActions();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: AppBar(
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'إعدادات الإجراءات السريعة',
                    style: AssyrianTheme.titleStyle.copyWith(
                      fontSize: 18.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    'اختر الإجراءات التي تريد عرضها',
                    style: AssyrianTheme.subtitleStyle.copyWith(
                      fontSize: 10.sp,
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
          TextButton.icon(
            onPressed: _resetToDefaults,
            icon: Icon(Icons.restore, color: AssyrianTheme.primaryGold, size: 20.sp),
            label: Text(
              'افتراضي',
              style: TextStyle(
                fontSize: 12.sp,
                fontFamily: 'Cairo',
                color: AssyrianTheme.primaryGold,
              ),
            ),
          ),
          IconButton(
            onPressed: _saveActions,
            icon: Icon(
              Icons.save_outlined,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: _isLoading
          ? LoadingWidget(message: 'جاري التحميل...')
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة توضيحية
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AssyrianTheme.primaryGold,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجراءات السريعة',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: AssyrianTheme.deepBlue,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'يمكنك اختيار إجرائين فقط للعرض في صفحة المستخدمين. قم بتفعيل الإجراءات التي تريدها.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: 'Cairo',
                          color: AssyrianTheme.deepBlue.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // عنوان القسم
          Text(
            'الإجراءات المتاحة',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: AssyrianTheme.deepBlue,
            ),
          ),

          SizedBox(height: 16.h),

          // قائمة الإجراءات
          ..._allActions.map((action) => _buildActionTile(action)),

          SizedBox(height: 32.h),

          // زر الحفظ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveActions,
              icon: Icon(Icons.save, size: 20.sp),
              label: Text(
                'حفظ التغييرات',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(Map<String, dynamic> action) {
    final isEnabled = action['enabled'] as bool;
    final enabledCount = _allActions.where((a) => a['enabled'] as bool).length;
    final isMaxReached = enabledCount >= 2 && !isEnabled;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isMaxReached ? null : () {
            setState(() {
              action['enabled'] = !isEnabled;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // الأيقونة
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    size: 24.sp,
                    color: action['color'] as Color,
                  ),
                ),

                SizedBox(width: 16.w),

                // العنوان والوصف
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action['title'] as String,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          color: isEnabled
                              ? AssyrianTheme.deepBlue
                              : Colors.grey,
                          decoration: isEnabled
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        action['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: 'Cairo',
                          color: isEnabled
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),

                // زر التبديل
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: isEnabled,
                    onChanged: isMaxReached ? null : (value) {
                      setState(() {
                        action['enabled'] = value;
                      });
                    },
                    activeThumbColor: AssyrianTheme.primaryGold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



