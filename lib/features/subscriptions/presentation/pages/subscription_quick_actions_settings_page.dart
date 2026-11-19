import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/navigation/navigation_service.dart';

/// صفحة إعدادات الإجراءات السريعة - اختيار الإجراءات المعروضة
class SubscriptionQuickActionsSettingsPage extends StatefulWidget {
  const SubscriptionQuickActionsSettingsPage({super.key});

  @override
  State<SubscriptionQuickActionsSettingsPage> createState() =>
      _SubscriptionQuickActionsSettingsPageState();
}

class _SubscriptionQuickActionsSettingsPageState
    extends State<SubscriptionQuickActionsSettingsPage> {
  // قائمة جميع الإجراءات المتاحة
  final List<Map<String, dynamic>> _allActions = [
    {
      'id': 'add_subscription',
      'title': 'إضافة اشتراك',
      'subtitle': 'اشتراك جديد',
      'icon': Icons.subscriptions_outlined,
      'color': AssyrianTheme.primaryGold,
      'permission': 'subscriptions_create',
      'enabled': false,
    },
    {
      'id': 'subscriptions_list',
      'title': 'الاشتراكات',
      'subtitle': 'قائمة الاشتراكات',
      'icon': Icons.list_alt_outlined,
      'color': Colors.teal,
      'permission': 'subscriptions_view',
      'enabled': false,
    },
    {
      'id': 'subscription_types',
      'title': 'أنواع الاشتراكات',
      'subtitle': 'إدارة الأنواع',
      'icon': Icons.category_outlined,
      'color': Colors.purple,
      'permission': 'subscriptions_settings_manage',
      'enabled': false,
    },
    {
      'id': 'reports',
      'title': 'التقارير',
      'subtitle': 'إحصائيات مفصلة',
      'icon': Icons.analytics_outlined,
      'color': Colors.blue,
      'permission': 'reports_view',
      'enabled': false,
    },
    {
      'id': 'settings',
      'title': 'الإعدادات',
      'subtitle': 'إعدادات الاشتراكات',
      'icon': Icons.settings_outlined,
      'color': Colors.orange,
      'permission': 'subscriptions_settings_manage',
      'enabled': false,
    },
    {
      'id': 'refresh',
      'title': 'تحديث',
      'subtitle': 'تحديث البيانات',
      'icon': Icons.refresh_outlined,
      'color': Colors.green,
      'permission': null,
      'enabled': false,
    },
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedActions();
  }

  Future<void> _loadSavedActions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedActions = prefs.getString('subscription_quick_actions');

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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveActions() async {
    final enabledCount = _allActions.where((a) => a['enabled'] as bool).length;

    if (enabledCount > 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يمكنك اختيار إجرائين فقط',
                style: TextStyle(fontSize: 14.sp, fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final actionsData =
        _allActions.map((a) => {'id': a['id'], 'enabled': a['enabled']}).toList();
    await prefs.setString('subscription_quick_actions', jsonEncode(actionsData));

    // تحديث notifier في NavigationService لإعادة بناء شاشات الإجراءات السريعة فوراً
    final navService = NavigationService();
    final currentSettings = Map<String, bool>.from(navService.quickActionsSettingsNotifier.value);
    for (var a in _allActions) {
      currentSettings['subscription_${a['id']}'] = a['enabled'] as bool;
    }
    navService.quickActionsSettingsNotifier.value = currentSettings;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ الإعدادات بنجاح',
              style: TextStyle(fontSize: 14.sp, fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      for (var action in _allActions) {
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
                isDarkBackground: true, hasCircularBackground: false),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('إعدادات الإجراءات السريعة',
                      style: AssyrianTheme.titleStyle.copyWith(
                          fontSize: 18.sp, color: AssyrianTheme.primaryGold),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text('اختر الإجراءات التي تريد عرضها',
                      style: AssyrianTheme.subtitleStyle.copyWith(
                          fontSize: 10.sp, color: AssyrianTheme.ivoryWhite),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _resetToDefaults,
            icon: Icon(Icons.restore, color: AssyrianTheme.primaryGold, size: 20.sp),
            label:
                Text('افتراضي', style: TextStyle(fontSize: 12.sp, fontFamily: 'Cairo', color: AssyrianTheme.primaryGold)),
          ),
          IconButton(
            onPressed: _saveActions,
            icon: Icon(Icons.save_outlined, color: AssyrianTheme.primaryGold, size: 24.sp),
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
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AssyrianTheme.primaryGold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AssyrianTheme.primaryGold, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الإجراءات السريعة',
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              color: AssyrianTheme.deepBlue)),
                      SizedBox(height: 4.h),
                      Text(
                          'يمكنك اختيار إجرائين فقط للعرض في صفحة الاشتراكات. قم بتفعيل الإجراءات التي تريدها.',
                          style: TextStyle(
                              fontSize: 12.sp,
                              fontFamily: 'Cairo',
                              color: AssyrianTheme.deepBlue.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Text('الإجراءات المتاحة',
              style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: AssyrianTheme.deepBlue)),
          SizedBox(height: 16.h),
          ..._allActions.map((action) => _buildActionTile(action)),
          SizedBox(height: 32.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveActions,
              icon: Icon(Icons.save, size: 20.sp),
              label: Text('حفظ التغييرات',
                  style: TextStyle(
                      fontSize: 16.sp, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isMaxReached ? null : () {
            setState(() => action['enabled'] = !isEnabled);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action['icon'] as IconData, size: 24.sp, color: action['color'] as Color),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action['title'] as String,
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              color: isEnabled ? AssyrianTheme.deepBlue : Colors.grey,
                              decoration: isEnabled ? null : TextDecoration.lineThrough)),
                      SizedBox(height: 4.h),
                      Text(action['subtitle'] as String,
                          style: TextStyle(
                              fontSize: 12.sp,
                              fontFamily: 'Cairo',
                              color: isEnabled ? Colors.grey[600] : Colors.grey[400])),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: isEnabled,
                    onChanged: isMaxReached
                        ? null
                        : (value) {
                            setState(() => action['enabled'] = value);
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



