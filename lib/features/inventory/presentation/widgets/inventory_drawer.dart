import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../injection_container.dart';
import '../bloc/inventory_bloc.dart';
import '../pages/inventory_log_page.dart';

/// الشريط الجانبي الموحد لقسم المخزون
class InventoryDrawer extends StatefulWidget {
  const InventoryDrawer({
    super.key,
    this.currentRoute,
    this.onAddProduct,
    this.onManageCategories,
    this.onManageShelves,
    this.onViewReports,
    this.onViewMovements,
    this.onScanBarcode,
    this.onSettings,
  });
  final String? currentRoute;
  final VoidCallback? onAddProduct;
  final VoidCallback? onManageCategories;
  final VoidCallback? onManageShelves;
  final VoidCallback? onViewReports;
  final VoidCallback? onViewMovements;
  final VoidCallback? onScanBarcode;
  final VoidCallback? onSettings;

  @override
  State<InventoryDrawer> createState() => _InventoryDrawerState();
}

class _InventoryDrawerState extends State<InventoryDrawer> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _userPermissions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
  }

  Future<void> _loadUserPermissions() async {
    final permissions = await _permissionChecker.getUserPermissions();
    final permissionsMap = <String, bool>{};

    for (final permission in permissions) {
      permissionsMap[permission] = true;
    }

    if (mounted) {
      setState(() {
        _userPermissions = permissionsMap;
        _isLoading = false;
      });
    }
  }

  bool _hasPermission(String permission) {
    return _userPermissions[permission] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Drawer(
        backgroundColor: AssyrianTheme.ivoryWhite,
        child: LoadingWidget(message: 'جاري التحميل...'),
      );
    }

    return Drawer(
      backgroundColor: AssyrianTheme.ivoryWhite,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AssyrianTheme.ivoryWhite,
              AssyrianTheme.ivoryWhite.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(context),
            _buildDrawerSection(
              context,
              title: 'المخزون الرئيسي',
              items: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'لوحة التحكم',
                  isSelected: widget.currentRoute == 'dashboard',
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                if (_hasPermission('inventory_view'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.inventory_2_outlined,
                    title: 'جميع المنتجات',
                    isSelected: widget.currentRoute == 'products',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(AppRoutes.productsList);
                    },
                  ),
                if (_hasPermission('inventory_create'))
                  _buildDrawerItem(
                    context,
                    icon: Icons.add_box_outlined,
                    title: 'إضافة منتج',
                    isSelected: widget.currentRoute == 'add_product',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onAddProduct != null) {
                        widget.onAddProduct!();
                      } else {
                        Navigator.of(context).pushNamed(AppRoutes.createProduct);
                      }
                    },
                  ),
              ],
            ),
            if (_hasPermission('inventory_categories_view'))
              _buildDrawerSection(
                context,
                title: 'التصنيف والتنظيم',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.category_outlined,
                    title: 'الفئات',
                    isSelected: widget.currentRoute == 'categories',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onManageCategories != null) {
                        widget.onManageCategories!();
                      } else {
                        Navigator.of(context).pushNamed(AppRoutes.categoriesList);
                      }
                    },
                  ),
                  if (_hasPermission('inventory_shelves_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.shelves,
                      title: 'الرفوف',
                      isSelected: widget.currentRoute == 'shelves',
                      onTap: () {
                        Navigator.of(context).pop();
                        if (widget.onManageShelves != null) {
                          widget.onManageShelves!();
                        } else {
                          Navigator.of(context).pushNamed(AppRoutes.shelvesList);
                        }
                      },
                    ),
                ],
              ),
            if (_hasPermission('inventory_reports_view'))
              _buildDrawerSection(
                context,
                title: 'التقارير والتحليل',
                items: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'التقارير',
                    isSelected: widget.currentRoute == '/inventory/reports',
                    onTap: () {
                      Navigator.of(context).pop();
                      if (widget.onViewReports != null) {
                        widget.onViewReports!();
                      } else {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.inventoryReports);
                      }
                    },
                  ),
                  if (_hasPermission('inventory_logs_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.history_outlined,
                      title: 'سجل الحركات',
                      isSelected: widget.currentRoute == 'movements',
                      onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<InventoryBloc>(),
                                child: const InventoryLogPage(),
                              ),
                            ),
                          );
                      },
                    ),
                ],
              ),
            if (_hasPermission('inventory_tools_view'))
              _buildDrawerSection(
                context,
                title: 'الأدوات',
                items: [
                  if (_hasPermission('inventory_barcode_scan'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.qr_code_scanner_outlined,
                      title: 'مسح الباركود',
                      isSelected: widget.currentRoute == 'barcode',
                      onTap: () {
                        Navigator.of(context).pop();
                        if (widget.onScanBarcode != null) {
                          widget.onScanBarcode!();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ميزة مسح الباركود قيد التطوير'),
                            ),
                          );
                        }
                      },
                    ),
                  if (_hasPermission('inventory_settings_view'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.settings_outlined,
                      title: 'إعدادات المخزون',
                      isSelected: widget.currentRoute == 'settings',
                      onTap: () {
                        Navigator.of(context).pop();
                        if (widget.onSettings != null) {
                          widget.onSettings!();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('صفحة الإعدادات قيد التطوير'),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 3,
            child: AssyrianTheme.getLamassuForBackground(
              isDarkBackground: true,
            ),
          ),
          SizedBox(height: 4.h),
          Flexible(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إدارة المخزون',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 16.sp,
                    color: AssyrianTheme.primaryGold,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Text(
                  'نظام إدارة المتاجر',
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: 9.sp,
                    color: AssyrianTheme.ivoryWhite,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AssyrianTheme.primaryGold : AssyrianTheme.deepBlue,
        size: 20.sp,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14.sp,
          color: isSelected
              ? AssyrianTheme.primaryGold
              : AssyrianTheme.deepBlue,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      dense: true,
    );
  }
}



