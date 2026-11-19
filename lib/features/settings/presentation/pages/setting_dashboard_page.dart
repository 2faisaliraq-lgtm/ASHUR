import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';

class SettingDashboardPage extends StatefulWidget {
  const SettingDashboardPage({required this.organizationEmail, super.key});
  final String organizationEmail;

  @override
  State<SettingDashboardPage> createState() => _SettingDashboardPageState();
}

class _SettingDashboardPageState extends State<SettingDashboardPage> {
  // متغيرات الصلاحيات المخزنة
  bool? _usersSettingsPermission;
  bool? _customersSettingsPermission;
  bool? _inventorySettingsPermission;
  bool? _invoicesSettingsPermission;
  bool? _reportsSettingsPermission;
  bool? _expensesSettingsPermission;
  bool? _subscriptionsSettingsPermission;
  bool? _maintenanceSettingsPermission;
  bool? _rentalsSettingsPermission;
  bool? _settingsPermission;
  bool? _formattingSettingsPermission;
  bool? _backupSettingsPermission;

  // تخزين البطاقات في قائمة لتجنب إعادة البناء
  List<Widget>? _cachedCards;

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
  }

  Future<void> _loadUserPermissions() async {
    final permissionChecker = PermissionChecker();
    final permissions = await permissionChecker.getUserPermissions();

    if (mounted) {
      setState(() {
        for (final permission in permissions) {
          switch (permission) {
            case 'users_settings_view':
              _usersSettingsPermission = true;
              break;
            case 'customers_settings_view':
              _customersSettingsPermission = true;
              break;
            case 'inventory_settings_view':
              _inventorySettingsPermission = true;
              break;
            case 'invoices_settings_view':
              _invoicesSettingsPermission = true;
              break;
            case 'reports_settings_view':
              _reportsSettingsPermission = true;
              break;
            case 'expenses_settings_view':
              _expensesSettingsPermission = true;
              break;
            case 'subscriptions_settings_view':
              _subscriptionsSettingsPermission = true;
              break;
            case 'maintenance_settings_view':
              _maintenanceSettingsPermission = true;
              break;
            case 'rentals_settings_view':
              _rentalsSettingsPermission = true;
              break;
            case 'settings_view':
              _settingsPermission = true;
              break;
            case 'formatting_settings_view':
              _formattingSettingsPermission = true;
              break;
            case 'backup_settings_view':
              _backupSettingsPermission = true;
              break;
          }
        }
        // بناء البطاقات مرة واحدة فقط
        _buildCardsList();
      });
    }
  }

  void _buildCardsList() {
    _cachedCards = [];
    if (_usersSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات المستخدمين',
          subtitle: 'إدارة المستخدمين والأدوار',
          icon: Icons.people,
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, AppRoutes.usersSettings),
        ),
      );
    }
    if (_customersSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات العملاء',
          subtitle: 'إدارة العملاء والمجموعات',
          icon: Icons.person,
          color: Colors.green,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.customersSettings),
        ),
      );
    }
    if (_inventorySettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات المخزون',
          subtitle: 'إدارة المنتجات والمخزون',
          icon: Icons.inventory_2,
          color: AssyrianTheme.primaryGold,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.inventorySettings),
        ),
      );
    }
    if (_invoicesSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات الفواتير',
          subtitle: 'إدارة الفواتير والمدفوعات',
          icon: Icons.receipt_long,
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, AppRoutes.invoicesSettings),
        ),
      );
    }
    if (_reportsSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات التقارير',
          subtitle: 'إدارة التقارير والإحصائيات',
          icon: Icons.analytics,
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, AppRoutes.reportsSettings),
        ),
      );
    }
    if (_expensesSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات المصروفات',
          subtitle: 'إدارة المصروفات والموافقات',
          icon: Icons.money_off,
          color: Colors.red,
          onTap: () => Navigator.pushNamed(context, AppRoutes.expensesSettings),
        ),
      );
    }
    if (_subscriptionsSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات الاشتراكات',
          subtitle: 'إدارة الاشتراكات والدفع',
          icon: Icons.subscriptions,
          color: Colors.purple,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.subscriptionsSettings),
        ),
      );
    }
    if (_maintenanceSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات الصيانة',
          subtitle: 'إدارة طلبات وأعمال الصيانة',
          icon: Icons.build,
          color: Colors.brown,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.maintenanceSettings),
        ),
      );
    }
    if (_rentalsSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات الإيجارات',
          subtitle: 'إدارة عقود الإيجار والمدفوعات',
          icon: Icons.home_work,
          color: Colors.indigo,
          onTap: () => Navigator.pushNamed(context, AppRoutes.rentalsSettings),
        ),
      );
    }
    if (_settingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'الإعدادات العامة',
          subtitle: 'إعدادات النظام والشركة',
          icon: Icons.settings,
          color: AssyrianTheme.deepBlue,
          onTap: () => Navigator.pushNamed(context, AppRoutes.systemSettings),
        ),
      );
    }
    if (_formattingSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'إعدادات التنسيق',
          subtitle: 'الأرقام والعملات والتاريخ',
          icon: Icons.format_list_numbered,
          color: Colors.purple,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.formattingSettings),
        ),
      );
    }
    if (_backupSettingsPermission == true) {
      _cachedCards!.add(
        _buildSettingsCard(
          title: 'النسخ الاحتياطي',
          subtitle: 'إدارة النسخ الاحتياطية',
          icon: Icons.backup,
          color: Colors.teal,
          onTap: () => _showBackupOptions(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // تخزين ثابت لقيمة العنوان لتجنب إعادة البناء
    final titleStyle =
        Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AssyrianTheme.deepBlue,
        ) ??
        const TextStyle();

    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      body: _buildSettingContent(context, titleStyle),
    );
  }

  Widget _buildSettingContent(BuildContext context, TextStyle titleStyle) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
            child: Text('أقسام الإعدادات', style: titleStyle),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              const double minItemWidth = 200;
              final availableWidth = constraints.crossAxisExtent;
              final maxColumns = (availableWidth / minItemWidth).floor().clamp(
                2,
                4,
              );

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: maxColumns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate(_cachedCards ?? []),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return RepaintBoundary(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color.fromRGBO(
                    (color.r * 255).round(),
                    (color.g * 255).round(),
                    (color.b * 255).round(),
                    0.2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(
                          (color.r * 255).round(),
                          (color.g * 255).round(),
                          (color.b * 255).round(),
                          0.1,
                        ),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Color.fromRGBO(
                            (color.r * 255).round(),
                            (color.g * 255).round(),
                            (color.b * 255).round(),
                            0.3,
                          ),
                        ),
                      ),
                      child: Icon(icon, size: 28.sp, color: color),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBackupOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'خيارات النسخ الاحتياطي',
          style: TextStyle(color: AssyrianTheme.deepBlue),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.blue),
              title: const Text('إنشاء نسخة احتياطية'),
              subtitle: const Text('حفظ جميع البيانات'),
              onTap: () {
                Navigator.pop(context);
                _createBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download, color: Colors.green),
              title: const Text('استعادة النسخة الاحتياطية'),
              subtitle: const Text('استعادة البيانات المحفوظة'),
              onTap: () {
                Navigator.pop(context);
                _restoreBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.orange),
              title: const Text('جدولة النسخ الاحتياطية'),
              subtitle: const Text('إعداد النسخ التلقائية'),
              onTap: () {
                Navigator.pop(context);
                _scheduleBackup();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _createBackup() {
    // ⚠️ ملاحظة: هذه الوظيفة وهمية حالياً ولا تنفذ نسخاً احتياطياً حقيقياً.
    // يجب تنفيذ منطق النسخ الاحتياطي الفعال هنا قبل الإنتاج.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إنشاء النسخة الاحتياطية...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _restoreBackup() {
    // ⚠️ ملاحظة: هذه الوظيفة وهمية حالياً ولا تنفذ استعادة حقيقية.
    // يجب تنفيذ منطق الاستعادة الفعال هنا قبل الإنتاج.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري استعادة النسخة الاحتياطية...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _scheduleBackup() {
    // ⚠️ ملاحظة: هذه الوظيفة وهمية حالياً ولا تنفذ جدولة حقيقية.
    // يجب تنفيذ منطق الجدولة الفعال هنا قبل الإنتاج.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إعداد جدولة النسخ الاحتياطية...'),
        backgroundColor: Colors.orange,
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x4DFFD700),
              blurRadius: 10,
              offset: Offset(0, 2),
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإعدادات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: 2),
                Text(
                  'نظام إدارة المتاجر الآشوري',
                  style: TextStyle(
                    fontSize: 10,
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
    );
  }
}
