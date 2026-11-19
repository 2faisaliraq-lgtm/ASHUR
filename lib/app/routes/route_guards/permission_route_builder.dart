import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/permissions/permission_guard.dart';

/// دالة مساعدة لبناء مسار مع PermissionGuard
Widget buildPermissionRoute({
  required String permission,
  required Widget child,
  List<BlocProvider>? blocProviders,
}) {
  return PermissionGuard(
    permission: permission,
    child: blocProviders != null
        ? MultiBlocProvider(providers: blocProviders, child: child)
        : child,
  );
}

/// دالة مساعدة لبناء مسار مع PermissionGuard و BlocProvider واحد
Widget buildPermissionRouteWithBloc<T extends Bloc>({
  required String permission,
  required T bloc,
  required Widget child,
}) {
  return PermissionGuard(
    permission: permission,
    child: BlocProvider<T>(create: (context) => bloc, child: child),
  );
}

/// دالة مساعدة لبناء مسار مع PermissionGuard و MultiBlocProvider
Widget buildPermissionRouteWithMultiBloc({
  required String permission,
  List<String>? alternativePermissions,
  required List<BlocProvider> blocProviders,
  required Widget child,
}) {
  if (alternativePermissions != null && alternativePermissions.isNotEmpty) {
    // استخدام AnyPermissionGuard إذا وجدت صلاحيات بديلة
    return AnyPermissionGuard(
      permissions: [permission, ...alternativePermissions],
      child: MultiBlocProvider(providers: blocProviders, child: child),
    );
  } else {
    // استخدام PermissionGuard العادي
    return PermissionGuard(
      permission: permission,
      child: MultiBlocProvider(providers: blocProviders, child: child),
    );
  }
}
