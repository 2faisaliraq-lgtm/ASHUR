import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/invoice_numbering_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/services/pdf/invoice_pdf_automation_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../../invoices/presentation/bloc/invoice_bloc.dart' as invoice_bloc;
import '../../domain/entities/equipment_entity.dart';
import '../../domain/entities/maintenance_log_entity.dart';
import '../../domain/entities/maintenance_request_entity.dart';
import '../../domain/entities/maintenance_requests_page.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/usecases/check_maintenance_permission.dart';
import '../../domain/usecases/create_maintenance_request.dart';
import '../../domain/usecases/get_equipment.dart';
import '../../domain/usecases/get_equipment_stream.dart';
import '../../domain/usecases/get_maintenance_logs_stream.dart';
import '../../domain/usecases/get_maintenance_requests.dart';
import '../../domain/usecases/get_maintenance_stats.dart';
import '../../domain/usecases/get_maintenance_stats_stream.dart';
import '../../domain/usecases/get_maintenance_stream.dart';
import '../../domain/usecases/update_maintenance_request.dart';

part 'maintenance_event.dart';
part 'maintenance_state.dart';

/// BLoC إدارة الصيانة
// ════════════════════════════════════════════════════════════════
// 📋 سجل التحقق من الذرية على مستوى BLoC (تم التحقق والإصلاح يدوياً بتاريخ 2026-10-08):
//
// ✅ إصلاح ذرية: أُزيل التسجيل المكرر للسجلات من مستوى BLoC.
//   كان BLoC يسجل العملية مرة أخرى خارج المعاملة بأنواع
//   (create_maintenance_request / update_maintenance_request /
//   delete_maintenance_request) بينما المستودع يسجلها ذرياً
//   داخل Transaction بأنواع (create / update / delete).
//   النتيجة كانت: سجلان مكرران لكل عملية، والنوع الثاني لا
//   يطابق فلاتر واجهة السجل ويظهر بشكل عام غير مفهوم.
//   الآن التسجيل يتم في مكان واحد فقط: داخل Transaction في
//   المستودع (ذرية بالكامل — إما يُسجل مع العملية أو يفشل معها).
//
// ⚠️ العمليات المتبقية غير الذرية (مقصود ومُتحقق منه):
//   - _onCreateMaintenanceRequest: إنشاء الفاتورة التلقائية + الإشعار
//     خارج المعاملة.
//   - _onUpdateMaintenanceRequest: الإشعار خارج المعاملة.
//   - _onDeleteMaintenanceRequest: الإشعار خارج المعاملة.
//
// لماذا هذا مقبول ولا يُصلح بإدخال كل شيء في Transaction:
//   1. الإشعارات وتوليد PDF آثار جانبية خارجية لا يمكن التراجع
//      عنها داخل معاملة Firestore.
//   2. الفاتورة تُنشأ في InvoiceBloc (مستودع آخر) ولا يمكن لمعاملة
//      Firestore واحدة أن تمتد عبر مستودعين.
//   3. فشل هذه العمليات الجانبية لا يجب أن يُلغي العملية الأساسية
//      (مثلاً: لا نحذف طلب صيانة فقط لأن الإشعار فشل).
//
// 🔴 قاعدة للمبرمجين المستقبليين: إذا احتجت يوماً ذرية حقيقية عبر
//   المستودعين (مثلاً: طلب صيانة + فاتورة معاً)، استخدم نمط Saga
//   أو Cloud Functions — لا تحاول دمجها في runTransaction واحد.
//
// ✅ نتيجة إعادة التحقق الدقيق (2026-10-08
// و2026-10-11 و2026-10-12 — دُمجت كتل
// التحقق المتكررة هنا) — تحقق بدون تعديل
// أي منطق: لا تسجيل سجلات مكرر — معالجات
// الإنشاء/التحديث/الحذف لا تستدعي
// addMaintenanceLog بأنواع العمليات
// (create/update/delete)؛ التسجيل الوحيد
// للعملية داخل Transaction في المستودع.
// الاستثناء المقصود: سجلات فشل الفاتورة
// التلقائية فقط (مسارات خطأ جانبية). دُمجت
// كتل "ملاحظة للمبرمجين المستقبليين" المتشابهة
// تحت المعالجات الثلاثة في إشارات موجزة
// تشير لهذه الملاحظة. لماذا هذا مهم: إضافة
// تسجيل عمليات هنا سينتج سجلين مكررين لكل
// عملية (ذري داخل المعاملة + خارجها بنوع
// لا طابقه فلاتر السجل) — لا تُعد تسجيل
// العمليات في هذا الملف أبداً.
//
// ✅ ستريمات القراءة فقط (أُضيفت 2026-10-11):
//   - ستريم المعدات (getEquipmentStream): يبدأ مع
//     ستريم الطلبات في _onStartMaintenanceStream ويُوقف
//     معه في _onStopMaintenanceStream — لتحديث المعدات
//     فورياً في الحالة. أخطاؤه تُسجل فقط ولا تُلغي
//     عرض الطلبات.
//   - ستريم سجل النشاطات (getMaintenanceLogsStream):
//     تستخدمه صفحة السجل — يُعاد تشغيله عند تغيير
//     الفلاتر ويُوقف عند إغلاق الصفحة.
//   لماذا هذا مهم: المعدات وسجل النشاطات كانا يُحمَّلان
//   بـ Future (لمرة واحدة) فلا يتحدثان فورياً عند
//   إضافة/تعديل/حذف أي عملية. الستريمات تضمن عرض
//   أحدث البيانات دون إعادة تحميل يدوية.
//   ⚠️ هذه الستريمات قراءة فقط (snapshots) — لا تحتوي
//   على كتابة أو معاملة، فلا تنطبق عليها قاعدة
//   "كل القراءات قبل كل الكتابات".
// ════════════════════════════════════════════════════════════════
class MaintenanceBloc extends Bloc<MaintenanceEvent, MaintenanceState> {
  MaintenanceBloc({
    required this.getMaintenanceRequests,
    required this.getMaintenanceStream,
    required this.getMaintenanceStatsStream,
    required this.createMaintenanceRequest,
    required this.updateMaintenanceRequest,
    required this.getEquipment,
    required this.getEquipmentStream,
    required this.getMaintenanceLogsStream,
    required this.getMaintenanceStats,
    required this.checkPermission,
    required this.repository,
  }) : super(MaintenanceInitial()) {
    on<LoadMaintenanceRequestsEvent>(_onLoadMaintenanceRequests);
    on<LoadMoreMaintenanceRequestsEvent>(_onLoadMoreMaintenanceRequests);
    on<ServerSearchMaintenanceRequestsEvent>(
      _onServerSearchMaintenanceRequests,
    );
    on<CreateMaintenanceRequestEvent>(_onCreateMaintenanceRequest);
    on<UpdateMaintenanceRequestEvent>(_onUpdateMaintenanceRequest);
    on<DeleteMaintenanceRequestEvent>(_onDeleteMaintenanceRequest);
    on<SearchMaintenanceRequestsEvent>(_onSearchMaintenanceRequests);
    on<FilterMaintenanceRequestsEvent>(_onFilterMaintenanceRequests);
    on<ToggleMaintenanceViewModeEvent>(_onToggleViewMode);
    on<LoadMaintenanceLogsEvent>(_onLoadMaintenanceLogs);

    // Stream handlers
    on<StartMaintenanceStreamEvent>(_onStartMaintenanceStream);
    on<StopMaintenanceStreamEvent>(_onStopMaintenanceStream);
    on<StartMaintenanceStatsStreamEvent>(_onStartMaintenanceStatsStream);
    on<StopMaintenanceStatsStreamEvent>(_onStopMaintenanceStatsStream);
    on<MaintenanceStreamDataReceived>(_onMaintenanceStreamDataReceived);
    on<MaintenanceStreamErrorReceived>(_onMaintenanceStreamErrorReceived);
    on<MaintenanceStatsStreamDataReceived>(
      _onMaintenanceStatsStreamDataReceived,
    );

    // Equipment stream handlers
    on<StartEquipmentStreamEvent>(_onStartEquipmentStream);
    on<StopEquipmentStreamEvent>(_onStopEquipmentStream);
    on<MaintenanceEquipmentStreamDataReceived>(
      _onMaintenanceEquipmentStreamDataReceived,
    );

    // Logs stream handlers
    on<StartMaintenanceLogsStreamEvent>(_onStartMaintenanceLogsStream);
    on<StopMaintenanceLogsStreamEvent>(_onStopMaintenanceLogsStream);
    on<MaintenanceLogsStreamDataReceived>(_onMaintenanceLogsStreamDataReceived);
  }

