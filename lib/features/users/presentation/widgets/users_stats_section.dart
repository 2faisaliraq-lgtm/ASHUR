import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/user_management_entity.dart';

/// قسم إحصائيات المستخدمين
class UsersStatsSection extends StatelessWidget {
  UsersStatsSection({
    required this.users,
    required this.onFilterSelected,
    this.statistics,
    super.key,
  });
  final List<UserManagementEntity> users;
  final ValueChanged<String> onFilterSelected;
  final Map<String, int>? statistics;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  @override
  Widget build(BuildContext context) {
    // استخدام الإحصائيات من statistics إذا كانت متوفرة، وإلا احسبها من القائمة
    final totalUsers = statistics?['total'] ?? users.length;
    final activeUsers =
        statistics?['active'] ?? users.where((u) => u.isActive).length;
    final inactiveUsers = statistics?['inactive'] ?? (totalUsers - activeUsers);
    final admins =
        statistics?['admins'] ??
        users
            .where(
              (user) =>
                  user.roleIds.contains('admin') ||
                  user.roles.any(
                    (role) => role.id == 'admin' || role.name == 'admin',
                  ),
            )
            .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AssyrianTheme.primaryGold,
            AssyrianTheme.primaryGold.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظرة عامة على المستخدمين',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              int crossAxisCount;
              double childAspectRatio;

              if (availableWidth > 900) {
                crossAxisCount = 4;
                childAspectRatio = 4.5;
              } else if (availableWidth > 600) {
                crossAxisCount = 4;
                childAspectRatio = 4.0;
              } else {
                crossAxisCount = 2;
                childAspectRatio = 2.5;
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildStatCard(
                    'إجمالي المستخدمين',
                    _formattingService.formatInteger(totalUsers),
                    Icons.people_outline,
                    AssyrianTheme.deepBlue,
                    onTap: () => onFilterSelected('all'),
                  ),
                  _buildStatCard(
                    'نشط',
                    _formattingService.formatInteger(activeUsers),
                    Icons.check_circle_outline,
                    Colors.green,
                    onTap: () => onFilterSelected('active'),
                  ),
                  _buildStatCard(
                    'غير نشط',
                    _formattingService.formatInteger(inactiveUsers),
                    Icons.cancel_outlined,
                    Colors.orange,
                    onTap: () => onFilterSelected('inactive'),
                  ),
                  _buildStatCard(
                    'المدراء',
                    _formattingService.formatInteger(admins),
                    Icons.admin_panel_settings_outlined,
                    Colors.purple,
                    onTap: () => onFilterSelected('admins'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // الاسم في الجهة اليمنى
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 8.w),
              // الرقم في الجهة اليسرى
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
