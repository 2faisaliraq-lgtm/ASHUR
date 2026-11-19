import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_log_entity.dart';
import '../../domain/entities/report_stats_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/add_report.dart';
import '../../domain/usecases/delete_report.dart';
import '../../domain/usecases/get_report_logs.dart';
import '../../domain/usecases/get_report_stats.dart';
import '../../domain/usecases/get_reports.dart';
import '../../domain/usecases/get_reports_stats_stream.dart';
import '../../domain/usecases/get_reports_stream.dart';
import '../../domain/usecases/update_report.dart';

part 'report_event.dart';
part 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc({
    required this.getReports,
    required this.getReportsStream,
    required this.getReportsStatsStream,
    required this.addReport,
    required this.updateReport,
    required this.deleteReport,
    required this.getReportStats,
    required this.getReportLogs,
    required this.repository,
  }) : super(ReportInitial()) {
    on<LoadReportsEvent>(_onLoadReports);
    on<LoadMoreReportsEvent>(_onLoadMoreReports);
    on<AddReportEvent>(_onAddReport);
    on<UpdateReportEvent>(_onUpdateReport);
    on<DeleteReportEvent>(_onDeleteReport);
    on<LoadReportStatsEvent>(_onLoadReportStats);
    on<FilterReportsEvent>(_onFilterReports);
    on<SearchReportsEvent>(_onSearchReports);
    on<ToggleViewModeEvent>(_onToggleViewMode);
    on<LoadReportLogsEvent>(_onLoadReportLogs);

    // Stream handlers
    on<StartReportsStreamEvent>(_onStartReportsStream);
    on<StopReportsStreamEvent>(_onStopReportsStream);
    on<StartReportsStatsStreamEvent>(_onStartReportsStatsStream);
    on<StopReportsStatsStreamEvent>(_onStopReportsStatsStream);
    on<ReportsStreamDataReceived>(_onReportsStreamDataReceived);
    on<ReportsStreamErrorReceived>(_onReportsStreamErrorReceived);
    on<ReportsStatsStreamDataReceived>(_onReportsStatsStreamDataReceived);
  }
  final GetReports getReports;
  final GetReportsStream getReportsStream;
  final GetReportsStatsStream getReportsStatsStream;
  final AddReport addReport;
  final UpdateReport updateReport;
  final DeleteReport deleteReport;
  final GetReportStats getReportStats;
  final GetReportLogs getReportLogs;
  final ReportRepository repository;

  StreamSubscription<Either<Failure, List<ReportEntity>>>?
  _reportsStreamSubscription;
  StreamSubscription<Either<Failure, Map<String, int>>>?
  _reportsStatsStreamSubscription;

  // تمرير التقارير
  dynamic _lastDocumentReports;
  bool _isLoadingMoreReports = false;
  bool _hasMoreReportsData = true;

  Future<void> _onLoadReports(
    LoadReportsEvent event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    _lastDocumentReports = null;
    _hasMoreReportsData = true;
    final result = await getReports(event.organizationEmail);
    result.fold((failure) => emit(ReportError(failure.message)), (reports) {
      // ⚠️ حساب الإحصائيات من القائمة المحملة أصلاً في
      // الذاكرة بدلاً من getReportStats الذي يقرأ كل
      // التقارير من Firestore مرة ثانية فقط للعدّ —
      // كان يضاعف زمن التحميل ويستهلك قراءات إضافية.
      // العدّ المحلي فوري ونفس النتيجة (نفس حقول
      // العدّ في getReportStats) لأن GetReports
      // يجلب كل التقارير بلا حدّ
      final stats = _computeStatsFromReports(reports);

      emit(
        ReportLoaded(
          reports: reports,
          filteredReports: reports,
          selectedFilter: 'all',
          searchQuery: '',
          stats: stats,
          isGridView: false,
        ),
      );
    });
  }

  Future<void> _onLoadMoreReports(
    LoadMoreReportsEvent event,
    Emitter<ReportState> emit,
  ) async {
    if (_isLoadingMoreReports || !_hasMoreReportsData) return;

    final currentState = state;
    if (currentState is! ReportLoaded) return;
    _isLoadingMoreReports = true;
    emit(currentState.copyWith(isLoadingMoreReports: true));

    try {
      final result = await repository.getReportsPaginated(
        organizationEmail: event.organizationEmail,
        limit: 20,
        lastDocument: _lastDocumentReports,
      );

      result.fold((failure) => emit(ReportError(failure.message)), (page) {
        if (page.reports.isNotEmpty) {
          _lastDocumentReports = page.lastDocument;
          final currentReports = <ReportEntity>[];
          final currentState = state;
          if (currentState is ReportLoaded) {
            currentReports.addAll(currentState.reports);
          }
          currentReports.addAll(page.reports);
          _hasMoreReportsData = page.reports.length >= 20;

          final stats = _computeStatsFromReports(currentReports);
          final currentFilter = currentState is ReportLoaded
              ? currentState.selectedFilter
              : (currentState is ReportsStreamActive
                    ? currentState.selectedFilter
                    : 'all');
          final currentSearchQuery = currentState is ReportLoaded
              ? currentState.searchQuery
              : (currentState is ReportsStreamActive
                    ? currentState.searchQuery
                    : '');

          emit(
            ReportLoaded(
              reports: currentReports,
              filteredReports: _applyFilters(
                reports: currentReports,
                selectedFilter: currentFilter,
                searchQuery: currentSearchQuery,
              ),
              selectedFilter: currentFilter,
              searchQuery: currentSearchQuery,
              stats: stats,
              isGridView: false,
              hasMoreReportsData: _hasMoreReportsData,
              isLoadingMoreReports: false,
              lastDocumentReports: _lastDocumentReports,
            ),
          );
        } else {
          _hasMoreReportsData = false;
          final currentState = state;
          if (currentState is ReportLoaded) {
            emit(
              currentState.copyWith(
                hasMoreReportsData: false,
                isLoadingMoreReports: false,
              ),
            );
          }
        }
        _isLoadingMoreReports = false;
      });
    } on Exception catch (_) {
      _isLoadingMoreReports = false;
      final currentState = state;
      if (currentState is ReportLoaded) {
        emit(currentState.copyWith(isLoadingMoreReports: false));
      }
      emit(ReportError('حدث خطأ غير متوقع'));
    }
  }

  /// حساب إحصائيات التقارير من قائمة محملة في الذاكرة
  /// ⚠️ بديل محلي سريع لـ getReportStats — نفس العدّ
  /// (حسب الحالة والنوع) بدون قراءة Firestore إضافية
  ReportStatsEntity _computeStatsFromReports(List<ReportEntity> reports) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final monthlyReports = reports.where((report) {
      final createdAt = report.createdAt;
      return !createdAt.isBefore(thisMonth) && createdAt.isBefore(nextMonth);
    }).length;

    return ReportStatsEntity(
      totalReports: reports.length,
      pendingReports: reports
          .where((r) => r.status.toLowerCase() == 'pending')
          .length,
      completedReports: reports
          .where((r) => r.status.toLowerCase() == 'completed')
          .length,
      failedReports: reports
          .where((r) => r.status.toLowerCase() == 'failed')
          .length,
      financialReports: reports.where((r) => r.type == 'financial').length,
      inventoryReports: reports.where((r) => r.type == 'inventory').length,
      salesReports: reports.where((r) => r.type == 'sales').length,
      monthlyReports: monthlyReports,
    );
  }

  /// تطبيق فلتر الحالة/النوع والبحث النصي على قائمة تقارير
  /// ⚠️ مشتركة بين _onFilterReports و _onSearchReports و
  /// _onReportsStreamDataReceived — أي تغيير في منطق
  /// الفلترة يُطبَّق على الثلاثة من هنا فقط
  List<ReportEntity> _applyFilters({
    required List<ReportEntity> reports,
    required String selectedFilter,
    required String searchQuery,
  }) {
    var filtered = reports;

    if (selectedFilter == 'this_month') {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month);
      final startOfNextMonth = DateTime(now.year, now.month + 1);
      filtered = filtered
          .where(
            (report) =>
                !report.createdAt.isBefore(startOfMonth) &&
                report.createdAt.isBefore(startOfNextMonth),
          )
          .toList();
    } else if (selectedFilter != 'all') {
      if (selectedFilter == 'pending' ||
          selectedFilter == 'completed' ||
          selectedFilter == 'failed') {
        filtered = filtered.where((r) => r.status == selectedFilter).toList();
      } else {
        filtered = filtered.where((r) => r.type == selectedFilter).toList();
      }
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (r) =>
                r.title.toLowerCase().contains(query) ||
                r.description.toLowerCase().contains(query),
          )
          .toList();
    }

    return filtered;
  }

  Future<void> _onAddReport(
    AddReportEvent event,
    Emitter<ReportState> emit,
  ) async {
    // ⚠️ لا شرط على حالة الـ BLoC — صفحة الإنشاء تفتح بـ BLoC جديد
    // بحالة ReportInitial (انظر مسار createReport في reports_routes.dart)
    // فشرط "state is ReportLoaded" كان يتجاهل الحدث فلا يُنشأ التقرير
    // أبداً مع عرض نجاح كاذب. إعادة الجلب بعد الإضافة تعمل من أي حالة.
    final result = await addReport(event.report);
    result.fold((failure) => emit(ReportError(failure.message)), (reportId) {
      // تسجيل العملية في السجل
      // ⚠️ targetId = المعرف المُعاد من addReport (يُولَّد داخل المعاملة
      // الذرية) — event.report.id يصل فارغاً من صفحة الإنشاء فلا يُستخدم
      unawaited(
        repository.addReportLog(
          userId: 'current_user',
          actionType: 'add_report',
          details: 'تم إضافة تقرير جديد: ${event.report.title}',
          targetId: reportId,
          targetType: 'report',
          newValues: {
            'title': event.report.title,
            'description': event.report.description,
            'type': event.report.type,
            'status': event.report.status,
            'startDate': event.report.startDate.toIso8601String(),
            'endDate': event.report.endDate.toIso8601String(),
            'data': event.report.data,
          },
        ),
      );

      emit(const ReportOperationSuccess('تم إضافة التقرير بنجاح'));
      // ⚠️ إعادة تحميل التقارير بعد كل إضافة ناجحة، حتى لو كانت الحالة
      // ReportsStreamActive (الستريم نشط). هذا قد يسبب تحميلًا مزدوجًا:
      // الستريم يرسل تحديثًا تلقائيًا بعد إضافة المستند، وLoadReportsEvent
      // يرسل طلبًا يدويًا إضافيًا. يُنصح بتفادي الإضافة إذا كان الستريم نشطًا
      // والاعتماد على التحديث التلقائي من الستريم.
      add(LoadReportsEvent(event.report.organizationEmail));
    });
  }

  Future<void> _onUpdateReport(
    UpdateReportEvent event,
    Emitter<ReportState> emit,
  ) async {
    // ⚠️ لا شرط على حالة الـ BLoC — نفس سبب _onAddReport (انظر التعليق هناك)
    final result = await updateReport(event.report);
    result.fold((failure) => emit(ReportError(failure.message)), (_) {
      // تسجيل العملية في السجل
      unawaited(
        repository.addReportLog(
          userId: 'current_user',
          actionType: 'update_report',
          details: 'تم تحديث التقرير: ${event.report.title}',
          targetId: event.report.id,
          targetType: 'report',
          newValues: {
            'title': event.report.title,
            'description': event.report.description,
            'type': event.report.type,
            'status': event.report.status,
            'startDate': event.report.startDate.toIso8601String(),
            'endDate': event.report.endDate.toIso8601String(),
            'data': event.report.data,
          },
        ),
      );

      emit(const ReportOperationSuccess('تم تحديث التقرير بنجاح'));
      // إعادة تحميل القائمة حتى لو كان العرض الحالي يستمع إلى stream.
      add(LoadReportsEvent(event.report.organizationEmail));
    });
  }

  Future<void> _onDeleteReport(
    DeleteReportEvent event,
    Emitter<ReportState> emit,
  ) async {
    if (state is ReportLoaded) {
      final currentState = state as ReportLoaded;
      final result = await deleteReport(event.id, event.organizationEmail);
      result.fold((failure) => emit(ReportError(failure.message)), (_) {
        // تسجيل العملية في السجل
        unawaited(
          repository.addReportLog(
            userId: 'current_user',
            actionType: 'delete_report',
            details: 'تم حذف التقرير',
            targetId: event.id,
            targetType: 'report',
          ),
        );

        add(LoadReportsEvent(event.organizationEmail));
        // ⚠️ إذا كانت الحالة ReportsStreamActive أيضًا (الستريم نشط)،
        // هذا التحميل اليدوي مكرر لأن الستريم سيرسل تحديثًا تلقائيًا بعد الحذف.
        // يُنصح بالتحقق من ReportsStreamActive أولًا وتجنب التحميل اليدوي في هذه الحالة.
      });
    } else if (state is ReportsStreamActive) {
      final result = await deleteReport(event.id, event.organizationEmail);
      result.fold((failure) => emit(ReportError(failure.message)), (_) {
        // تسجيل العملية في السجل
        unawaited(
          repository.addReportLog(
            userId: 'current_user',
            actionType: 'delete_report',
            details: 'تم حذف التقرير',
            targetId: event.id,
            targetType: 'report',
          ),
        );

        add(LoadReportsEvent(event.organizationEmail));
      });
    } else {
      // ⚠️ تم إضافة هذه الحالة لإظهار خطأ واضح عندما يكون الحذف
      // في حالة غير مدعومة (مثل ReportInitial أو ReportLoading)
      // بدلاً من تجاهل الحدث بصمت.
      emit(
        ReportError('لا يمكن الحذف في الحالة الحالية، يرجى إعادة تحميل الصفحة'),
      );
    }
  }

  Future<void> _onLoadReportStats(
    LoadReportStatsEvent event,
    Emitter<ReportState> emit,
  ) async {
    // ⚠️ تم توسيع الدعم ليشمل حالتي ReportLoaded و ReportsStreamActive
    // حتى يمكن تحديث الإحصائيات من الداشبورد الذي يستخدم الستريم.
    // ⚠️ الكود مكرر تمامًا للحالتين — يمكن استخلاص دالة مساعدة
    // لتجنب التكرار وتقليل احتمالية حدوث خطأ عند التعديل في المستقبل.
    if (state is ReportLoaded) {
      final currentState = state as ReportLoaded;
      final result = await getReportStats(event.organizationEmail);
      result.fold(
        (failure) => emit(currentState.copyWith()),
        (stats) => emit(currentState.copyWith(stats: stats)),
      );
    } else if (state is ReportsStreamActive) {
      final currentState = state as ReportsStreamActive;
      final result = await getReportStats(event.organizationEmail);
      result.fold(
        (failure) => emit(currentState.copyWith()),
        (stats) => emit(currentState.copyWith(stats: stats)),
      );
    }
    // إذا كانت الحالة ReportInitial أو ReportLoading، لا نحدث الإحصائيات
  }

  void _onFilterReports(FilterReportsEvent event, Emitter<ReportState> emit) {
    if (state is ReportsStreamActive) {
      final currentState = state as ReportsStreamActive;
      emit(
        currentState.copyWith(
          filteredReports: _applyFilters(
            reports: currentState.reports,
            selectedFilter: event.filter,
            searchQuery: currentState.searchQuery,
          ),
          selectedFilter: event.filter,
        ),
      );
    } else if (state is ReportLoaded) {
      final currentState = state as ReportLoaded;
      emit(
        currentState.copyWith(
          filteredReports: _applyFilters(
            reports: currentState.reports,
            selectedFilter: event.filter,
            searchQuery: currentState.searchQuery,
          ),
          selectedFilter: event.filter,
        ),
      );
    }
  }

  void _onSearchReports(SearchReportsEvent event, Emitter<ReportState> emit) {
    if (state is ReportsStreamActive) {
      final currentState = state as ReportsStreamActive;
      emit(
        currentState.copyWith(
          filteredReports: _applyFilters(
            reports: currentState.reports,
            selectedFilter: currentState.selectedFilter,
            searchQuery: event.query,
          ),
          searchQuery: event.query,
        ),
      );
    } else if (state is ReportLoaded) {
      final currentState = state as ReportLoaded;
      emit(
        currentState.copyWith(
          filteredReports: _applyFilters(
            reports: currentState.reports,
            selectedFilter: currentState.selectedFilter,
            searchQuery: event.query,
          ),
          searchQuery: event.query,
        ),
      );
    }
  }

  void _onToggleViewMode(ToggleViewModeEvent event, Emitter<ReportState> emit) {
    if (state is ReportLoaded) {
      final currentState = state as ReportLoaded;
      emit(currentState.copyWith(isGridView: !currentState.isGridView));
    }
  }

  Future<void> _onLoadReportLogs(
    LoadReportLogsEvent event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());

    final params = GetReportLogsParams(
      searchQuery: event.searchQuery,
      actionFilter: event.actionFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: 100, // حد أقصى للنتائج
    );

    final result = await getReportLogs(params);

    result.fold(
      (failure) => emit(ReportError(failure.message)),
      (logs) => emit(ReportLogsLoaded(logs)),
    );
  }

  // Stream handlers
  Future<void> _onStartReportsStream(
    StartReportsStreamEvent event,
    Emitter<ReportState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل
    // هنا لأنها تهدم الواجهة وتغلق الكيبورد — الستريم
    // سيوصل البيانات المحدثة تلقائياً
    await _reportsStreamSubscription?.cancel();

    final params = GetReportsStreamParams(
      limit: event.limit,
      searchQuery: event.searchQuery,
      typeFilter: event.typeFilter,
      statusFilter: event.statusFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
    );

    _reportsStreamSubscription = getReportsStream(params).listen((result) {
      result.fold(
        (failure) => add(ReportsStreamErrorReceived(failure.message)),
        (reports) => add(ReportsStreamDataReceived(reports)),
      );
    });
  }

  Future<void> _onStopReportsStream(
    StopReportsStreamEvent event,
    Emitter<ReportState> emit,
  ) async {
    await _reportsStreamSubscription?.cancel();
    _reportsStreamSubscription = null;
  }

  Future<void> _onStartReportsStatsStream(
    StartReportsStatsStreamEvent event,
    Emitter<ReportState> emit,
  ) async {
    await _reportsStatsStreamSubscription?.cancel();

    _reportsStatsStreamSubscription = getReportsStatsStream(NoParams()).listen((
      result,
    ) {
      result.fold(
        (failure) => add(ReportsStreamErrorReceived(failure.message)),
        (stats) => add(ReportsStatsStreamDataReceived(stats)),
      );
    });
  }

  Future<void> _onStopReportsStatsStream(
    StopReportsStatsStreamEvent event,
    Emitter<ReportState> emit,
  ) async {
    await _reportsStatsStreamSubscription?.cancel();
    _reportsStatsStreamSubscription = null;
  }

  void _onReportsStreamDataReceived(
    ReportsStreamDataReceived event,
    Emitter<ReportState> emit,
  ) {
    // ⚠️ لم يعد هناك حد أقصى ثابت (10 عناصر) في البلوك.
    // كان الحد يُطبق على جميع الصفحات (الداشبورد والقائمة)
    // مما يمنع عرض أكثر من 10 تقارير في صفحة القائمة رغم
    // أن Firestore ترسلها جميعها (limit: null).
    // التحكم في عدد العناصر المعروضة مسؤولية واجهة المستخدم
    // (ReportGrid / ReportListPage)، وليس bloc.
    final allReports = event.reports;

    // تطبيق الفلتر إذا كان هناك حالة سابقة
    if (state is ReportsStreamActive) {
      final currentState = state as ReportsStreamActive;

      // ✅ إعادة تطبيق الفلاتر من الحالة الحالية
      // (عبر _applyFilters المشتركة — نفس منطق
      // _onFilterReports و _onSearchReports)
      final filteredReports = _applyFilters(
        reports: allReports,
        selectedFilter: currentState.selectedFilter,
        searchQuery: currentState.searchQuery,
      );

      emit(
        currentState.copyWith(
          reports: allReports,
          filteredReports: filteredReports,
          statistics: currentState.statistics, // ✅ حفظ الإحصائيات
        ),
      );
    } else if (state is ReportLoaded) {
      final currentState = state as ReportLoaded;
      emit(
        ReportsStreamActive(
          reports: allReports,
          filteredReports: _applyFilters(
            reports: allReports,
            selectedFilter: currentState.selectedFilter,
            searchQuery: currentState.searchQuery,
          ),
          selectedFilter: currentState.selectedFilter,
          searchQuery: currentState.searchQuery,
          stats: currentState.stats,
          statistics:
              currentState.statistics, // ✅ الحفاظ على الإحصائيات عند التبديل
          isGridView: currentState.isGridView,
        ),
      );
    } else {
      emit(
        ReportsStreamActive(reports: allReports, filteredReports: allReports),
      );
    }
  }

  void _onReportsStreamErrorReceived(
    ReportsStreamErrorReceived event,
    Emitter<ReportState> emit,
  ) {
    emit(ReportError(event.error));
  }

  void _onReportsStatsStreamDataReceived(
    ReportsStatsStreamDataReceived event,
    Emitter<ReportState> emit,
  ) {
    // ⚠️ تم توسيع الدعم ليشمل حالتي ReportsStreamActive و ReportLoaded
    // حتى لا تُتجاهل بيانات الإحصائيات الواردة من الستريم في وضع التحميل العادي.
    if (state is ReportsStreamActive) {
      final currentState = state as ReportsStreamActive;
      emit(currentState.copyWith(statistics: event.statistics));
    } else if (state is ReportLoaded) {
      final currentState = state as ReportLoaded;
      emit(currentState.copyWith(statistics: event.statistics));
    }
  }

  @override
  Future<void> close() async {
    await _reportsStreamSubscription?.cancel();
    _reportsStreamSubscription = null;
    await _reportsStatsStreamSubscription?.cancel();
    _reportsStatsStreamSubscription = null;
    return super.close();
  }
}
