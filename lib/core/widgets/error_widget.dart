import 'package:material_ui/material_ui.dart';

import '../theme/assyrian_theme.dart';

/// ويدجت الخطأ المعياري
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    required this.message,
    super.key,
    this.onRetry,
    this.icon,
  });
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    String cleanMessage = message
        .replaceAll('Exception:', '')
        .replaceAll('Instance of \'Exception\'', '')
        .replaceAll('Instance of "Exception"', '')
        .trim();

    if (cleanMessage.isEmpty) {
      cleanMessage = 'حدث خطأ غير متوقع';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.error_outline, size: 80, color: AssyrianTheme.error),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AssyrianTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cleanMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AssyrianTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
