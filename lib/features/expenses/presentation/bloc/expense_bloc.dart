import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_log_entity.dart';
import '../../domain/entities/expense_stats_entity.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/add_expense.dart';
import '../../domain/usecases/delete_expense.dart';
import '../../domain/usecases/get_expense_logs.dart';
import '../../domain/usecases/get_expense_logs_stream.dart';
import '../../domain/usecases/get_expense_stats.dart';
import '../../domain/usecases/get_expense_stats_stream.dart';
import '../../domain/usecases/get_expenses.dart';
import '../../domain/usecases/get_expenses_paginated.dart';
import '../../domain/usecases/get_expenses_stream.dart';
import '../../domain/usecases/update_expense.dart';

part 'expense_event.dart';
part 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  ExpenseBloc({
    required this.getExpenses,
    required this.getExpensesPaginated,
    required this.getExpensesStream,
    required this.getExpenseStatsStream,
    required this.addExpense,
    required this.updateExpense,
    required this.deleteExpense,
    required this.getExpenseStats,
    required this.getExpenseLogs,
    required this.getExpenseLogsStream,
    required this.repository,
  }) : super(ExpenseInitial()) {
    on<LoadExpensesEvent>(_onLoadExpenses);
    on<LoadExpensesPaginatedEvent>(_onLoadExpensesPaginated);
    on<LoadMoreExpensesEvent>(_onLoadMoreExpenses);
    on<StartExpensesStreamEvent>(_onStartExpensesStream);
    on<StopExpensesStreamEvent>(_onStopExpensesStream);
    on<StartExpenseStatsStreamEvent>(_onStartExpenseStatsStream);
    on<StopExpenseStatsStreamEvent>(_onStopExpenseStatsStream);
    on<AddExpenseEvent>(_onAddExpense);
    on<UpdateExpenseEvent>(_onUpdateExpense);
    on<DeleteExpenseEvent>(_onDeleteExpense);
    on<LoadExpenseStatsEvent>(_onLoadExpenseStats);
    on<FilterExpensesEvent>(_onFilterExpenses);
    on<SearchExpensesEvent>(_onSearchExpenses);
    on<ToggleViewModeEvent>(_onToggleViewMode);
    on<LoadExpenseLogsEvent>(_onLoadExpenseLogs);
    on<StartExpenseLogsStreamEvent>(_onStartExpenseLogsStream);
    on<StopExpenseLogsStreamEvent>(_onStopExpenseLogsStream);
    // Stream handlers
    on<_ExpenseStreamDataReceived>(_onExpenseStreamDataReceived);
    on<_ExpenseStreamErrorReceived>(_onExpenseStreamErrorReceived);
    on<_ExpenseStatsStreamDataReceived>(_onExpenseStatsStreamDataReceived);
    on<_ExpenseLogsStreamDataReceived>(_onExpenseLogsStreamDataReceived);
    on<_ExpenseLogsStreamErrorReceived>(_onExpenseLogsStreamErrorReceived);
  }

  final GetExpenses getExpenses;
  final GetExpensesPaginated getExpensesPaginated;
  final GetExpensesStream getExpensesStream;
  final GetExpenseStatsStream getExpenseStatsStream;
  final AddExpense addExpense;
  final UpdateExpense updateExpense;
  final DeleteExpense deleteExpense;
  final GetExpenseStats getExpenseStats;
  final GetExpenseLogs getExpenseLogs;
  final GetExpenseLogsStream getExpenseLogsStream;
  final ExpenseRepository repository;

  // متغيرات للتحكم في الـ streams
  StreamSubscription<dynamic>? _expensesStreamSubscription;
  StreamSubscription<dynamic>? _statsStreamSubscription;
  StreamSubscription<dynamic>? _expenseLogsStreamSubscription;
  List<ExpenseEntity> _allExpenses = []; // ✅ حفظ كل المصروفات للفلترة
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isGridView = false;
  ExpenseStatsEntity?
  _pendingStats; // ✅ تخزين الإحصائيات الواصلة قبل بيانات المصاريف

  Future<void> _onLoadExpenses(
    LoadExpensesEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(ExpenseLoading());
    final result = await getExpenses(event.organizationEmail);
    await result.fold((failure) async => emit(ExpenseError(failure.message)), (
      expenses,
    ) async {
      // ℹ️ ملاحظة أداء: تُحسب الإحصائيات من القائمة المُحمّلة
      // مباشرة (بدون قراءة ثانية للمجموعة) — نفس نتيجة
      // getExpenseStats لكن أسرع.
      final stats = repository.computeExpenseStats(expenses);

      emit(
        ExpenseLoaded(
          expenses: expenses,
          filteredExpenses: expenses,
          selectedFilter: 'all',
          searchQuery: '',
          stats: stats,
          isGridView: false,
        ),
      );
    });
  }

  // متغيرات للتحكم في pagination
  dynamic _lastDocument;
  static const int _pageSize = 20;

  Future<void> _onLoadExpensesPaginated(
    LoadExpensesPaginatedEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    if (event.isRefresh) {
      _lastDocument = null;
      emit(ExpenseLoading());
    }

    final result = await getExpensesPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
    );

    await result.fold((failure) async => emit(ExpenseError(failure.message)), (
      page,
    ) async {
      final expenses = page.expenses;

      // آخر مستند من نتيجة الصفحة مباشرة — بلا قراءة
      // إضافية (انظر ExpensePage) — أسرع ويمنع تكرار
      // الصفحات إن فشلت قراءة المستند الأخير منفرداً.
      _lastDocument = page.lastSnapshot;

      // ℹ️ ملاحظة أداء: صفحة القائمة لا تعرض الإحصائيات
      // (تُعرض في الداشبورد عبر stream الإحصائيات فقط)،
      // فحسابها هنا كان يقرأ كل المصاريف بلا فائدة —
      // أُزيل لتسريع التحميل المجزأ.
      emit(
        ExpenseLoaded(
          expenses: expenses,
          filteredExpenses: expenses,
          selectedFilter: 'all',
          searchQuery: '',
          isGridView: false,
          hasMore: expenses.length >= _pageSize,
          lastDocument: _lastDocument,
        ),
      );
    });
  }

  Future<void> _onLoadMoreExpenses(
    LoadMoreExpensesEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state is! ExpenseLoaded) return;

    final currentState = state as ExpenseLoaded;

    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    final result = await getExpensesPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
      lastDocument: currentState.lastDocument,
    );

    await result.fold(
      (failure) async {
        emit(currentState.copyWith(isLoadingMore: false));
        emit(ExpenseError(failure.message));
      },
      (page) async {
        final newExpenses = page.expenses;

        // آخر مستند من نتيجة الصفحة مباشرة — بلا قراءة
        // إضافية (انظر ExpensePage) — وإن كانت الصفحة
        // فارغة نُبقي المستند السابق (لن يُطلب المزيد).
        _lastDocument = page.lastSnapshot ?? currentState.lastDocument;

        final allExpenses = <ExpenseEntity>[
          ...currentState.expenses,
          ...newExpenses,
        ];

        // ℹ️ ملاحظة أداء: لا إحصائيات هنا (انظر
        // _onLoadExpensesPaginated) — لتسريع التحميل الإضافي.
        emit(
          currentState.copyWith(
            expenses: allExpenses,
            filteredExpenses: allExpenses,
            hasMore: newExpenses.length >= _pageSize,
            isLoadingMore: false,
            lastDocument: _lastDocument,
          ),
        );
      },
    );
  }

  Future<void> _onAddExpense(
    AddExpenseEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state is ExpenseLoaded || state is ExpenseStreamActive) {
      final previousState = state;
      emit(ExpenseLoading());
      // ⚠️ ملاحظة للمبرمجين المستلمين — مشكلة أداء: بعد كل عملية ناجحة (إضافة/تعديل/حذف)
      // يتم استدعاء getExpenses الكامل لإعادة تحميل كل المصاريف من الخادم (السطور 272، 341، 420).
      // للمجموعات الكبيرة هذا غير كفء؛ يُفضل تحديث الحالة محلياً أو استخدام الستريم
      // بدلاً من إعادة تحميل كامل القائمة. (ملاحظة توثيقية فقط، لا تعديل للمنطق)
      final result = await addExpense(event.expense);
      await result.fold((failure) async => emit(ExpenseError(failure.message)), (
        _,
      ) async {
        // ℹ️ ملاحظة ذرية (تنطبق على معالجي التحديث والحذف أيضاً):
        // سجل النشاط يُنشأ الآن داخل runTransaction في المستودع
        // (نمط الفواتير) — ذري مع العملية المالية، فلا حاجة
        // لكتابته هنا. انظر كتلة التحقق في المستودع.
        // الإشعارات التنظيمية (أدناه) خارج المعاملة بقصد:
        // أثر جانبي غير حاسم — فشل الإشعار لا يُفقد العملية
        // المالية ولا سجل تدقيقها، فلا تُشترط ذرّيتها.

        // إرسال إشعار تنظيمي بإضافة مصروف جديد
        // ⚠️ ملاحظة للمبرمجين المستقبليين — عدم توافق مفاتيح الإعدادات:
        // صفحة الإعدادات (expenses_settings_page.dart) تُحفظ المفاتيح تحت
        // 'expenses_notify_new' و 'expenses_alert_pending' بينما البلوك يقرأ
        // 'expense_notify_new' (بلا حرف s). ما يُحفظ في واجهة الإعدادات لن يُقرأ
        // هنا، والمفاتيح 'expense_notify_updated' و 'expense_notify_deleted' لا تُحفظ
        // أصلاً في صفحة الإعدادات. يجب توحيد مفاتيح الإشعارات بين الموضعين.
        final expenseActorEmail =
            FirebaseAuth.instance.currentUser?.email ?? '';
        if (expenseActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'expenses',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'expenses_notify_new',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.expense.organizationEmail,
                title: '💰 مصروف جديد',
                body:
                    'تم إضافة مصروف جديد: ${event.expense.title} بمبلغ ${event.expense.amount.toStringAsFixed(0)} د.ع',
                type: 'expense_created',
                actorEmail: expenseActorEmail,
                data: {'expenseId': event.expense.id},
              );
            } on Exception catch (_) {
              // فشل الإشعار لا يمنع حفظ المصروف.
            }
          }());
          // ⚠️ ملاحظة للمبرمجين المستقبليين: الإشعار يُرسل عبر unawaited ( Fire-and-forget )
          // خارج المعاملة الذرية. فشل الإشعار لا يؤثر على العملية المالية ولا سجل التدقيق،
          // لكن هذا يعني أن الإشعار قد يُفقد إذا تعطل التطبيق قبل إرساله. لا تُضف منطقاً
          // يعتمد على نجاح الإشعار هنا.
        }

        emit(const ExpenseOperationSuccess('تم إضافة المصروف بنجاح'));

        // تحديث الحالة الحالية سواء كانت محملة من طلب أو عبر stream.
        final currentState = previousState;
        if (currentState is ExpenseLoaded) {
          final updatedExpenses = <ExpenseEntity>[
            ...currentState.expenses,
            event.expense,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          emit(
            currentState.copyWith(
              expenses: updatedExpenses,
              filteredExpenses: _applyFilters(updatedExpenses),
              stats: repository.computeExpenseStats(updatedExpenses),
            ),
          );
        } else if (currentState is ExpenseStreamActive) {
          final updatedExpenses = <ExpenseEntity>[
            ...currentState.expenses,
            event.expense,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          emit(
            currentState.copyWith(
              expenses: updatedExpenses,
              filteredExpenses: _applyFilters(updatedExpenses),
              stats: repository.computeExpenseStats(updatedExpenses),
            ),
          );
        }
      });
    }
  }

  Future<void> _onUpdateExpense(
    UpdateExpenseEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state is ExpenseLoaded || state is ExpenseStreamActive) {
      final previousState = state;
      final result = await updateExpense(event.expense);
      await result.fold((failure) async => emit(ExpenseError(failure.message)), (
        _,
      ) async {
        // إرسال إشعار تنظيمي بتحديث المصروف
        final updateExpenseActorEmail =
            FirebaseAuth.instance.currentUser?.email ?? '';
        if (updateExpenseActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'expenses',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'expenses_notify_updated',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.expense.organizationEmail,
                title: '✏️ تعديل مصروف (${event.expense.title})',
                body:
                    'تم تحديث المصروف "${event.expense.title}" بمبلغ ${event.expense.amount.toStringAsFixed(0)} د.ع',
                type: 'expense_updated',
                actorEmail: updateExpenseActorEmail,
                data: {'expenseId': event.expense.id},
              );
            } on Exception catch (_) {
              // فشل الإشعار لا يمنع تحديث المصروف.
            }
          }());
          // ⚠️ إشعار Fire-and-forget — انظر الملاحظة في _onAddExpense أعلاه.
        }

        emit(const ExpenseOperationSuccess('تم تحديث المصروف بنجاح'));

        // تحديث الحالة الحالية، سواء كانت محملة مرة واحدة أو عبر stream.
        final currentState = previousState;
        if (currentState is ExpenseLoaded) {
          final updatedExpenses = currentState.expenses
              .map(
                (expense) =>
                    expense.id == event.expense.id ? event.expense : expense,
              )
              .toList();
          emit(
            currentState.copyWith(
              expenses: updatedExpenses,
              filteredExpenses: _applyFilters(updatedExpenses),
              stats: repository.computeExpenseStats(updatedExpenses),
            ),
          );
          emit(
            currentState.copyWith(
              expenses: updatedExpenses,
              filteredExpenses: _applyFilters(updatedExpenses),
              stats: repository.computeExpenseStats(updatedExpenses),
            ),
          );
        } else if (currentState is ExpenseStreamActive) {
          final updatedExpenses = currentState.expenses
              .map(
                (expense) =>
                    expense.id == event.expense.id ? event.expense : expense,
              )
              .toList();
          emit(
            currentState.copyWith(
              expenses: updatedExpenses,
              filteredExpenses: _applyFilters(updatedExpenses),
              stats: repository.computeExpenseStats(updatedExpenses),
            ),
          );
        }
      });
    }
  }

  Future<void> _onDeleteExpense(
    DeleteExpenseEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    // التحقق من الصلاحية
    final permissionChecker = PermissionChecker();
    final hasPermission = await permissionChecker.hasPermission(
      'expenses_delete',
    );

    if (!hasPermission) {
      emit(const ExpenseError('ليس لديك صلاحية لحذف المصاريف'));
      return;
    }

    if (state is ExpenseLoaded) {
      emit(ExpenseLoading());
      final result = await deleteExpense(event.id, event.organizationEmail);
      await result.fold((failure) async => emit(ExpenseError(failure.message)), (
        _,
      ) async {
        // إرسال إشعار تنظيمي بحذف المصروف
        final deleteExpenseActorEmail =
            FirebaseAuth.instance.currentUser?.email ?? '';
        if (deleteExpenseActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'expenses',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'expenses_notify_deleted',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.organizationEmail,
                title: '🗑️ حذف مصروف',
                body: 'تم حذف مصروف من النظام',
                type: 'expense_deleted',
                actorEmail: deleteExpenseActorEmail,
                data: {'expenseId': event.id},
              );
            } on Exception catch (_) {
              // فشل الإشعار لا يمنع حذف المصروف.
            }
          }());
          // ⚠️ إشعار Fire-and-forget — انظر الملاحظة في _onAddExpense أعلاه.
        }

        emit(const ExpenseOperationSuccess('تم حذف المصروف بنجاح'));

        // تحديث الحالة محلياً بدلاً من إعادة تحميل كل المصاريف من الخادم
        if (state is ExpenseLoaded) {
          final currentState = state as ExpenseLoaded;
          final updatedExpenses = <ExpenseEntity>[
            for (final e in currentState.expenses)
              if (e.id != event.id) e,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final stats = repository.computeExpenseStats(updatedExpenses);
          emit(
            currentState.copyWith(
              expenses: updatedExpenses,
              filteredExpenses: updatedExpenses,
              stats: stats,
            ),
          );
        }
      });
    }
  }

  Future<void> _onLoadExpenseStats(
    LoadExpenseStatsEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state is ExpenseLoaded) {
      final currentState = state as ExpenseLoaded;
      final result = await getExpenseStats(event.organizationEmail);
      result.fold(
        (failure) => emit(currentState.copyWith()),
        (stats) => emit(currentState.copyWith(stats: stats)),
      );
    }
  }

  void _onFilterExpenses(
    FilterExpensesEvent event,
    Emitter<ExpenseState> emit,
  ) {
    _selectedFilter = event.filter;

    if (state is ExpenseLoaded) {
      final currentState = state as ExpenseLoaded;
      final filtered = _applyFilters(_allExpenses);

      emit(
        currentState.copyWith(
          filteredExpenses: filtered,
          selectedFilter: event.filter,
        ),
      );
    } else if (state is ExpenseStreamActive) {
      final currentState = state as ExpenseStreamActive;
      final filtered = _applyFilters(_allExpenses);

      emit(
        currentState.copyWith(
          filteredExpenses: filtered,
          selectedFilter: event.filter,
        ),
      );
    }
  }

  void _onSearchExpenses(
    SearchExpensesEvent event,
    Emitter<ExpenseState> emit,
  ) {
    _searchQuery = event.query;

    if (state is ExpenseLoaded) {
      final currentState = state as ExpenseLoaded;
      final filtered = _applyFilters(_allExpenses);

      emit(
        currentState.copyWith(
          filteredExpenses: filtered,
          searchQuery: event.query,
        ),
      );
    } else if (state is ExpenseStreamActive) {
      final currentState = state as ExpenseStreamActive;
      final filtered = _applyFilters(_allExpenses);

      emit(
        currentState.copyWith(
          filteredExpenses: filtered,
          searchQuery: event.query,
        ),
      );
    }
  }

  void _onToggleViewMode(
    ToggleViewModeEvent event,
    Emitter<ExpenseState> emit,
  ) {
    _isGridView = !_isGridView;

    if (state is ExpenseLoaded) {
      final currentState = state as ExpenseLoaded;
      emit(currentState.copyWith(isGridView: _isGridView));
    } else if (state is ExpenseStreamActive) {
      final currentState = state as ExpenseStreamActive;
      emit(currentState.copyWith(isGridView: _isGridView));
    }
  }

  Future<void> _onLoadExpenseLogs(
    LoadExpenseLogsEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(ExpenseLoading());

    final params = GetExpenseLogsParams(
      searchQuery: event.searchQuery,
      actionFilter: event.actionFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: 100, // حد أقصى للنتائج
    );

    final result = await getExpenseLogs(params);

    result.fold(
      (failure) => emit(ExpenseError(failure.message)),
      (logs) => emit(ExpenseLogsLoaded(logs)),
    );
  }

  /// بدء الاستماع لسجل نشاطات المصاريف مع التحديث الفوري
  Future<void> _onStartExpenseLogsStream(
    StartExpenseLogsStreamEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد (تغيير الفلاتر يعيد الاشتراك)
    await _expenseLogsStreamSubscription?.cancel();

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is ExpenseLogsLoaded ||
        state is ExpenseStreamActive ||
        state is ExpenseLoaded;
    if (!hasExistingData) {
      emit(ExpenseLoading());
    }

    try {
      final stream = getExpenseLogsStream(
        GetExpenseLogsParams(
          userId: event.userId,
          searchQuery: event.searchQuery,
          actionFilter: event.actionFilter,
          dateFilter: event.dateFilter,
          startDate: event.startDate,
          endDate: event.endDate,
          limit: event.limit,
        ),
      );

      _expenseLogsStreamSubscription = stream.listen(
        (result) {
          // إنشاء event جديد بدلاً من emit مباشر
          add(_ExpenseLogsStreamDataReceived(result));
        },
        onError: (error) {
          add(_ExpenseLogsStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(ExpenseError('حدث خطأ غير متوقع'));
    }
  }

  /// إيقاف الاستماع لسجل نشاطات المصاريف
  Future<void> _onStopExpenseLogsStream(
    StopExpenseLogsStreamEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    await _expenseLogsStreamSubscription?.cancel();
    _expenseLogsStreamSubscription = null;
  }

  /// معالج استلام البيانات من stream سجل النشاطات
  void _onExpenseLogsStreamDataReceived(
    _ExpenseLogsStreamDataReceived event,
    Emitter<ExpenseState> emit,
  ) {
    event.result.fold(
      (failure) => emit(ExpenseError(failure.message)),
      (logs) => emit(ExpenseLogsLoaded(logs)),
    );
  }

  /// معالج استلام خطأ من stream سجل النشاطات
  void _onExpenseLogsStreamErrorReceived(
    _ExpenseLogsStreamErrorReceived event,
    Emitter<ExpenseState> emit,
  ) {
    emit(ExpenseError(event.error));
  }

  /// بدء الاستماع للمصروفات مع التحديث الفوري
  Future<void> _onStartExpensesStream(
    StartExpensesStreamEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _expensesStreamSubscription?.cancel();

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is ExpenseStreamActive || state is ExpenseLoaded;
    if (!hasExistingData) {
      emit(ExpenseLoading());
    }

    try {
      final stream = getExpensesStream(
        event.organizationEmail,
        limit: event.limit,
        searchQuery: event.searchQuery,
      );

      _expensesStreamSubscription = stream.listen(
        (result) {
          add(_ExpenseStreamDataReceived(result));
        },
        onError: (error) {
          add(_ExpenseStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(ExpenseError('حدث خطأ غير متوقع'));
    }
  }

  /// إيقاف الاستماع للمصروفات
  Future<void> _onStopExpensesStream(
    StopExpensesStreamEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    await _expensesStreamSubscription?.cancel();
    _expensesStreamSubscription = null;
  }

  /// بدء الاستماع لإحصائيات المصروفات مع التحديث الفوري
  Future<void> _onStartExpenseStatsStream(
    StartExpenseStatsStreamEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _statsStreamSubscription?.cancel();

    try {
      final stream = getExpenseStatsStream(event.organizationEmail);

      _statsStreamSubscription = stream.listen(
        (result) {
          add(_ExpenseStatsStreamDataReceived(result));
        },
        onError: (_) {
          // تجاهل خطأ stream الإحصائيات مع إبقاء الحالة الحالية.
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      // تجاهل الأخطاء في إنشاء stream الإحصائيات
    }
  }

  /// إيقاف الاستماع لإحصائيات المصروفات
  Future<void> _onStopExpenseStatsStream(
    StopExpenseStatsStreamEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
  }

  /// تطبيق الفلاتر والبحث على المصروفات
  List<ExpenseEntity> _applyFilters(List<ExpenseEntity> expenses) {
    var filtered = expenses;

    // تطبيق فلتر الحالة
    if (_selectedFilter != 'all') {
      filtered = filtered.where((expense) {
        switch (_selectedFilter) {
          case 'pending':
            return expense.isPending;
          case 'approved':
            return expense.status == 'approved';
          case 'rejected':
            return expense.status == 'rejected';
          default:
            return true;
        }
      }).toList();
    }

    // تطبيق البحث النصي
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((expense) {
        final query = _searchQuery.toLowerCase();
        return expense.title.toLowerCase().contains(query) ||
            expense.description.toLowerCase().contains(query) ||
            expense.category.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// معالج استلام البيانات من stream المصروفات
  void _onExpenseStreamDataReceived(
    _ExpenseStreamDataReceived event,
    Emitter<ExpenseState> emit,
  ) {
    event.result.fold(
      (failure) {
        emit(ExpenseError(failure.message));
      },
      (expenses) {
        // ✅ حفظ كل المصروفات للفلترة الكاملة
        _allExpenses = expenses;

        // ✅ تطبيق الحد الأقصى للعرض (10 عناصر فقط في الداشبورد)
        final limitedExpenses = expenses.length > 10
            ? expenses.sublist(0, 10)
            : expenses;

        final filteredExpenses = _applyFilters(_allExpenses);

        // ✅ تطبيق الحد الأقصى على النتائج المفلترة للعرض في الداشبورد
        final displayedFilteredExpenses = filteredExpenses.length > 10
            ? filteredExpenses.sublist(0, 10)
            : filteredExpenses;

        // ✅ التحقق من الحالة الحالية لحفظ الإحصائيات
        if (state is ExpenseLoaded) {
          final currentState = state as ExpenseLoaded;

          // ✅ التحقق من تغير البيانات قبل emit
          final expensesChanged = !listEquals(
            currentState.expenses,
            limitedExpenses,
          );
          final filteredChanged = !listEquals(
            currentState is ExpenseStreamActive
                ? currentState.filteredExpenses
                : limitedExpenses,
            displayedFilteredExpenses,
          );

          if (expensesChanged || filteredChanged) {
            emit(
              ExpenseStreamActive(
                expenses: _allExpenses,
                filteredExpenses: displayedFilteredExpenses,
                selectedFilter: _selectedFilter,
                searchQuery: _searchQuery,
                isGridView: _isGridView,
                stats: currentState.stats, // ✅ حفظ الإحصائيات
              ),
            );
          }
        } else if (state is ExpenseStreamActive) {
          final currentState = state as ExpenseStreamActive;

          // ✅ التحقق من تغير البيانات قبل emit
          final expensesChanged = !listEquals(
            currentState.expenses,
            limitedExpenses,
          );
          final filteredChanged = !listEquals(
            currentState.filteredExpenses,
            displayedFilteredExpenses,
          );

          if (expensesChanged || filteredChanged) {
            emit(
              ExpenseStreamActive(
                expenses: _allExpenses,
                filteredExpenses: displayedFilteredExpenses,
                selectedFilter: _selectedFilter,
                searchQuery: _searchQuery,
                isGridView: _isGridView,
                stats: currentState.stats, // ✅ حفظ الإحصائيات
              ),
            );
          }
        } else {
          // ===== ملاحظة للمبرمجين المستقبليين =====
          // لماذا نستخدم _pendingStats هنا؟
          // لأنه في صفحة الداشبورد، يبدأ stream الإحصائيات
          // وstream المصاريف في نفس الوقت. من المحتمل أن يصل
          // stream الإحصائيات قبل stream المصاريف.
          // إذا لم نستخدم _pendingStats، سنفقد الإحصائيات الواصلة
          // أثناء حالة ExpenseLoading، وسيتم عرض أصفار في النظرة العامة.
          // ==========================================
          final statsToUse = _pendingStats;
          _pendingStats = null; // مسح بعد الاستخدام

          emit(
            ExpenseStreamActive(
              expenses: _allExpenses,
              filteredExpenses: displayedFilteredExpenses,
              selectedFilter: _selectedFilter,
              searchQuery: _searchQuery,
              isGridView: _isGridView,
              stats: statsToUse,
            ),
          );
        }
      },
    );
  }

  /// معالج استلام خطأ من stream المصروفات
  void _onExpenseStreamErrorReceived(
    _ExpenseStreamErrorReceived event,
    Emitter<ExpenseState> emit,
  ) {
    emit(ExpenseError(event.error));
  }

  /// معالج استلام البيانات من stream الإحصائيات
  void _onExpenseStatsStreamDataReceived(
    _ExpenseStatsStreamDataReceived event,
    Emitter<ExpenseState> emit,
  ) {
    event.result.fold(
      (failure) {
        // لا نوقف التطبيق بسبب خطأ في الإحصائيات
      },
      (stats) {
        // ===== ملاحظة للمبرمجين المستقبليين =====
        // لماذا نقوم بتخزين الإحصائيات في _pendingStats عندما تكون
        // الحالة ExpenseLoading أو ExpenseInitial؟
        // لأنه في صفحة الداشبورد، يبدأ stream الإحصائيات
        // وstream المصاريف في نفس الوقت. من المحتمل أن يصل
        // stream الإحصائيات قبل stream المصاريف.
        // إذا تجاهلنا الإحصائيات في هذه الحالة، سنفقدها إلى الأبد
        // لأن stream الإحصائيات لن يعيد إرسالها ما لم يتغير
        // أي مستند في المجموعة.
        // ==========================================

        if (state is ExpenseStreamActive) {
          final currentState = state as ExpenseStreamActive;

          // ✅ التحقق من تغير الإحصائيات قبل emit
          final statsChanged = currentState.stats != stats;

          if (statsChanged) {
            emit(currentState.copyWith(stats: stats));
          }
        } else if (state is ExpenseLoaded) {
          final currentState = state as ExpenseLoaded;

          // ✅ التحقق من تغير الإحصائيات قبل emit
          final statsChanged = currentState.stats != stats;

          if (statsChanged) {
            emit(currentState.copyWith(stats: stats));
          }
        } else if (state is ExpenseLoading || state is ExpenseInitial) {
          // ✅ تخزين الإحصائيات مؤقتاً لاستخدامها عند وصول بيانات المصاريف
          _pendingStats = stats;
        }
      },
    );
  }

  @override
  Future<void> close() async {
    await _expensesStreamSubscription?.cancel();
    await _statsStreamSubscription?.cancel();
    await _expenseLogsStreamSubscription?.cancel();
    return super.close();
  }
}