  final GetMaintenanceRequests getMaintenanceRequests;
  final GetMaintenanceStream getMaintenanceStream;
  final GetMaintenanceStatsStream getMaintenanceStatsStream;
  final CreateMaintenanceRequest createMaintenanceRequest;
  final UpdateMaintenanceRequest updateMaintenanceRequest;
  final GetEquipment getEquipment;
  final GetEquipmentStream getEquipmentStream;
  final GetMaintenanceLogsStream getMaintenanceLogsStream;
  final GetMaintenanceStats getMaintenanceStats;
  final CheckMaintenancePermission checkPermission;
  final MaintenanceRepository repository;

  StreamSubscription<Either<Failure, List<MaintenanceRequestEntity>>>?
  _maintenanceStreamSubscription;
  StreamSubscription<Either<Failure, Map<String, dynamic>>>?
  _maintenanceStatsStreamSubscription;
  StreamSubscription<Either<Failure, List<EquipmentEntity>>>?
  _equipmentStreamSubscription;
  StreamSubscription<Either<Failure, List<MaintenanceLogEntity>>>?
  _maintenanceLogsStreamSubscription;
  List<MaintenanceRequestEntity> _allRequests = []; // ✅ حفظ كل الطلبات للفلترة
  dynamic _lastDocument;
  bool _hasMoreData = true;
  int _currentPage = 1;
  static const int _pageSize = 20;

