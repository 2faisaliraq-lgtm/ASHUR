import 'package:material_ui/material_ui.dart';


import '../../core/widgets/loading_widget.dart';
import 'permission_checker.dart';

/// حارس الصلاحيات - يمنع الوصول للصفحات بدون صلاحية
class PermissionGuard extends StatelessWidget {
  const PermissionGuard({
    required this.permission,
    required this.child,
    this.fallback,
    super.key,
  });

  final String permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionChecker().hasPermission(permission),
      builder: (context, snapshot) {
        // أثناء التحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingWidget(message: 'جاري التحميل...'),
          );
        }

        // إذا كان لديه الصلاحية
        if (snapshot.data ?? false) {
          return child;
        }

        // إذا لم يكن لديه الصلاحية
        return fallback ?? _buildNoPermissionPage(context);
      },
    );
  }

  Widget _buildNoPermissionPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('غير مصرح'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'ليس لديك صلاحية للوصول',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'عذراً، ليس لديك الصلاحية المطلوبة للوصول إلى هذه الصفحة.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('العودة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
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

/// حارس صلاحيات متعدد - يتطلب أي صلاحية من القائمة
class AnyPermissionGuard extends StatelessWidget {
  const AnyPermissionGuard({
    required this.permissions,
    required this.child,
    this.fallback,
    super.key,
  });

  final List<String> permissions;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionChecker().hasAnyPermission(permissions),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingWidget(message: 'جاري التحميل...'),
          );
        }

        if (snapshot.data ?? false) {
          return child;
        }

        return fallback ?? _buildNoPermissionPage(context);
      },
    );
  }

  Widget _buildNoPermissionPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('غير مصرح'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'ليس لديك صلاحية للوصول',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'عذراً، ليس لديك الصلاحية المطلوبة للوصول إلى هذه الصفحة.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('العودة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
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




