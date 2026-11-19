import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/expenses/domain/entities/expense_entity.dart';
import '../../../features/expenses/expense_feature.dart';
import '../../../features/expenses/injection_container.dart' show getIt;
import '../../../features/expenses/presentation/bloc/expense_bloc.dart';
import '../../../features/expenses/presentation/pages/create_expense_page.dart';
import '../../../features/expenses/presentation/pages/edit_expense_page.dart';
import '../../../features/expenses/presentation/pages/expense_details_page.dart';
import '../../../features/expenses/presentation/pages/expenses_list_page.dart';
import '../../../features/expenses/presentation/pages/expenses_log_page.dart';
import '../../../features/expenses/presentation/pages/expenses_reports_page.dart';
import '../../../features/expenses/presentation/pages/expenses_settings_page.dart';
import '../route_guards/bloc_route_builder.dart';
import '../route_guards/permission_route_builder.dart';
import '../route_paths.dart';

/// مسارات المصروفات
Map<String, WidgetBuilder> get expensesRoutes => {
  RoutePaths.expensesList: (context) {
    final user = FirebaseAuth.instance.currentUser;
    final initialFilter = ModalRoute.of(context)?.settings.arguments as String?;
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    ExpenseFeature.ensureInitialized();

    return BlocProvider<ExpenseBloc>(
      create: (context) => ExpenseBloc(
        getExpenses: getIt(),
        getExpensesPaginated: getIt(),
        getExpensesStream: getIt(),
        getExpenseStatsStream: getIt(),
        addExpense: getIt(),
        updateExpense: getIt(),
        deleteExpense: getIt(),
        getExpenseStats: getIt(),
        getExpenseLogs: getIt(),
        getExpenseLogsStream: getIt(),
        repository: getIt(),
      )..add(LoadExpensesEvent(user?.email ?? '')),
      child: ExpensesListPage(initialFilter: initialFilter),
    );
  },
  RoutePaths.expensesSettings: (context) => const ExpensesSettingsPage(),
  RoutePaths.expensesLog: (context) {
    // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
    ExpenseFeature.ensureInitialized();

    return BlocProvider<ExpenseBloc>(
      create: (context) => ExpenseBloc(
        getExpenses: getIt(),
        getExpensesPaginated: getIt(),
        getExpensesStream: getIt(),
        getExpenseStatsStream: getIt(),
        addExpense: getIt(),
        updateExpense: getIt(),
        deleteExpense: getIt(),
        getExpenseStats: getIt(),
        getExpenseLogs: getIt(),
        getExpenseLogsStream: getIt(),
        repository: getIt(),
      ),
      child: const ExpensesLogPage(),
    );
  },
  RoutePaths.expensesReports: (context) => buildPermissionRoute(
    permission: 'reports_view',
    blocProviders: [
      BlocProvider<ExpenseBloc>(
        create: (context) {
          final user = FirebaseAuth.instance.currentUser;
          // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
          ExpenseFeature.ensureInitialized();

          return ExpenseBloc(
            getExpenses: getIt(),
            getExpensesPaginated: getIt(),
            getExpensesStream: getIt(),
            getExpenseStatsStream: getIt(),
            addExpense: getIt(),
            updateExpense: getIt(),
            deleteExpense: getIt(),
            getExpenseStats: getIt(),
            getExpenseLogs: getIt(),
            getExpenseLogsStream: getIt(),
            repository: getIt(),
          )..add(LoadExpensesEvent(user?.email ?? ''));
        },
      ),
    ],
    child: const ExpensesReportsPage(),
  ),
};

/// مسارات المصروفات الديناميكية (تتطلب arguments)
Route<dynamic>? buildExpenseRoute(String routeName, RouteSettings settings) {
  final user = FirebaseAuth.instance.currentUser;

  switch (routeName) {
    case RoutePaths.createExpense:
      // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
      ExpenseFeature.ensureInitialized();

      return MaterialPageRoute(
        builder: (context) => buildPermissionRouteWithBloc(
          permission: 'expenses_create',
          bloc: ExpenseBloc(
            getExpenses: getIt(),
            getExpensesPaginated: getIt(),
            getExpensesStream: getIt(),
            getExpenseStatsStream: getIt(),
            addExpense: getIt(),
            updateExpense: getIt(),
            deleteExpense: getIt(),
            getExpenseStats: getIt(),
            getExpenseLogs: getIt(),
            getExpenseLogsStream: getIt(),
            repository: getIt(),
          ),
          child: const CreateExpensePage(),
        ),
        settings: settings,
      );

    case RoutePaths.editExpense:
      final expense = settings.arguments;
      if (expense != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        ExpenseFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildPermissionRouteWithBloc(
            permission: 'expenses_edit',
            bloc: ExpenseBloc(
              getExpenses: getIt(),
              getExpensesPaginated: getIt(),
              getExpensesStream: getIt(),
              getExpenseStatsStream: getIt(),
              addExpense: getIt(),
              updateExpense: getIt(),
              deleteExpense: getIt(),
              getExpenseStats: getIt(),
              getExpenseLogs: getIt(),
              getExpenseLogsStream: getIt(),
              repository: getIt(),
            ),
            child: EditExpensePage(expense: expense as ExpenseEntity),
          ),
          settings: settings,
        );
      }
      return null;

    case RoutePaths.expenseDetails:
      final expense = settings.arguments;
      if (expense != null) {
        // تهيئة سريعة بدون FutureBuilder - التهيئة تتم في الخلفية
        ExpenseFeature.ensureInitialized();

        return MaterialPageRoute(
          builder: (context) => buildBlocRoute(
            bloc: ExpenseBloc(
              getExpenses: getIt(),
              getExpensesPaginated: getIt(),
              getExpensesStream: getIt(),
              getExpenseStatsStream: getIt(),
              addExpense: getIt(),
              updateExpense: getIt(),
              deleteExpense: getIt(),
              getExpenseStats: getIt(),
              getExpenseLogs: getIt(),
              getExpenseLogsStream: getIt(),
              repository: getIt(),
            )..add(LoadExpensesEvent(user?.email ?? '')),
            child: ExpenseDetailsPage(expense: expense as ExpenseEntity),
          ),
          settings: settings,
        );
      }
      return null;

    default:
      return null;
  }
}
