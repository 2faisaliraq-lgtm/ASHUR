import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../services/formatting_service.dart';
import '../theme/assyrian_theme.dart';

/// Shared widget for consistent detail screen headers
class DetailScreenHeader extends StatelessWidget {
  const DetailScreenHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconBackgroundColor,
    this.iconForegroundColor,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconBackgroundColor;
  final Color? iconForegroundColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x1AFFD700), Color(0x0C003366)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x4DFFD700)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBackgroundColor ?? const Color(0x33FFD700),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32.sp,
                color: iconForegroundColor ?? AssyrianTheme.primaryGold,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared widget for consistent info cards
class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.title,
    required this.icon,
    required this.children,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0x33FFD700)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AssyrianTheme.primaryGold, size: 20.sp),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Shared widget for consistent detail rows
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120.w,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: valueColor ?? AssyrianTheme.deepBlue,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared widget for status rows with colored backgrounds
class StatusRow extends StatelessWidget {
  const StatusRow({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120.w,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared widget for amount rows with currency formatting
class AmountRow extends StatelessWidget {
  const AmountRow({
    required this.label,
    required this.amount,
    required this.color,
    this.isBold = false,
    this.prefix = '',
    super.key,
  });

  final String label;
  final double amount;
  final Color color;
  final bool isBold;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 120.w,
              child: Text(
                prefix + label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                GetIt.instance<FormattingService>().formatCurrency(amount),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: color,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared widget for consistent action buttons
class ActionButtons extends StatelessWidget {
  const ActionButtons({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'الإجراءات',
      icon: Icons.settings,
      children: children,
    );
  }
}

/// Shared widget for system info section
class SystemInfoCard extends StatelessWidget {
  const SystemInfoCard({
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
    super.key,
  });

  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'معلومات النظام',
      icon: Icons.system_update,
      children: [
        DetailRow(label: 'تاريخ الإنشاء', value: _formatDate(createdAt)),
        DetailRow(label: 'أنشئ بواسطة', value: _getUserName(createdBy)),
        if (updatedAt != null)
          DetailRow(label: 'آخر تحديث', value: _formatDate(updatedAt!)),
        if (updatedBy != null)
          DetailRow(label: 'آخر تحديث بواسطة', value: _getUserName(updatedBy)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getUserName(String? createdBy) {
    if (createdBy == null || createdBy.isEmpty) return 'غير محدد';

    // إذا كان النص يحتوي على @ فهو بريد إلكتروني، نستخرج اسم المستخدم
    if (createdBy.contains('@')) {
      final username = createdBy.split('@')[0];
      return username
          .replaceAll('.', ' ')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .split(' ')
          .map(
            (word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : '',
          )
          .join(' ');
    }

    // إذا لم يكن بريد إلكتروني، فهو اسم المستخدم الفعلي
    return createdBy;
  }
}
