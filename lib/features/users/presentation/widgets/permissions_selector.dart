import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../domain/entities/permission_entity.dart';

/// ويدجت محدد الصلاحيات
class PermissionsSelector extends StatefulWidget {

  const PermissionsSelector({
    required this.permissions, required this.selectedPermissions, required this.onPermissionsChanged, super.key,
  });
  final List<PermissionEntity> permissions;
  final List<String> selectedPermissions;
  final Function(List<String>) onPermissionsChanged;

  @override
  State<PermissionsSelector> createState() => _PermissionsSelectorState();
}

class _PermissionsSelectorState extends State<PermissionsSelector> {
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // تجميع الصلاحيات حسب الفئة
  Map<String, List<PermissionEntity>> get _groupedPermissions {
    var grouped = <String, List<PermissionEntity>>{};

    for (final permission in widget.permissions) {
      if (!grouped.containsKey(permission.category)) {
        grouped[permission.category] = [];
      }
      grouped[permission.category]!.add(permission);
    }

    return grouped;
  }

  // فلترة الصلاحيات حسب البحث والفئة
  List<PermissionEntity> get _filteredPermissions {
    var filtered = widget.permissions;

    // فلترة حسب الفئة
    if (_selectedCategory != null) {
      filtered = filtered
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    // فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (p) =>
                p.displayName.toLowerCase().contains(query) ||
                p.name.toLowerCase().contains(query) ||
                (p.description?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    return filtered;
  }

  // أسماء الفئات بالعربية
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'users':
        return 'المستخدمين';
      case 'dashboard':
        return 'لوحة التحكم';
      case 'customers':
        return 'العملاء';
      case 'inventory':
        return 'المخزون';
      case 'invoices':
        return 'الفواتير';
      case 'rentals':
        return 'الإيجارات';
      case 'expenses':
        return 'المصروفات';
      case 'maintenance':
        return 'الصيانة';
      case 'subscriptions':
        return 'الاشتراكات';
      case 'reports':
        return 'التقارير';
      case 'settings':
        return 'الإعدادات';
      default:
        return category;
    }
  }