  Future<void> _onLoadMaintenanceRequests(
    LoadMaintenanceRequestsEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    if (event.refresh) {
      _allRequests.clear();
      _lastDocument = null;
      _hasMoreData = true;
      _currentPage = 1;
    }

    emit(MaintenanceLoading());

    try {
      // ⚡ تحسين الأداء: التحميلات الثلاثة مستقلة —
      // تُنفذ بشكل منفصل مع معالجة الأخطاء لكل واحدة
      // لتجنب فشل الكل عند فشل واحدة فقط.
      final requestsResult = await repository.getMaintenanceRequestsPaginated(
        organizationEmail: event.organizationEmail,
        limit: event.limit ?? 10,
        lastDocument: event.refresh ? null : _lastDocument,
      );

      final equipmentResult = await getEquipment(event.organizationEmail);

      final statsResult = await getMaintenanceStats(event.organizationEmail);

      requestsResult.fold(
        (failure) => emit(MaintenanceError(failure.message)),
        (page) {
          final requests = page.requests;
          equipmentResult.fold(
            (failure) => emit(MaintenanceError(failure.message)),
            (equipment) {
              statsResult.fold(
                (failure) => emit(MaintenanceError(failure.message)),
                (stats) {
                  if (event.refresh) {
                    _allRequests = requests;
                  } else {
                    _allRequests.addAll(requests);
                  }

                  // تحديث معلومات الترقيم
                  _hasMoreData = requests.length == (event.limit ?? 10);

                  // ✅ تحسين (2026-10-12): مؤشر الصفحة من
                  // نتيجة الاستعلام مباشرة بدلاً من جلب
                  // المستند مجدداً عبر معرفه (جولة شبكة
                  // زائدة بعد كل تحميل صفحة).
                  if (requests.isNotEmpty) {
                    _lastDocument = page.lastDocument;
                  }

                  emit(
                    MaintenanceLoaded(
                      requests: _allRequests,
                      filteredRequests: _allRequests,
                      equipment: equipment,
                      stats: stats,
                      currentPage: _currentPage,
                      hasMoreData: _hasMoreData,
                      lastDocument: _lastDocument,
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } on Exception catch (_) {
      emit(MaintenanceError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadMoreMaintenanceRequests(
    LoadMoreMaintenanceRequestsEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    final currentState = state;
    if (currentState is! MaintenanceLoaded &&
        currentState is! MaintenanceStreamActive) {
      return;
    }
    if (!_hasMoreData) return;

    if (currentState is MaintenanceLoaded) {
      emit(MaintenanceLoadingMore(currentState));
    } else {
      final streamState = currentState as MaintenanceStreamActive;
      emit(
        MaintenanceStreamActive(
          requests: streamState.requests,
          filteredRequests: streamState.filteredRequests,
          equipment: streamState.equipment,
          stats: streamState.stats,
          statistics: streamState.statistics,
          searchQuery: streamState.searchQuery,
          statusFilter: streamState.statusFilter,
          priorityFilter: streamState.priorityFilter,
          equipmentFilter: streamState.equipmentFilter,
          dateFilter: streamState.dateFilter,
          startDate: streamState.startDate,
          endDate: streamState.endDate,
          isGridView: streamState.isGridView,
          hasMoreData: streamState.hasMoreData,
          isLoadingMore: true,
          lastDocument: streamState.lastDocument,
        ),
      );
    }

    try {
      final requestsResult = await repository.getMaintenanceRequestsPaginated(
        organizationEmail: event.organizationEmail,
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      requestsResult.fold(
        (failure) => emit(MaintenanceError(failure.message)),
        (page) {
          final requests = page.requests;
          _allRequests.addAll(requests);
          _hasMoreData = requests.length == _pageSize;
          _currentPage++;

          // ✅ تحسين (2026-10-12): مؤشر الصفحة من نتيجة
          // الاستعلام مباشرة بدلاً من جلب المستند مجدداً
          // عبر معرفه (جولة شبكة زائدة).
          if (requests.isNotEmpty) {
            _lastDocument = page.lastDocument;
          }

          if (currentState is MaintenanceLoaded) {
            emit(
              currentState.copyWith(
                requests: _allRequests,
                filteredRequests: _allRequests,
                currentPage: _currentPage,
                hasMoreData: _hasMoreData,
                lastDocument: _lastDocument,
              ),
            );
          } else {
            final streamState = currentState as MaintenanceStreamActive;
            emit(
              MaintenanceStreamActive(
                requests: _allRequests,
                filteredRequests: _allRequests,
                equipment: streamState.equipment,
                stats: streamState.stats,
                statistics: streamState.statistics,
                searchQuery: streamState.searchQuery,
                statusFilter: streamState.statusFilter,
                priorityFilter: streamState.priorityFilter,
                equipmentFilter: streamState.equipmentFilter,
                dateFilter: streamState.dateFilter,
                startDate: streamState.startDate,
                endDate: streamState.endDate,
                isGridView: streamState.isGridView,
                hasMoreData: _hasMoreData,
                isLoadingMore: false,
                lastDocument: _lastDocument,
              ),
            );
          }
        },
      );
    } on Exception catch (_) {
      emit(MaintenanceError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onServerSearchMaintenanceRequests(
    ServerSearchMaintenanceRequestsEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    emit(MaintenanceLoading());

    try {
      final requestsResult = await repository.searchMaintenanceRequests(
        event.organizationEmail,
        event.query,
        limit: event.limit,
      );

      requestsResult.fold(
        (failure) => emit(MaintenanceError(failure.message)),
        (requests) {
          final currentState = state;
          if (currentState is MaintenanceLoaded) {
            emit(
              currentState.copyWith(
                filteredRequests: requests,
                currentPage: 1,
                hasMoreData: requests.length == event.limit,
              ),
            );
          } else {
            // إذا لم تكن البيانات محملة، نحمل البيانات الأساسية أولاً
            add(
              LoadMaintenanceRequestsEvent(
                event.organizationEmail,
                refresh: true,
              ),
            );
          }
        },
      );
    } on Exception catch (_) {
      emit(MaintenanceError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onCreateMaintenanceRequest(
    CreateMaintenanceRequestEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    try {
      // ملاحظة للمبرمجين المستقبليين: تسجيل السجل ذري داخل
      // Transaction في المستودع فقط — السبب الكامل في الملاحظة
      // الشاملة أعلى هذا الملف. غير ذري مقصود: فاتورة تلقائية
      // + إشعار (آثار جانبية خارجية؛ فشلها لا يُلغي الإنشاء).
      // 1. فحص صلاحية الإنشاء
      final permissionResult = await checkPermission('maintenance_create');
      String? permissionError;
      var hasPermission = false;
      permissionResult.fold(
        (failure) => permissionError = failure.message,
        (allowed) => hasPermission = allowed,
      );

      if (permissionError != null) {
        emit(MaintenanceError(permissionError!));
        return;
      }

      if (!hasPermission) {
        emit(const MaintenanceError('ليس لديك صلاحية لإنشاء طلبات الصيانة'));
        return;
      }

      // 2. إنشاء طلب الصيانة
      final createResult = await createMaintenanceRequest(event.request);
      String? createError;
      createResult.fold((failure) => createError = failure.message, (_) {});

      if (createError != null) {
        emit(MaintenanceError(createError!));
        return;
      }

      // 3. إنشاء الفاتورة التلقائية (التسجيل تم ذرياً في المستودع)
      final shouldCreateInvoice =
          event.request.customerId != null &&
          event.request.customerId!.isNotEmpty &&
          event.request.customerName != null &&
          event.request.customerName!.isNotEmpty &&
          event.request.estimatedCost != null &&
          event.request.estimatedCost! > 0;
      final invoiceCreated = shouldCreateInvoice
          ? await _handleAutomaticInvoiceCreation(
              event.request,
              skipCreditCheck: event.skipInvoiceCreditCheck,
            )
          : false;

      // إرسال إشعار تنظيمي بإنشاء طلب صيانة جديد
      final maintenanceActorEmail =
          FirebaseAuth.instance.currentUser?.email ?? '';
      if (maintenanceActorEmail.isNotEmpty) {
        unawaited(() async {
          try {
            final isSectionEnabled =
                await SectionNotificationService.isSectionNotificationsEnabled(
                  'maintenance',
                );
            if (!isSectionEnabled) return;
            final isTypeEnabled =
                await SettingsService.isNotificationTypeEnabled(
                  'maintenance_notify_new',
                );
            if (!isTypeEnabled) return;
            await PushNotificationService.sendOrganizationNotification(
              organizationEmail: event.request.organizationEmail,
              title: '🔧 طلب صيانة جديد',
              body:
                  'تم إنشاء طلب صيانة جديد: ${event.request.title} - ${event.request.equipmentName}',
              type: 'maintenance_created',
              actorEmail: maintenanceActorEmail,
              data: {'maintenanceId': event.request.id},
            );
          } on Exception catch (e) {
            debugPrint('Failed to send maintenance_created notification: $e');
            final currentUser = FirebaseAuth.instance.currentUser;
            unawaited(
              repository.addMaintenanceLog(
                userId: currentUser?.uid ?? 'unknown',
                userName: currentUser?.displayName,
                userEmail: currentUser?.email,
                actionType: 'notification_failed',
                details: 'فشل في إرسال إشعار إنشاء طلب الصيانة: $e',
                targetId: event.request.id,
                targetType: 'maintenance_request',
                isSuccess: false,
              ),
            );
          }
        }());
      }

      emit(
        MaintenanceOperationSuccess(
          !shouldCreateInvoice
              ? 'تم إنشاء طلب الصيانة بنجاح'
              : invoiceCreated
              ? 'تم إنشاء طلب الصيانة وفاتورته بنجاح'
              : 'تم إنشاء طلب الصيانة، لكن تعذر حفظ فاتورة الصيانة',
        ),
      );

      // 4. إعادة تحميل البيانات
      await _reloadMaintenanceData(event.request.organizationEmail, emit);
    } on Exception catch (_) {
      emit(MaintenanceError('حدث خطأ غير متوقع'));
    }
  }

  /// معالجة إنشاء فاتورة الصيانة تلقائياً إذا انطبقت الشروط
  Future<bool> _handleAutomaticInvoiceCreation(
    MaintenanceRequestEntity request, {
    required bool skipCreditCheck,
  }) async {
    if (request.customerId == null ||
        request.customerId!.isEmpty ||
        request.customerName == null ||
        request.customerName!.isEmpty ||
        request.estimatedCost == null ||
        request.estimatedCost! <= 0) {
      return true;
    }

    try {
      // إنشاء الفاتورة خطوة إضافية؛ في حال فشلها يُسجل السبب
      // ويُعاد false حتى تعرض الواجهة نتيجة غير مضللة.
      return await _createMaintenanceInvoiceAutomatically(
        request,
        skipCreditCheck: skipCreditCheck,
      );
    } on Exception catch (e) {
      final currentUser = FirebaseAuth.instance.currentUser;
      unawaited(
        repository.addMaintenanceLog(
          userId: currentUser?.uid ?? 'unknown',
          userName: currentUser?.displayName,
          userEmail: currentUser?.email,
          actionType: 'invoice_creation_failed',
          details: 'فشل في إنشاء فاتورة الصيانة تلقائياً: $e',
          targetId: request.id,
          targetType: 'maintenance_request',
          isSuccess: false,
        ),
      );
      return false;
    }
  }

  /// إعادة تحميل بيانات الصيانة والمعدات والإحصائيات
  Future<void> _reloadMaintenanceData(
    String organizationEmail,
    Emitter<MaintenanceState> emit,
  ) async {
    // ⚡ تحسين الأداء: التحميلات الثلاثة مستقلة —
    // تُنفذ بشكل منفصل مع معالجة الأخطاء لكل واحدة
    // لتجنب فشل الكل عند فشل واحدة فقط.
    final requestsResult = await getMaintenanceRequests(organizationEmail);
    final equipmentResult = await getEquipment(organizationEmail);
    final statsResult = await getMaintenanceStats(organizationEmail);

    String? errorMessage;
    List<MaintenanceRequestEntity>? loadedRequests;
    List<EquipmentEntity>? loadedEquipment;
    Map<String, dynamic>? loadedStats;

    requestsResult.fold(
      (f) => errorMessage = f.message,
      (r) => loadedRequests = r,
    );
    if (errorMessage != null) {
      emit(MaintenanceError(errorMessage!));
      return;
    }

    equipmentResult.fold(
      (f) => errorMessage = f.message,
      (e) => loadedEquipment = e,
    );
    if (errorMessage != null) {
      emit(MaintenanceError(errorMessage!));
      return;
    }

    statsResult.fold((f) => errorMessage = f.message, (s) => loadedStats = s);
    if (errorMessage != null) {
      emit(MaintenanceError(errorMessage!));
      return;
    }

    _allRequests = loadedRequests ?? [];
    emit(
      MaintenanceLoaded(
        requests: _allRequests,
        filteredRequests: _allRequests,
        equipment: loadedEquipment ?? [],
        stats: loadedStats ?? {},
      ),
    );
  }

  Future<void> _onUpdateMaintenanceRequest(
    UpdateMaintenanceRequestEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    try {
      // ملاحظة للمبرمجين المستقبليين: تسجيل السجل ذري داخل
      // Transaction في المستودع فقط — السبب الكامل في الملاحظة
      // الشاملة أعلى هذا الملف. غير ذري مقصود: إشعار (أثر
      // جانبي خارجي؛ فشله لا يُلغي التحديث).
      // فحص صلاحية التحديث
      final permissionResult = await checkPermission('maintenance_edit');
      await permissionResult.fold(
        (failure) async => emit(MaintenanceError(failure.message)),
        (hasPermission) async {
          if (!hasPermission) {
            emit(
              const MaintenanceError('ليس لديك صلاحية لتحديث طلبات الصيانة'),
            );
            return;
          }

          final result = await updateMaintenanceRequest(event.request);
          await result.fold(
            (failure) async => emit(MaintenanceError(failure.message)),
            (_) async {
              // ✅ تم التسجيل ذرياً داخل Transaction في المستودع
              // (لا يوجد تسجيل منفصل هنا — أُزيل التسجيل المكرر)
              final currentUser = FirebaseAuth.instance.currentUser;

              // إرسال إشعار تنظيمي بتحديث طلب الصيانة
              final updateMaintenanceActorEmail = currentUser?.email ?? '';
              if (updateMaintenanceActorEmail.isNotEmpty) {
                unawaited(() async {
                  try {
                    final isSectionEnabled =
                        await SectionNotificationService.isSectionNotificationsEnabled(
                          'maintenance',
                        );
                    if (!isSectionEnabled) return;
                    final isTypeEnabled =
                        await SettingsService.isNotificationTypeEnabled(
                          'maintenance_notify_updated',
                        );
                    if (!isTypeEnabled) return;
                    await PushNotificationService.sendOrganizationNotification(
                      organizationEmail: event.request.organizationEmail,
                      title: '✏️ تعديل طلب صيانة (${event.request.title})',
                      body:
                          'تم تحديث طلب صيانة الجهاز ${event.request.equipmentName} - الحالة: ${event.request.status}',
                      type: 'maintenance_updated',
                      actorEmail: updateMaintenanceActorEmail,
                      data: {'maintenanceId': event.request.id},
                    );
                  } on Exception catch (e) {
                    debugPrint(
                      'Failed to send maintenance_updated notification: $e',
                    );
                    final currentUser = FirebaseAuth.instance.currentUser;
                    unawaited(
                      repository.addMaintenanceLog(
                        userId: currentUser?.uid ?? 'unknown',
                        userName: currentUser?.displayName,
                        userEmail: currentUser?.email,
                        actionType: 'notification_failed',
                        details: 'فشل في إرسال إشعار تحديث طلب الصيانة: $e',
                        targetId: event.request.id,
                        targetType: 'maintenance_request',
                        isSuccess: false,
                      ),
                    );
                  }
                }());
              }

              emit(
                const MaintenanceOperationSuccess('تم تحديث طلب الصيانة بنجاح'),
              );
            },
          );
        },
      );
    } on Exception catch (_) {
      emit(MaintenanceError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onDeleteMaintenanceRequest(
    DeleteMaintenanceRequestEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    try {
      // ملاحظة للمبرمجين المستقبليين: تسجيل السجل ذري داخل
      // Transaction في المستودع فقط — السبب الكامل في الملاحظة
      // الشاملة أعلى هذا الملف. غير ذري مقصود: إشعار (أثر
      // جانبي خارجي؛ فشله لا يُلغي الحذف).
      // فحص صلاحية الحذف
      final permissionResult = await checkPermission('maintenance_delete');
      await permissionResult.fold(
        (failure) async => emit(MaintenanceError(failure.message)),
        (hasPermission) async {
          if (!hasPermission) {
            emit(const MaintenanceError('ليس لديك صلاحية لحذف طلبات الصيانة'));
            return;
          }

          final result = await repository.deleteMaintenanceRequest(
            event.id,
            event.organizationEmail,
          );
          await result.fold(
            (failure) async {
              emit(MaintenanceError(failure.message));
            },
            (_) async {
              // ✅ تم التسجيل ذرياً داخل Transaction في المستودع
              // (لا يوجد تسجيل منفصل هنا — أُزيل التسجيل المكرر)
              final currentUser = FirebaseAuth.instance.currentUser;

              // إرسال إشعار تنظيمي بحذف طلب الصيانة
              final deleteMaintenanceActorEmail = currentUser?.email ?? '';
              if (deleteMaintenanceActorEmail.isNotEmpty) {
                unawaited(() async {
                  try {
                    final isSectionEnabled =
                        await SectionNotificationService.isSectionNotificationsEnabled(
                          'maintenance',
                        );
                    if (!isSectionEnabled) return;
                    final isTypeEnabled =
                        await SettingsService.isNotificationTypeEnabled(
                          'maintenance_notify_deleted',
                        );
                    if (!isTypeEnabled) return;
                    await PushNotificationService.sendOrganizationNotification(
                      organizationEmail: event.organizationEmail,
                      title: '🗑️ حذف طلب صيانة',
                      body: 'تم حذف طلب صيانة من النظام',
                      type: 'maintenance_deleted',
                      actorEmail: deleteMaintenanceActorEmail,
                      data: {'maintenanceId': event.id},
                    );
                  } on Exception catch (e) {
                    debugPrint(
                      'Failed to send maintenance_deleted notification: $e',
                    );
                    final currentUser = FirebaseAuth.instance.currentUser;
                    unawaited(
                      repository.addMaintenanceLog(
                        userId: currentUser?.uid ?? 'unknown',
                        userName: currentUser?.displayName,
                        userEmail: currentUser?.email,
                        actionType: 'notification_failed',
                        details: 'فشل في إرسال إشعار حذف طلب الصيانة: $e',
                        targetId: event.id,
                        targetType: 'maintenance_request',
                        isSuccess: false,
                      ),
                    );
                  }
                }());
              }

              // إزالة الطلب من القائمة المحلية
              _allRequests.removeWhere((request) => request.id == event.id);

              // إرسال حالة النجاح
              emit(
                const MaintenanceOperationSuccess('تم حذف طلب الصيانة بنجاح'),
              );

              // إعادة تحميل البيانات
              add(LoadMaintenanceRequestsEvent(event.organizationEmail));
            },
          );
        },
      );
    } on Exception catch (_) {
      emit(MaintenanceError('حدث خطأ غير متوقع'));
    }
  }

  /// تطبيق الفلاتر على الطلبات
  List<MaintenanceRequestEntity> _applyFilters(
    List<MaintenanceRequestEntity> requests, [
    String query = '',
  ]) {
    var filtered = requests;

    // تطبيق البحث النصي
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isNotEmpty) {
      filtered = filtered.where((request) {
        return request.title.toLowerCase().contains(cleanQuery) ||
            request.description.toLowerCase().contains(cleanQuery) ||
            (request.equipmentName?.toLowerCase().contains(cleanQuery) ??
                false);
      }).toList();
    }

    return filtered;
  }

  // ⚠️ ملاحظة للمبرمجين المستقبليين: القيد بـ 10 عناصر في _onSearchMaintenanceRequests
  // و _onFilterMaintenanceRequests و _onMaintenanceStreamDataReceived مقصود للعرض في
  // لوحة التحكم فقط (تجنب إرهاق الواجهة). لنتائج كاملة استخدم
  // getMaintenanceRequestsPaginated مباشرة.
  // ✅ تم توثيق القيد يدوياً (بدون تعديل أي منطق) — قد يخفي نتائج مطابقة تتجاوز 10 عناصر.

  void _onSearchMaintenanceRequests(
    SearchMaintenanceRequestsEvent event,
    Emitter<MaintenanceState> emit,
  ) {
    final filtered = _applyFilters(_allRequests, event.query);
    final displayedFiltered = filtered.length > 10
        ? filtered.sublist(0, 10)
        : filtered;

    if (state is MaintenanceStreamActive) {
      final currentState = state as MaintenanceStreamActive;
      emit(
        currentState.copyWith(
          filteredRequests: displayedFiltered,
          searchQuery: event.query,
        ),
      );
    } else if (state is MaintenanceLoaded) {
      final currentState = state as MaintenanceLoaded;
      emit(currentState.copyWith(filteredRequests: displayedFiltered));
    }
  }

  /// تصفية طلبات الصيانة حسب الحالة والأولوية
  List<MaintenanceRequestEntity> _filterRequestsByStatusAndPriority({
    required List<MaintenanceRequestEntity> requests,
    String? status,
    String? priority,
  }) {
    return requests.where((request) {
      final matchesStatus = status == null || request.status == status;
      final matchesPriority = priority == null || request.priority == priority;
      return matchesStatus && matchesPriority;
    }).toList();
  }

  void _onFilterMaintenanceRequests(
    FilterMaintenanceRequestsEvent event,
    Emitter<MaintenanceState> emit,
  ) {
    final filtered = _filterRequestsByStatusAndPriority(
      requests: _allRequests,
      status: event.status,
      priority: event.priority,
    );

    // ✅ تطبيق الحد الأقصى على النتائج المفلترة
    // ⚠️ ملاحظة للمبرمجين المستقبليين: القيد بـ 10 عناصر مقصود للعرض في لوحة التحكم
    // فقط (تجنب إرهاق الواجهة). لنتائج كاملة استخدم getMaintenanceRequestsPaginated.
    final displayedFiltered = filtered.length > 10
        ? filtered.sublist(0, 10)
        : filtered;

    if (state is MaintenanceStreamActive) {
      final currentState = state as MaintenanceStreamActive;
      emit(
        currentState.copyWith(
          filteredRequests: displayedFiltered,
          statusFilter: event.status,
          priorityFilter: event.priority,
        ),
      );
    } else if (state is MaintenanceLoaded) {
      final currentState = state as MaintenanceLoaded;
      emit(currentState.copyWith(filteredRequests: displayedFiltered));
    }
  }

  void _onToggleViewMode(
    ToggleMaintenanceViewModeEvent event,
    Emitter<MaintenanceState> emit,
  ) {
    if (state is MaintenanceLoaded) {
      final currentState = state as MaintenanceLoaded;
      emit(currentState.copyWith(isGridView: !currentState.isGridView));
    }
  }

  Future<void> _onLoadMaintenanceLogs(
    LoadMaintenanceLogsEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    try {
      final result = await repository.getMaintenanceLogs(
        userId: event.userId,
        searchQuery: event.searchQuery,
        actionFilter: event.actionFilter,
        dateFilter: event.dateFilter,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit,
      );

      result.fold(
        (failure) => emit(MaintenanceError(failure.message)),
        (logs) => emit(MaintenanceLogsLoaded(logs)),
      );
    } on Exception catch (_) {
      emit(MaintenanceError('حدث خطأ غير متوقع'));
    }
  }

  /// إنشاء فاتورة صيانة تلقائياً
  Future<bool> _createMaintenanceInvoiceAutomatically(
    MaintenanceRequestEntity request, {
    required bool skipCreditCheck,
  }) async {
    try {
      // الفاتورة تُحفظ في InvoiceBloc بشكل مستقل عن طلب الصيانة؛
      // لذلك قد يبقى الطلب محفوظاً إذا تعذر إنشاء الفاتورة.
      // الحصول على بيانات العميل الحالية لحساب الحساب
      final customerRepository = GetIt.instance<CustomerRepository>();

      double currentBalance = 0;
      CustomerEntity? customer;

      // ⚡ تحسين الأداء: جلب مستند العميل الواحد
      // بالمعرف (قراءة O(1) لمستند واحد) بدلاً
      // من تحميل كل العملاء والبحث بينهم —
      // نفس النتيجة ونفس السلوك عند عدم الوجود
      // (الرصيد يبقى صفراً). getCustomerById يقرأ
      // من مؤسسة المستخدم الحالي (نفس مسار مجموعة
      // العملاء المطبّع) — وأُزيلت حماية firstWhere
      // من StateError معها لأن البحث لم يعد بين
      // قائمة بل مستند واحد.
      final customerResult = await customerRepository.getCustomerById(
        request.customerId!,
      );
      customerResult.fold((failure) {}, (found) {
        customer = found;
        currentBalance = customer!.totalDebt;
      });

      // حساب الحساب بعد الفاتورة (فاتورة صيانة تزيد الدين)
      final balanceAfter = currentBalance + request.estimatedCost!;

      // ملاحظة: لا نقوم بتحديث حساب العميل هنا مباشرة
      // سيتم تحديثه تلقائياً عند حفظ الفاتورة في InvoiceBloc

      // إنشاء رقم فاتورة تلقائي
      final now = DateTime.now();
      final invoiceNumber = InvoiceNumberingService.generateNumberSync(
        section: 'maintenance',
      );

      // ============================================
      // ملاحظة للمبرمجين المستقبليين:
      // تم تعريف دوال التنسيق هنا قبل استخدامها لمنع
      // خطأ referenced_before_declaration.
      // ============================================
      String formatDate(DateTime date) {
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      }

      String getPriorityName(String priority) {
        switch (priority) {
          case 'low':
            return 'منخفضة';
          case 'medium':
            return 'متوسطة';
          case 'high':
            return 'عالية';
          case 'urgent':
            return 'عاجلة';
          default:
            return priority;
        }
      }

      // إضافة بند خدمة يطابق التكلفة؛ InvoiceBloc يتحقق من تطابق
      // مجموع البنود مع إجمالي كل فاتورة غير نقدية.
      final maintenanceItem = InvoiceItemEntity(
        productName: 'صيانة - ${request.title}',
        quantity: 1,
        unit: 'خدمة',
        unitPrice: request.estimatedCost!,
        totalPrice: request.estimatedCost!,
      );

      // إنشاء الفاتورة
      final invoice = InvoiceEntity(
        id: '',
        invoiceNumber: invoiceNumber,
        customerName: request.customerName!,
        customerPhone: '',
        customerId: request.customerId,
        invoiceDate: DateTime.now(),
        totalAmount: request.estimatedCost!,
        paidAmount: 0,
        remainingAmount: request.estimatedCost!,
        status: 'unpaid',
        type: 'maintenance',
        items: [maintenanceItem],
        notes:
            '''
فاتورة صيانة تم إنشاؤها تلقائياً
العنوان: ${request.title}
الوصف: ${request.description}
المعدة: ${request.equipmentName ?? 'غير محدد'}
الأولوية: ${getPriorityName(request.priority)}
التكلفة المقدرة: ${request.estimatedCost?.toStringAsFixed(2) ?? '0.00'} د.ع
الموعد المحدد: ${request.scheduledDate != null ? formatDate(request.scheduledDate!) : 'غير محدد'}''',
        organizationEmail: request.organizationEmail,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'النظام',
        balanceBeforeInvoice: currentBalance,
        balanceAfterInvoice: balanceAfter,
      );

      // إرسال الفاتورة إلى InvoiceBloc والانتظار حتى يتم معالجتها
      if (GetIt.instance.isRegistered<invoice_bloc.InvoiceBloc>()) {
        final invoiceBloc = GetIt.instance<invoice_bloc.InvoiceBloc>();

        // إنشاء Completer للانتظار حتى يتم معالجة الفاتورة
        final completer = Completer<void>();
        StreamSubscription<invoice_bloc.InvoiceState>?
        invoiceStreamSubscription;

        invoiceStreamSubscription = invoiceBloc.stream.listen((state) {
          if (state is invoice_bloc.InvoiceCreditLimitWarning) {
            invoiceStreamSubscription?.cancel();
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('تم رفض فاتورة الصيانة بسبب تجاوز حد الدين'),
              );
            }
          } else if (state is invoice_bloc.InvoiceOperationSuccess) {
            invoiceStreamSubscription?.cancel();
            if (!completer.isCompleted) {
              completer.complete();
            }
          } else if (state is invoice_bloc.InvoiceError) {
            invoiceStreamSubscription?.cancel();
            if (!completer.isCompleted) {
              completer.completeError(state.message);
            }
          }
        });

        // موافقة المستخدم على تجاوز الحد تُمرر لتجاوز الفحص المكرر.
        invoiceBloc.add(
          invoice_bloc.AddInvoiceEvent(
            invoice,
            skipCreditCheck: skipCreditCheck,
          ),
        );

        // الانتظار حتى يتم معالجة الفاتورة (مع timeout)
        try {
          await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              invoiceStreamSubscription?.cancel();
              if (!completer.isCompleted) {
                completer.completeError(
                  Exception('انتهت المهلة أثناء معالجة الفاتورة'),
                );
              }
            },
          );
        } catch (timeoutError) {
          // تسجيل خطأ timeout
          final currentUser = FirebaseAuth.instance.currentUser;
          unawaited(
            repository.addMaintenanceLog(
              userId: currentUser?.uid ?? 'unknown',
              userName: currentUser?.displayName,
              userEmail: currentUser?.email,
              actionType: 'auto_invoice_timeout',
              details:
                  'Timeout في معالجة فاتورة الصيانة التلقائي: $timeoutError',
              targetId: request.id,
              targetType: 'maintenance_request',
              isSuccess: false,
            ),
          );
          rethrow;
        }

        // توليد وإرسال PDF تلقائياً للفاتورة
        try {
          final pdfAutomationService = InvoicePdfAutomationService();
          await pdfAutomationService.generateAndSendInvoicePdf(
            invoice: invoice,
            organizationEmail: request.organizationEmail,
          );
        } on Exception catch (pdfError) {
          // تسجيل خطأ PDF
          final currentUser = FirebaseAuth.instance.currentUser;
          unawaited(
            repository.addMaintenanceLog(
              userId: currentUser?.uid ?? 'unknown',
              userName: currentUser?.displayName,
              userEmail: currentUser?.email,
              actionType: 'auto_invoice_pdf_error',
              details: 'خطأ في توليد PDF فاتورة الصيانة التلقائي: $pdfError',
              targetId: request.id,
              targetType: 'maintenance_request',
              isSuccess: false,
            ),
          );
        }
        return true;
      } else {
        // InvoiceBloc غير مسجل
        final currentUser = FirebaseAuth.instance.currentUser;
        unawaited(
          repository.addMaintenanceLog(
            userId: currentUser?.uid ?? 'unknown',
            userName: currentUser?.displayName,
            userEmail: currentUser?.email,
            actionType: 'auto_invoice_service_unavailable',
            details: 'InvoiceBloc غير متاح لإنشاء فاتورة الصيانة التلقائي',
            targetId: request.id,
            targetType: 'maintenance_request',
            isSuccess: false,
          ),
        );
        return false;
      }
    } on Exception catch (e) {
      // تسجيل الخطأ فقط
      final currentUser = FirebaseAuth.instance.currentUser;
      unawaited(
        repository.addMaintenanceLog(
          userId: currentUser?.uid ?? 'unknown',
          userName: currentUser?.displayName,
          userEmail: currentUser?.email,
          actionType: 'auto_invoice_creation_error',
          details: 'خطأ في إنشاء فاتورة الصيانة التلقائي: $e',
          targetId: request.id,
          targetType: 'maintenance_request',
          isSuccess: false,
        ),
      );
      return false;
    }
  }

  // Stream handlers
  Future<void> _onStartMaintenanceStream(
    StartMaintenanceStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل
    // هنا لأنها تهدم الواجهة وتغلق الكيبورد — الستريم
    // سيوصل البيانات المحدثة تلقائياً
    await _maintenanceStreamSubscription?.cancel();

    final params = GetMaintenanceStreamParams(
      limit: event.limit,
      searchQuery: event.searchQuery,
      statusFilter: event.statusFilter,
      priorityFilter: event.priorityFilter,
      equipmentFilter: event.equipmentFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
    );

    _maintenanceStreamSubscription = getMaintenanceStream(params).listen((
      result,
    ) {
      result.fold(
        (failure) => add(MaintenanceStreamErrorReceived(failure.message)),
        (requests) => add(MaintenanceStreamDataReceived(requests)),
      );
    });

    // بدء ستريم المعدات للتحديث الفوري — يبدأ مع ستريم الطلبات
    // لأنهما يعرضان معاً في نفس الصفحات
    await _equipmentStreamSubscription?.cancel();
    _equipmentStreamSubscription = getEquipmentStream(NoParams()).listen((
      result,
    ) {
      result.fold(
        // أخطاء ستريم المعدات لا تُلغي عرض الطلبات — تُسجل فقط
        (failure) => debugPrint('Equipment stream error: ${failure.message}'),
        (equipment) => add(MaintenanceEquipmentStreamDataReceived(equipment)),
      );
    });
  }

  Future<void> _onStopMaintenanceStream(
    StopMaintenanceStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    await _maintenanceStreamSubscription?.cancel();
    _maintenanceStreamSubscription = null;
    await _equipmentStreamSubscription?.cancel();
    _equipmentStreamSubscription = null;
  }

  Future<void> _onStartEquipmentStream(
    StartEquipmentStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    await _equipmentStreamSubscription?.cancel();
    _equipmentStreamSubscription = getEquipmentStream(NoParams()).listen((
      result,
    ) {
      result.fold(
        (failure) => debugPrint('Equipment stream error: ${failure.message}'),
        (equipment) => add(MaintenanceEquipmentStreamDataReceived(equipment)),
      );
    });
  }

  Future<void> _onStopEquipmentStream(
    StopEquipmentStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    await _equipmentStreamSubscription?.cancel();
    _equipmentStreamSubscription = null;
  }

  void _onMaintenanceEquipmentStreamDataReceived(
    MaintenanceEquipmentStreamDataReceived event,
    Emitter<MaintenanceState> emit,
  ) {
    final currentState = state;
    if (currentState is MaintenanceStreamActive) {
      emit(currentState.copyWith(equipment: event.equipment));
    } else if (currentState is MaintenanceLoaded) {
      emit(currentState.copyWith(equipment: event.equipment));
    }
  }

  // Logs stream handlers
  Future<void> _onStartMaintenanceLogsStream(
    StartMaintenanceLogsStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    await _maintenanceLogsStreamSubscription?.cancel();
    _maintenanceLogsStreamSubscription =
        getMaintenanceLogsStream(
          GetMaintenanceLogsStreamParams(
            userId: event.userId,
            searchQuery: event.searchQuery,
            actionFilter: event.actionFilter,
            dateFilter: event.dateFilter,
            startDate: event.startDate,
            endDate: event.endDate,
            limit: event.limit,
          ),
        ).listen((result) {
          result.fold(
            (failure) => emit(MaintenanceError(failure.message)),
            (logs) => add(MaintenanceLogsStreamDataReceived(logs)),
          );
        });
  }

  Future<void> _onStopMaintenanceLogsStream(
    StopMaintenanceLogsStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    await _maintenanceLogsStreamSubscription?.cancel();
    _maintenanceLogsStreamSubscription = null;
  }

  void _onMaintenanceLogsStreamDataReceived(
    MaintenanceLogsStreamDataReceived event,
    Emitter<MaintenanceState> emit,
  ) {
    emit(MaintenanceLogsLoaded(event.logs));
  }

  Future<void> _onStartMaintenanceStatsStream(
    StartMaintenanceStatsStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    await _maintenanceStatsStreamSubscription?.cancel();

    _maintenanceStatsStreamSubscription = getMaintenanceStatsStream(NoParams())
        .listen((result) {
          result.fold(
            (failure) => add(MaintenanceStreamErrorReceived(failure.message)),
            (stats) => add(MaintenanceStatsStreamDataReceived(stats)),
          );
        });
  }

  Future<void> _onStopMaintenanceStatsStream(
    StopMaintenanceStatsStreamEvent event,
    Emitter<MaintenanceState> emit,
  ) async {
    await _maintenanceStatsStreamSubscription?.cancel();
    _maintenanceStatsStreamSubscription = null;
  }

  void _onMaintenanceStreamDataReceived(
    MaintenanceStreamDataReceived event,
    Emitter<MaintenanceState> emit,
  ) {
    // ✅ حفظ كل الطلبات للفلترة الكاملة
    _allRequests = event.requests;

    // ✅ استخراج الفلاتر من الحالة الحالية إن وجدت
    String currentSearchQuery = '';
    String? currentStatusFilter;
    String? currentPriorityFilter;

    if (state is MaintenanceStreamActive) {
      final currentState = state as MaintenanceStreamActive;
      currentSearchQuery = currentState.searchQuery;
      currentStatusFilter = currentState.statusFilter;
      currentPriorityFilter = currentState.priorityFilter;
    }

    // ✅ تطبيق البحث النصي على كل البيانات
    var filteredRequests = _applyFilters(_allRequests, currentSearchQuery);

    // ✅ تطبيق فلاتر الحالة والأولوية من الحالة الحالية
    filteredRequests = _filterRequestsByStatusAndPriority(
      requests: filteredRequests,
      status: currentStatusFilter,
      priority: currentPriorityFilter,
    );

    // ✅ تطبيق الحد الأقصى على النتائج المفلترة للعرض في الداشبورد
    // ⚠️ ملاحظة للمبرمجين المستقبليين: القيد بـ 10 عناصر مقصود للعرض في لوحة التحكم
    // فقط (تجنب إرهاق الواجهة). لنتائج كاملة استخدم getMaintenanceRequestsPaginated.
    final displayedFilteredRequests = filteredRequests.length > 10
        ? filteredRequests.sublist(0, 10)
        : filteredRequests;

    // تطبيق الفلتر إذا كان هناك حالة سابقة
    if (state is MaintenanceStreamActive) {
      final currentState = state as MaintenanceStreamActive;

      // ✅ التحقق من تغير البيانات قبل emit
      final requestsChanged = !listEquals(currentState.requests, _allRequests);
      final filteredRequestsChanged = !listEquals(
        currentState.filteredRequests,
        displayedFilteredRequests,
      );

      if (requestsChanged || filteredRequestsChanged) {
        emit(
          currentState.copyWith(
            requests: _allRequests,
            filteredRequests: displayedFilteredRequests,
            searchQuery: currentSearchQuery, // ✅ حفظ كلمة البحث
            statusFilter: currentStatusFilter, // ✅ حفظ فلتر الحالة
            priorityFilter: currentPriorityFilter, // ✅ حفظ فلتر الأولوية
            statistics: currentState.statistics, // ✅ حفظ الإحصائيات
          ),
        );
      }
    } else if (state is MaintenanceLoaded) {
      final currentState = state as MaintenanceLoaded;

      emit(
        MaintenanceStreamActive(
          requests: _allRequests,
          filteredRequests: displayedFilteredRequests,
          statusFilter: currentStatusFilter,
          priorityFilter: currentPriorityFilter,
          searchQuery: currentSearchQuery,
          statistics: null,
          isGridView: currentState.isGridView,
          hasMoreData: currentState.hasMoreData,
          lastDocument: currentState.lastDocument,
        ),
      );
    } else {
      emit(
        MaintenanceStreamActive(
          requests: _allRequests,
          filteredRequests: filteredRequests,
          statusFilter: currentStatusFilter,
          priorityFilter: currentPriorityFilter,
          searchQuery: currentSearchQuery,
        ),
      );
    }
  }

  void _onMaintenanceStreamErrorReceived(
    MaintenanceStreamErrorReceived event,
    Emitter<MaintenanceState> emit,
  ) {
    emit(MaintenanceError(event.error));
  }

  void _onMaintenanceStatsStreamDataReceived(
    MaintenanceStatsStreamDataReceived event,
    Emitter<MaintenanceState> emit,
  ) {
    // ✅ التحقق من تغير الإحصائيات قبل emit
    final statsChanged = state is MaintenanceStreamActive
        ? (state as MaintenanceStreamActive).statistics != event.statistics
        : true;

    if (statsChanged) {
      if (state is MaintenanceStreamActive) {
        final currentState = state as MaintenanceStreamActive;
        emit(currentState.copyWith(statistics: event.statistics));
      }
    }
  }

  @override
  Future<void> close() async {
    await _maintenanceStreamSubscription?.cancel();
    _maintenanceStreamSubscription = null;
    await _maintenanceStatsStreamSubscription?.cancel();
    _maintenanceStatsStreamSubscription = null;
    await _equipmentStreamSubscription?.cancel();
    _equipmentStreamSubscription = null;
    await _maintenanceLogsStreamSubscription?.cancel();
    _maintenanceLogsStreamSubscription = null;
    return super.close();
  }
}
