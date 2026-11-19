import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../features/users/presentation/bloc/users_bloc.dart';
import '../../../features/users/presentation/bloc/users_event.dart';
import '../../../features/users/presentation/pages/create_edit_role_page.dart';
import '../../../features/users/presentation/pages/create_user_page.dart';
import '../../../features/users/presentation/pages/edit_user_page.dart';
import '../../../features/users/presentation/pages/role_details_page.dart';
import '../../../features/users/presentation/pages/roles_list_page.dart';
import '../../../features/users/presentation/pages/user_details_page.dart';
import '../../../features/users/presentation/pages/users_list_page.dart';
import '../../../features/users/presentation/pages/users_log_page.dart';
import '../../../features/users/presentation/pages/users_reports_page.dart';
import '../../../features/users/presentation/pages/users_settings_page.dart';
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات المستخدمين
Map<String, WidgetBuilder> get usersRoutes => {
  // ignore: cascade_invitations
  RoutePaths.users: (context) => BlocProvider<UsersBloc>.value(
    value: GetIt.instance<UsersBloc>(),
    child: UsersListPage(
      initialFilter: ModalRoute.of(context)?.settings.arguments as String?,
    ),
  ),
  // مسار بديل للداشبورد
  RoutePaths.usersList: (context) => BlocProvider<UsersBloc>.value(
    value: GetIt.instance<UsersBloc>(),
    child: UsersListPage(
      initialFilter: ModalRoute.of(context)?.settings.arguments as String?,
    ),
  ),
  // ignore: cascade_invitations
  RoutePaths.rolesManagement: (context) => BlocProvider<UsersBloc>.value(
    value: GetIt.instance<UsersBloc>(),
    child: const RolesListPage(),
  ),
  // ignore: cascade_invitations
  RoutePaths.usersSettings: (context) => BlocProvider<UsersBloc>.value(
    value: GetIt.instance<UsersBloc>(),
    child: const UsersSettingsPage(),
  ),
  // ignore: cascade_invitations
  RoutePaths.usersReports: (context) => BlocProvider<UsersBloc>.value(
    value: GetIt.instance<UsersBloc>(),
    child: const UsersReportsPage(),
  ),
  // ignore: cascade_invitations
  RoutePaths.usersLog: (context) => BlocProvider<UsersBloc>.value(
    value: GetIt.instance<UsersBloc>(),
    child: const UsersLogPage(),
  ),
};

/// مسارات المستخدمين الديناميكية (تتطلب arguments)
Route<dynamic>? buildUserRoute(String routeName, RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createUser:
      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'users_create',
          bloc: GetIt.instance<UsersBloc>()..add(const LoadRolesEvent()),
          child: const CreateUserPage(),
        ),
        settings: settings,
      );

    case RoutePaths.editUser:
      final userData = settings.arguments;
      if (userData != null) {
        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'users_edit',
            bloc: GetIt.instance<UsersBloc>()..add(const LoadRolesEvent()),
            child: EditUserPage(user: userData as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.userDetails:
      final userData = settings.arguments;
      if (userData != null) {
        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: GetIt.instance<UsersBloc>(),
            child: UserDetailsPage(user: userData as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.createRole:
      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'users_create',
          bloc: GetIt.instance<UsersBloc>(),
          child: const CreateEditRolePage(),
        ),
        settings: settings,
      );

    case RoutePaths.editRole:
      final role = settings.arguments;
      if (role != null) {
        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'users_edit',
            bloc: GetIt.instance<UsersBloc>(),
            child: CreateEditRolePage(role: role as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.roleDetails:
      final role = settings.arguments;
      if (role != null) {
        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: GetIt.instance<UsersBloc>(),
            child: RoleDetailsPage(role: role as dynamic),
          ),
          settings: settings,
        );
      }
      return null;

    default:
      return null;
  }
}