  // أيقونات الفئات
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'users':
        return Icons.people;
      case 'dashboard':
        return Icons.dashboard;
      case 'customers':
        return Icons.person_outline;
      case 'inventory':
        return Icons.inventory;
      case 'invoices':
        return Icons.receipt;
      case 'rentals':
        return Icons.home_work;
      case 'expenses':
        return Icons.money_off;
      case 'maintenance':
        return Icons.build;
      case 'subscriptions':
        return Icons.card_membership;
      case 'reports':
        return Icons.assessment;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.security;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.permissions.isEmpty) {
      return AppEmptyState(
        icon: Icons.security,
        title: 'لا توجد صلاحيات متاحة',
        message: 'يرجى تحميل الصلاحيات أولاً',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // شريط البحث والفلاتر
        _buildSearchAndFilters(),

        SizedBox(height: 16.h),

        // عرض الصلاحيات
        ResponsiveHelper.responsiveBuilder(
          mobile: _buildMobileView(),
          tablet: _buildTabletView(),
          desktop: _buildDesktopView(),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // شريط البحث
        DecoratedBox(
          decoration: BoxDecoration(
            color: AssyrianTheme.ivoryWhite,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AssyrianTheme.bronzeBrown.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14.sp,
              color: AssyrianTheme.deepBlue,
            ),
            decoration: InputDecoration(
              hintText: 'البحث في الصلاحيات...',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14.sp,
                color: AssyrianTheme.deepBlue.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AssyrianTheme.primaryGold,
                size: 20.sp,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: Icon(
                        Icons.clear,
                        color: AssyrianTheme.deepBlue.withValues(alpha: 0.6),
                        size: 18.sp,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
            ),
          ),
        ),

        SizedBox(height: 12.h),

        // فلتر الفئات
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // زر "جميع الفئات"
              _buildCategoryChip(null, 'جميع الفئات', Icons.all_inclusive),
              SizedBox(width: 8.w),

              // أزرار الفئات
              ..._groupedPermissions.keys.map(
                (category) => Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: _buildCategoryChip(
                    category,
                    _getCategoryDisplayName(category),
                    _getCategoryIcon(category),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String? category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;

    return FilterChip(
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? category : null;
        });
      },
      avatar: Icon(
        icon,
        size: 16.sp,
        color: isSelected
            ? AssyrianTheme.ivoryWhite
            : AssyrianTheme.primaryGold,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: isSelected ? AssyrianTheme.ivoryWhite : AssyrianTheme.deepBlue,
        ),
      ),
      selectedColor: AssyrianTheme.primaryGold,
      backgroundColor: AssyrianTheme.ivoryWhite,
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : AssyrianTheme.bronzeBrown.withValues(alpha: 0.3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
    );
  }

  Widget _buildMobileView() {
    final filteredPermissions = _filteredPermissions;

    if (filteredPermissions.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        // إحصائيات سريعة
        _buildQuickStats(filteredPermissions),

        SizedBox(height: 16.h),

        // قائمة الصلاحيات
        ...filteredPermissions.map(
          _buildMobilePermissionTile,
        ),
      ],
    );
  }

  Widget _buildTabletView() {
    final filteredPermissions = _filteredPermissions;

    if (filteredPermissions.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        // إحصائيات سريعة
        _buildQuickStats(filteredPermissions),

        SizedBox(height: 16.h),

        // شبكة الصلاحيات
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
          ),
          itemCount: filteredPermissions.length,
          itemBuilder: (context, index) {
            return _buildTabletPermissionCard(filteredPermissions[index]);
          },
        ),
      ],
    );
  }

  Widget _buildDesktopView() {
    final groupedPermissions = _groupedPermissions;
    final filteredPermissions = _filteredPermissions;

    if (filteredPermissions.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        // إحصائيات سريعة
        _buildQuickStats(filteredPermissions),

        SizedBox(height: 16.h),

        // عرض مجمع حسب الفئة
        if (_selectedCategory == null) ...[
          ...groupedPermissions.entries.map((entry) {
            final categoryPermissions = entry.value
                .where(
                  (p) =>
                      _searchQuery.isEmpty ||
                      p.displayName.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      p.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      (p.description?.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ??
                          false),
                )
                .toList();

            if (categoryPermissions.isEmpty) return const SizedBox();

            return _buildCategorySection(entry.key, categoryPermissions);
          }),
        ] else ...[
          // عرض فئة واحدة
          _buildPermissionsGrid(filteredPermissions),
        ],
      ],
    );
  }

  Widget _buildQuickStats(List<PermissionEntity> permissions) {
    final selectedCount = widget.selectedPermissions.length;
    final totalCount = permissions.length;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AssyrianTheme.primaryGold,
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'تم تحديد $selectedCount من أصل $totalCount صلاحية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AssyrianTheme.deepBlue,
              ),
            ),
          ),
          if (selectedCount > 0) ...[
            TextButton(
              onPressed: () {
                widget.onPermissionsChanged([]);
              },
              child: Text(
                'إلغاء الكل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.sp,
                  color: AssyrianTheme.crimsonRed,
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: () {
              final allPermissionIds = permissions.map((p) => p.name).toList();
              widget.onPermissionsChanged(allPermissionIds);
            },
            child: Text(
              'تحديد الكل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.sp,
                color: AssyrianTheme.primaryGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AssyrianTheme.bronzeBrown.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48.sp,
            color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'جرب تغيير معايير البحث أو الفلترة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14.sp,
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePermissionTile(PermissionEntity permission) {
    final isSelected = widget.selectedPermissions.contains(permission.name);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isSelected
            ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
            : AssyrianTheme.ivoryWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected
              ? AssyrianTheme.primaryGold
              : AssyrianTheme.bronzeBrown.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          _togglePermission(permission.name);
        },
        title: Text(
          permission.displayName,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: permission.description != null
            ? Text(
                permission.description!,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.sp,
                  color: AssyrianTheme.deepBlue.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        secondary: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Icon(
            _getCategoryIcon(permission.category),
            size: 16.sp,
            color: AssyrianTheme.primaryGold,
          ),
        ),
        activeColor: AssyrianTheme.primaryGold,
        checkColor: AssyrianTheme.deepBlue,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildTabletPermissionCard(PermissionEntity permission) {
    final isSelected = widget.selectedPermissions.contains(permission.name);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected
            ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
            : AssyrianTheme.ivoryWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected
              ? AssyrianTheme.primaryGold
              : AssyrianTheme.bronzeBrown.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _togglePermission(permission.name),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) => _togglePermission(permission.name),
                activeColor: AssyrianTheme.primaryGold,
                checkColor: AssyrianTheme.deepBlue,
              ),
              SizedBox(width: 8.w),
              Icon(
                _getCategoryIcon(permission.category),
                size: 16.sp,
                color: AssyrianTheme.primaryGold,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      permission.displayName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AssyrianTheme.deepBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (permission.description != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        permission.description!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.sp,
                          color: AssyrianTheme.deepBlue.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    List<PermissionEntity> permissions,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الفئة
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: AssyrianTheme.primaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: AssyrianTheme.ivoryWhite,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  _getCategoryDisplayName(category),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.ivoryWhite,
                  ),
                ),
                const Spacer(),
                Text(
                  '${permissions.length} صلاحية',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.sp,
                    color: AssyrianTheme.ivoryWhite.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // محتوى الفئة
          Padding(
            padding: EdgeInsets.all(16.w),
            child: _buildPermissionsGrid(permissions),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsGrid(List<PermissionEntity> permissions) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveHelper.isDesktop(context) ? 3 : 2,
        childAspectRatio: 3,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
      ),
      itemCount: permissions.length,
      itemBuilder: (context, index) {
        return _buildTabletPermissionCard(permissions[index]);
      },
    );
  }

  void _togglePermission(String permissionName) {
    var newSelected = <String>[...widget.selectedPermissions];

    if (newSelected.contains(permissionName)) {
      newSelected.remove(permissionName);
    } else {
      newSelected.add(permissionName);
    }

    widget.onPermissionsChanged(newSelected);
  }
}
