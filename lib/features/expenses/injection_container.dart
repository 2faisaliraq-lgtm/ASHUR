import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'data/repositories/expense_repository_impl.dart';
import 'domain/repositories/expense_repository.dart';
import 'domain/usecases/add_expense.dart';
import 'domain/usecases/delete_expense.dart';
import 'domain/usecases/get_expense_logs.dart';
import 'domain/usecases/get_expense_logs_stream.dart';
import 'domain/usecases/get_expense_stats.dart';
import 'domain/usecases/get_expense_stats_stream.dart';
import 'domain/usecases/get_expenses.dart';
import 'domain/usecases/get_expenses_paginated.dart';
import 'domain/usecases/get_expenses_stream.dart';
import 'domain/usecases/update_expense.dart';
import 'presentation/bloc/expense_bloc.dart';

final getIt = GetIt.instance;

Future<void> initExpenses() async {
  // Repository
  if (!getIt.isRegistered<ExpenseRepository>()) {
    getIt.registerLazySingleton<ExpenseRepository>(
      () => ExpenseRepositoryImpl(firestore: getIt<FirebaseFirestore>()),
    );
  }

  // Use Cases
  if (!getIt.isRegistered<GetExpenses>()) {
    getIt.registerLazySingleton(() => GetExpenses(getIt()));
  }
  if (!getIt.isRegistered<GetExpensesPaginated>()) {
    getIt.registerLazySingleton(() => GetExpensesPaginated(getIt()));
  }
  if (!getIt.isRegistered<GetExpensesStream>()) {
    getIt.registerLazySingleton(() => GetExpensesStream(getIt()));
  }
  if (!getIt.isRegistered<GetExpenseStatsStream>()) {
    getIt.registerLazySingleton(() => GetExpenseStatsStream(getIt()));
  }
  if (!getIt.isRegistered<AddExpense>()) {
    getIt.registerLazySingleton(() => AddExpense(getIt()));
  }
  if (!getIt.isRegistered<UpdateExpense>()) {
    getIt.registerLazySingleton(() => UpdateExpense(getIt()));
  }
  if (!getIt.isRegistered<DeleteExpense>()) {
    getIt.registerLazySingleton(() => DeleteExpense(getIt()));
  }
  if (!getIt.isRegistered<GetExpenseStats>()) {
    getIt.registerLazySingleton(() => GetExpenseStats(getIt()));
  }
  if (!getIt.isRegistered<GetExpenseLogs>()) {
    getIt.registerLazySingleton(() => GetExpenseLogs(getIt()));
  }
  if (!getIt.isRegistered<GetExpenseLogsStream>()) {
    getIt.registerLazySingleton(() => GetExpenseLogsStream(getIt()));
  }

  // BLoC
  if (!getIt.isRegistered<ExpenseBloc>()) {
    getIt.registerFactory(
      () => ExpenseBloc(
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
    );
  }
}
