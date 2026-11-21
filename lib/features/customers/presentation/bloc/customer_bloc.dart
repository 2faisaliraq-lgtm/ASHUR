import 'dart:async';

import 'package:ashur/core/services/logger_service.dart';
import 'package:ashur/core/services/push_notification_service.dart';
import 'package:ashur/core/services/section_notification_service.dart';
import 'package:ashur/core/services/session_service.dart';
import 'package:ashur/core/services/settings_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_group_entity.dart';
import '../../domain/entities/customer_log_entity.dart';
import '../../domain/entities/customer_stats_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/add_customer.dart';
import '../../domain/usecases/add_customer_with_opening_balance.dart';
import '../../domain/usecases/delete_customer.dart';
import '../../domain/usecases/get_customer_logs.dart';
import '../../domain/usecases/get_customer_stats.dart';
import '../../domain/usecases/get_customer_stats_stream.dart';
import '../../domain/usecases/get_customers.dart';
import '../../domain/usecases/get_customers_paginated.dart';
import '../../domain/usecases/get_customers_stream.dart';
import '../../domain/usecases/update_customer.dart';
import '../../domain/validators/customer_validator.dart';

part 'customer_event.dart';
part 'customer_state.dart';

// ===== ملاحظة للمبرمجين المستقبليين =====
// عمليات تسجيل السجل (addCustomerLog / deleteCustomerLog) ذرية بالفعل
// داخل CustomerRepositoryImpl عبر runTransaction، لأن كل عملية منهما
// تتكون من جزئين: إنشاء/حذف مستند السجل + تحديث قائمة السجلات (logIds)
// في مستند العميل. لذلك لا تحتاج إلى معاملة إضافية في BLoC.
// العمليات الذرية الأخرى موجودة في CustomerRepositoryImpl
// وتستخدم runTransaction أو WriteBatch.
//
// ⚠️ تحقق الذرية (للمبرمجين المستقبليين):
//   كتابة سجل التدقيق (addCustomerLog) في هذا الـ BLoC تتم عبر
//   unawaited(...) كمعاملة منفصلة بعد العملية الأساسية — أي أن
//   "إنشاء/تحديث/حذف عميل + تسجيل سجله" ليست ذرية معاً. هذا مقبول
//   لأن السجل مساعد (auxiliary)، لكن إذا فشلت كتابة السجل يبقى
//   العميل موجوداً بدون سجل تدقيق. لا تُدمج العمليتان في
//   runTransaction واحد من الـ BLoC لأن حدود الـ repository تفصلهما
//   — وإذا احتجت ذرية كاملة مستقبلاً فالحل في طبقة الـ repository.
//
// ⚠️ حقل `totalDebt` حقل تراكمي — قاعدة واحدة تُطبَّق في كل
//   معالجات هذا الملف (لا تُكرَّر ملاحظتها في كل معالج):
//   يُحدَّث ذرياً فقط داخل runTransaction في
//   CustomerRepositoryImpl (أو عبر FieldValue.increment) — في
//   addCustomerWithOpeningBalance بناءً على الرصيد الافتتاحي،
//   وفي معاملات الفواتير في invoice_repository_impl. لا تحسبه
//   خارج العمليات الذرية إلا إذا كنت تريد تعديله يدوياً في
//   منطق الفواتير لاحقاً. عند حذف عميل: فواتيره لا تُحذف بل
//   يتحول customerId فيها إلى 'deleted_customer' (في
//   deleteCustomer) — فلا دخل لتحديث totalDebt يدوياً عند
//   الحذف. قيمته الصالحة: موجب (مدين) أو سالب (دائن) أو صفر
//   (متوازن) — لذلك لا يُرفض هنا ولا يُحسب من الكيان.
// ==========================================

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc({
    required this.getCustomers,
    required this.getCustomersPaginated,
    required this.getCustomersStream,
    required this.getCustomerStatsStream,
    required this.addCustomer,
    required this.addCustomerWithOpeningBalance,
    required this.updateCustomer,
    required this.deleteCustomer,
    required this.getCustomerStats,
    required this.getCustomerLogs,
    required this.repository,
  }) : super(CustomerInitial()) {
    on<LoadCustomersEvent>(_onLoadCustomers);
    on<LoadCustomersPaginatedEvent>(_onLoadCustomersPaginated);
    on<LoadMoreCustomersEvent>(_onLoadMoreCustomers);
    on<StartCustomersStreamEvent>(_onStartCustomersStream);
    on<StopCustomersStreamEvent>(_onStopCustomersStream);
    on<StartCustomerStatsStreamEvent>(_onStartCustomerStatsStream);
    on<StopCustomerStatsStreamEvent>(_onStopCustomerStatsStream);
    on<StartCustomerGroupsStreamEvent>(_onStartCustomerGroupsStream);
    on<StopCustomerGroupsStreamEvent>(_onStopCustomerGroupsStream);
    on<AddCustomerEvent>(_onAddCustomer);
    on<UpdateCustomerEvent>(_onUpdateCustomer);
    on<DeleteCustomerEvent>(_onDeleteCustomer);
    on<LoadCustomerStatsEvent>(_onLoadCustomerStats);
    on<FilterCustomersEvent>(_onFilterCustomers);
    on<SearchCustomersEvent>(_onSearchCustomers);
    on<ToggleViewModeEvent>(_onToggleViewMode);
    on<CreateCustomerEvent>(_onCreateCustomer);
    // Customer Groups handlers
    on<LoadCustomerGroupsEvent>(_onLoadCustomerGroups);
    on<LoadMoreCustomerGroupsEvent>(_onLoadMoreCustomerGroups);
    on<CreateCustomerGroupEvent>(_onCreateCustomerGroup);
    on<UpdateCustomerGroupEvent>(_onUpdateCustomerGroup);
    on<DeleteCustomerGroupEvent>(_onDeleteCustomerGroup);
    // Customer Logs handlers
    on<LoadCustomerLogsEvent>(_onLoadCustomerLogs);
    on<StartCustomerLogsStreamEvent>(_onStartCustomerLogsStream);
    on<StopCustomerLogsStreamEvent>(_onStopCustomerLogsStream);
    // Stream handlers
    on<_CustomerStreamDataReceived>(_onCustomerStreamDataReceived);
    on<_CustomerStreamErrorReceived>(_onCustomerStreamErrorReceived);
    on<_CustomerStatsStreamDataReceived>(_onCustomerStatsStreamDataReceived);
    on<_CustomerGroupsStreamDataReceived>(_onCustomerGroupsStreamDataReceived);
    on<_CustomerLogsStreamDataReceived>(_onCustomerLogsStreamDataReceived);
  }

  final GetCustomers getCustomers;
  final GetCustomersPaginated getCustomersPaginated;
  final GetCustomersStream getCustomersStream;
  final GetCustomerStatsStream getCustomerStatsStream;
  final AddCustomer addCustomer;
  final AddCustomerWithOpeningBalance addCustomerWithOpeningBalance;
  final UpdateCustomer updateCustomer;
  final DeleteCustomer deleteCustomer;
  final GetCustomerStats getCustomerStats;
  final GetCustomerLogs getCustomerLogs;
  final CustomerRepository repository;
  bool _isOperating = false;

  Future<void> _notifyCustomerCreated(CustomerEntity customer) async {
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      final actorEmail =
          switchedUser?['email']?.toString() ??
          FirebaseAuth.instance.currentUser?.email;
      if (actorEmail == null || actorEmail.isEmpty) return;

      await PushNotificationService.sendOrganizationNotification(
        organizationEmail: customer.organizationEmail,
        title: '👤 تسجيل عميل جديد',
        body: 'تمت إضافة العميل "${customer.name}" إلى سجل العملاء',
        type: 'customer_created',
        actorEmail: actorEmail,
        data: {'customerId': customer.id},
      );
    } on Exception catch (error) {
      LoggerService.warning(
        'Failed to send customer_created notification: $error',
      );
    }
  }

  // Customer Groups pagination
  DocumentSnapshot<Object?>? _lastDocumentGroups;
  bool _isLoadingMoreGroups = false;
  bool _hasMoreGroupsData = true;

  // متغيرات للتحكم في الـ streams
  StreamSubscription<dynamic>? _customersStreamSubscription;
  StreamSubscription<dynamic>? _statsStreamSubscription;
  StreamSubscription<dynamic>? _customerGroupsStreamSubscription;
  StreamSubscription<dynamic>? _customerLogsStreamSubscription;
  List<CustomerEntity> _allCustomers = []; // ✅ حفظ كل العملاء للفلترة
  String?
  _currentOrganizationEmail; // ✅ بريد المؤسسة الحالية لإعادة تشغيل الستريم عند البحث
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isGridView = false;
  CustomerStatsEntity?
  _pendingStats; // ✅ تخزين الإحصائيات الواصلة قبل بيانات العملاء

  // متغيرات للتحكم في pagination
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  Future<void> _onLoadCustomers(
    LoadCustomersEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await getCustomers(
      event.organizationEmail,
      forceRefresh: event.forceRefresh,
    );
    await result.fold((failure) async => emit(CustomerError(failure.message)), (
      customers,
    ) async {
      // تحميل الإحصائيات والمجموعات بشكل متوازٍ لتحسين وقت الاستجابة
      // ✅ ملاحظة للمبرمجين المستقبليين: Future.wait يُنفّذ العمليتين
      // معاً بدلاً من الانتظار متسلسلاً — يقلل وقت الاستجابة تقريبًا إلى النصف.
      final results =
          await Future.wait([
                getCustomerStats(event.organizationEmail),
                repository.getCustomerGroups(event.organizationEmail),
              ])
              as List<Either<Failure, dynamic>>;

      CustomerStatsEntity? stats;
      (results[0] as Either<Failure, CustomerStatsEntity>).fold(
        (failure) => stats = null,
        (loadedStats) => stats = loadedStats,
      );

      List<CustomerGroupEntity> groups = [];
      (results[1] as Either<Failure, List<CustomerGroupEntity>>).fold(
        (failure) => groups = [],
        (loadedGroups) => groups = loadedGroups,
      );

      emit(
        CustomerLoaded(
          customers: customers,
          filteredCustomers: customers,
          selectedFilter: 'all',
          searchQuery: '',
          stats: stats,
          customerGroups: groups, // ✅ المجموعات ضمن CustomerLoaded
          isGridView: false,
        ),
      );
    });
  }

  Future<void> _onLoadCustomersPaginated(
    LoadCustomersPaginatedEvent event,
    Emitter<CustomerState> emit,
  ) async {
    // إذا كان refresh، نعيد تعيين المتغيرات
    if (event.isRefresh) {
      _lastDocument = null;
      emit(CustomerLoading());
    }

    // ✅ حفظ بريد المؤسسة لإعادة تشغيل الستريم مع نص البحث عند البحث
    _currentOrganizationEmail = event.organizationEmail;

    // تحميل الإحصائيات
    final statsResult = await getCustomerStats(event.organizationEmail);
    CustomerStatsEntity? stats;
    statsResult.fold(
      (failure) => stats = null,
      (loadedStats) => stats = loadedStats,
    );

    // تحميل أول دفعة من العملاء
    final result = await getCustomersPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
      searchQuery: event.searchQuery,
    );

    await result.fold((failure) async => emit(CustomerError(failure.message)), (
      page,
    ) async {
      final customers = page.customers;

      // ✅ تحسين (2026-10-12): مؤشر الصفحة
      // الأخيرة يُعاد مع نتيجة الاستعلام
      // نفسها (snapshot.docs.last) — لا
      // جلب منفصل للمستند عبر
      // getCustomerDocument (جولة شبكة
      // زائدة بعد كل تحميل صفحة — نفس
      // تحسين قسم الفواتير).
      if (page.lastDocument != null) {
        _lastDocument = page.lastDocument;
      }

      emit(
        CustomerLoaded(
          customers: customers,
          filteredCustomers: customers,
          selectedFilter: 'all',
          searchQuery: '',
          stats: stats,
          isGridView: false,
          hasMore: customers.length >= _pageSize,
          lastDocument: _lastDocument,
        ),
      );
    });
  }

  Future<void> _onLoadMoreCustomers(
    LoadMoreCustomersEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (state is! CustomerLoaded) return;

    final currentState = state as CustomerLoaded;

    // إذا لم يكن هناك المزيد أو جاري التحميل، لا نفعل شيء
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    // تحديث الحالة لإظهار مؤشر التحميل
    emit(currentState.copyWith(isLoadingMore: true));

    // تحميل المزيد من العملاء
    final result = await getCustomersPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
      lastDocument: currentState.lastDocument,
    );

    await result.fold(
      (failure) async {
        emit(currentState.copyWith(isLoadingMore: false));
        emit(CustomerError(failure.message));
      },
      (page) async {
        final newCustomers = page.customers;

        // ✅ تحسين (2026-10-12): مؤشر
        // الصفحة الأخيرة يُعاد مع نتيجة
        // الاستعلام نفسها — لا جلب
        // منفصل للمستند عبر
        // getCustomerDocument (جولة
        // شبكة زائدة بعد كل تحميل
        // صفحة — نفس تحسين قسم
        // الفواتير).
        if (page.lastDocument != null) {
          _lastDocument = page.lastDocument;
        }

        // دمج العملاء الجدد مع القديمة
        final allCustomers = [...currentState.customers, ...newCustomers];

        emit(
          currentState.copyWith(
            customers: allCustomers,
            filteredCustomers: allCustomers,
            // ✅ ملاحظة للمبرمجين المستقبليين: تحديد hasMore بناءً على وجود lastDocument
            // وليس بناءً على newCustomers.length >= _pageSize، لأن الصفحة الأخيرة
            // قد تحتوي على عدد عناصر يساوي pageSize تمامًا دون أن تكون هناك صفحات إضافية.
            hasMore: page.lastDocument != null,
            isLoadingMore: false,
            lastDocument: _lastDocument,
          ),
        );
      },
    );
  }

  Future<void> _onAddCustomer(
    AddCustomerEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // فحص صلاحية إنشاء العميل
      final permissionChecker = PermissionChecker();
      final canCreate = await permissionChecker.hasPermission(
        'customers_create',
      );
      if (!canCreate) {
        emit(const CustomerError('ليس لديك صلاحية لإضافة عملاء'));
        return;
      }

      if (state is CustomerLoaded) {
        emit(CustomerLoading());
        final result = await addCustomer(event.customer);
        await result.fold((failure) async => emit(CustomerError(failure.message)), (
          savedCustomer,
        ) async {
          // إرسال إشعار Push إلى بقية مستخدمي المؤسسة؛ الخادم يستثني حساب المنفذ.
          unawaited(_notifyCustomerCreated(savedCustomer));

          // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

          // تسجيل العملية في السجل (بدون انتظار لتجنب مشاكل emit)
          unawaited(
            repository.addCustomerLog(
              organizationEmail: savedCustomer.organizationEmail,
              userId: 'current_user',
              actionType: 'add_customer',
              details: 'تم إضافة عميل جديد: ${savedCustomer.name}',
              targetId: savedCustomer.id,
              targetType: 'customer',
              newValues: {
                'name': savedCustomer.name,
                'email': savedCustomer.email,
                'phone': savedCustomer.phone,
                'address': savedCustomer.address,
                'status': savedCustomer.status,
                'customerGroupId': savedCustomer.customerGroupId,
                'customerGroupName': savedCustomer.customerGroupName,
                'creditLimit': savedCustomer.creditLimit,
                'openingBalance': savedCustomer.openingBalance,
                'totalPurchases': savedCustomer.totalPurchases,
                'totalDebt': savedCustomer
                    .totalDebt, // ⚠️ حقل تراكمي - يجب تحديثه ذرياً فقط
              },
            ),
          );

          // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

          // إعادة تحميل البيانات مباشرة مع إجبار التحديث من السيرفر
          final refreshResult = await getCustomers(
            event.customer.organizationEmail,
            forceRefresh: true,
          );
          await refreshResult.fold(
            (failure) async => emit(CustomerError(failure.message)),
            (customers) async {
              final statsResult = await getCustomerStats(
                event.customer.organizationEmail,
              );
              CustomerStatsEntity? stats;
              statsResult.fold(
                (failure) => stats = null,
                (loadedStats) => stats = loadedStats,
              );

              emit(
                CustomerLoaded(
                  customers: customers,
                  filteredCustomers: customers,
                  selectedFilter: 'all',
                  searchQuery: '',
                  stats: stats,
                  isGridView: false,
                ),
              );
            },
          );
        });
      }
    } finally {
      _isOperating = false;
    }
  }

  Future<void> _onUpdateCustomer(
    UpdateCustomerEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // فحص صلاحية تعديل العميل
      final permissionChecker = PermissionChecker();
      final canEdit = await permissionChecker.hasPermission('customers_edit');
      if (!canEdit) {
        emit(const CustomerError('ليس لديك صلاحية لتعديل العملاء'));
        return;
      }

      // التحقق من الحالة الحالية وتحديد نوعها بشكل دقيق
      if (state is CustomerLoaded ||
          state is CustomerStreamActive ||
          state is CustomerGroupsLoaded) {
        emit(CustomerLoading());

        // الحصول على البيانات الحالية بناءً على نوع الحالة
        List<CustomerEntity> currentCustomers = [];
        String selectedFilter = 'all';
        String searchQuery = '';
        bool isGridView = false;
        CustomerStatsEntity? stats;
        List<CustomerGroupEntity> groups = [];

        if (state is CustomerLoaded) {
          final currentState = state as CustomerLoaded;
          currentCustomers = currentState.customers;
          selectedFilter = currentState.selectedFilter;
          searchQuery = currentState.searchQuery;
          isGridView = currentState.isGridView;
          stats = currentState.stats;
          groups = currentState.customerGroups;
        } else if (state is CustomerStreamActive) {
          final currentState = state as CustomerStreamActive;
          currentCustomers = currentState.customers;
          selectedFilter = currentState.selectedFilter;
          searchQuery = currentState.searchQuery;
          isGridView = currentState.isGridView;
          stats = currentState.stats;
        } else if (state is CustomerGroupsLoaded) {
          final currentState = state as CustomerGroupsLoaded;
          currentCustomers = currentState.customers;
          selectedFilter = currentState.selectedFilter;
          searchQuery = currentState.searchQuery;
          isGridView = currentState.isGridView;
          stats = currentState.stats;
          groups = currentState.groups;
        }

        CustomerEntity existingCustomer;
        try {
          existingCustomer = currentCustomers.firstWhere(
            (c) => c.id == event.customer.id,
          );
        } on StateError {
          emit(const CustomerError('العميل غير موجود في القائمة الحالية'));
          return;
        }

        // التحقق من صحة انتقال الحالة
        if (!existingCustomer.canTransitionToStatus(event.customer.status)) {
          emit(const CustomerError('لا يمكن الانتقال إلى الحالة المحددة'));
          return;
        }

        // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

        // إنشاء مكون التحقق من صحة البيانات
        final validator = CustomerValidator(repository);

        // التحقق من صحة البيانات المحدثة
        if (!validator.isValidName(event.customer.name)) {
          emit(const CustomerError('الاسم غير صحيح'));
          return;
        }

        if (!validator.isValidEmail(event.customer.email)) {
          emit(const CustomerError('البريد الإلكتروني غير صحيح'));
          return;
        }

        if (!validator.isValidPhone(event.customer.phone)) {
          emit(const CustomerError('رقم الهاتف غير صحيح'));
          return;
        }

        if (!validator.isValidAmount(event.customer.creditLimit)) {
          emit(const CustomerError('الحد الائتماني غير صحيح'));
          return;
        }

        if (!validator.isValidBalance(event.customer.totalDebt)) {
          emit(const CustomerError('إجمالي الدين غير صحيح'));
          return;
        }

        // ⚠️ totalDebt حقل تراكمي (موجب/سالب/صفر كلها صالحة) — قاعدته في
        // الملاحظة العامة أعلى هذا الملف.

        // ✅ السماح بتعديل العميل حتى لو تجاوز الدين حد الدين
        // حد الدين للتعاملات المستقبلية فقط وليس للديون الحالية

        if (!validator.isValidStatus(event.customer.status)) {
          emit(const CustomerError('الحالة غير صحيحة'));
          return;
        }

        if (!validator.isValidCustomerGroup(event.customer.customerGroupId)) {
          emit(const CustomerError('مجموعة العميل غير صحيحة'));
          return;
        }

        // التحقق من أن مجموعة العميل موجودة ونشطة (إذا تم تحديد مجموعة)
        if (event.customer.customerGroupId != null &&
            event.customer.customerGroupId!.isNotEmpty) {
          final isGroupValid = await repository.isCustomerGroupValid(
            event.customer.customerGroupId!,
            event.customer.organizationEmail,
          );

          if (isGroupValid.isLeft() || !isGroupValid.getOrElse(() => false)) {
            emit(const CustomerError('مجموعة العميل غير موجودة أو غير نشطة'));
            return;
          }
        }

        // التحقق من تكرار البريد الإلكتروني (باستثناء العميل الحالي)
        final emailUniqueResult = await validator.isEmailUnique(
          event.customer.email,
          event.customer.organizationEmail,
          excludeCustomerId: event.customer.id,
        );

        if (emailUniqueResult.isRight()) {
          final isUnique = emailUniqueResult.getOrElse(() => false);
          if (!isUnique) {
            emit(const CustomerError('البريد الإلكتروني مستخدم من قبل'));
            return;
          }
        } else {
          // في حالة فشل التحقق، نعيد الخطأ
          final failure = emailUniqueResult.fold((f) => f, (r) => null);
          emit(
            CustomerError(
              'فشل التحقق من البريد الإلكتروني: ${failure?.message ?? 'غير معروف'}',
            ),
          );
          return;
        }

        // التحقق من تكرار رقم الهاتف (باستثناء العميل الحالي)
        final phoneUniqueResult = await validator.isPhoneUnique(
          event.customer.phone,
          event.customer.organizationEmail,
          excludeCustomerId: event.customer.id,
        );

        if (phoneUniqueResult.isRight()) {
          final isUnique = phoneUniqueResult.getOrElse(() => false);
          if (!isUnique) {
            emit(const CustomerError('رقم الهاتف مستخدم من قبل'));
            return;
          }
        } else {
          // في حالة فشل التحقق، نعيد الخطأ
          final failure = phoneUniqueResult.fold((f) => f, (r) => null);
          emit(
            CustomerError(
              'فشل التحقق من رقم الهاتف: ${failure?.message ?? 'غير معروف'}',
            ),
          );
          return;
        }

        final result = await updateCustomer(event.customer);
        await result.fold(
          (failure) async {
            emit(CustomerError(failure.message));
          },
          (_) async {
            // إرسال إشعار محلي حسب حالة الحساب
            final customerUpdater =
                event.customer.updatedBy ?? event.customer.createdBy;
            if (event.customer.totalDebt <= 0 &&
                existingCustomer.totalDebt > 0) {
              unawaited(
                SectionNotificationService.notifyCustomerZeroBalance(
                  event.customer,
                  createdBy: customerUpdater,
                ),
              );
            } else if (event.customer.creditLimit != null &&
                event.customer.creditLimit! > 0 &&
                event.customer.totalDebt > event.customer.creditLimit!) {
              unawaited(
                SectionNotificationService.notifyCreditLimitExceeded(
                  event.customer,
                  createdBy: customerUpdater,
                ),
              );
            } else {
              unawaited(
                SectionNotificationService.notifyCustomerUpdated(
                  event.customer,
                  createdBy: customerUpdater,
                ),
              );
            }

            // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

            // إرسال إشعار تنظيمي بتحديث بيانات العميل
            final updateCustomerActorEmail =
                event.customer.updatedBy ?? event.customer.createdBy;
            final customerWasCleared =
                event.customer.totalDebt <= 0 && existingCustomer.totalDebt > 0;
            if (updateCustomerActorEmail != null &&
                updateCustomerActorEmail.isNotEmpty &&
                !customerWasCleared) {
              unawaited(() async {
                try {
                  final isSectionEnabled =
                      await SectionNotificationService.isSectionNotificationsEnabled(
                        'customers',
                      );
                  if (!isSectionEnabled) return;
                  final isTypeEnabled =
                      await SettingsService.isNotificationTypeEnabled(
                        'customer_notify_updated',
                      );
                  if (!isTypeEnabled) return;
                  await PushNotificationService.sendOrganizationNotification(
                    organizationEmail: event.customer.organizationEmail,
                    title: '✏️ تعديل بيانات عميل (${event.customer.name})',
                    body:
                        'تم تحديث بيانات العميل "${event.customer.name}" - رقم الهاتف: ${event.customer.phone}',
                    type: 'customer_updated',
                    actorEmail: updateCustomerActorEmail,
                    data: {'customerId': event.customer.id},
                  );
                } on Exception catch (_) {
                  // فشل الإشعار لا يمنع تحديث بيانات العميل.
                }
              }());
            }

            // تسجيل العملية في السجل (بدون انتظار لتجنب مشاكل emit)
            unawaited(
              repository.addCustomerLog(
                organizationEmail: event.customer.organizationEmail,
                userId: 'current_user',
                actionType: 'update_customer',
                details: 'تم تحديث بيانات العميل: ${event.customer.name}',
                targetId: event.customer.id,
                targetType: 'customer',
                newValues: {
                  'name': event.customer.name,
                  'email': event.customer.email,
                  'phone': event.customer.phone,
                  'address': event.customer.address,
                  'status': event.customer.status,
                  'customerGroupId': event.customer.customerGroupId,
                  'customerGroupName': event.customer.customerGroupName,
                  'creditLimit': event.customer.creditLimit,
                  'openingBalance': event.customer.openingBalance,
                  'totalPurchases': event.customer.totalPurchases,
                  'totalDebt': event
                      .customer
                      .totalDebt, // ⚠️ حقل تراكمي - يجب تحديثه ذرياً فقط
                },
              ),
            );

            // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

            emit(
              const CustomerOperationSuccess('تم تحديث بيانات العميل بنجاح'),
            );

            // إعادة تحميل البيانات مباشرة مع إجبار التحديث من السيرفر
            final refreshResult = await getCustomers(
              event.customer.organizationEmail,
              forceRefresh: true,
            );
            await refreshResult.fold(
              (failure) async => emit(CustomerError(failure.message)),
              (customers) async {
                final statsResult = await getCustomerStats(
                  event.customer.organizationEmail,
                );
                CustomerStatsEntity? stats;
                statsResult.fold(
                  (failure) => stats = null,
                  (loadedStats) => stats = loadedStats,
                );

                // إصدار الحالة المناسبة بناءً على نوع الحالة الأصلية
                if (state is CustomerStreamActive) {
                  emit(
                    CustomerStreamActive(
                      customers: customers,
                      filteredCustomers: customers,
                      selectedFilter: selectedFilter,
                      searchQuery: searchQuery,
                      stats: stats,
                      isGridView: isGridView,
                    ),
                  );
                } else if (state is CustomerGroupsLoaded) {
                  emit(
                    CustomerGroupsLoaded(
                      groups: groups,
                      customers: customers,
                      filteredCustomers: customers,
                      selectedFilter: selectedFilter,
                      searchQuery: searchQuery,
                      isGridView: isGridView,
                      stats: stats,
                    ),
                  );
                } else {
                  emit(
                    CustomerLoaded(
                      customers: customers,
                      filteredCustomers: customers,
                      selectedFilter: selectedFilter,
                      searchQuery: searchQuery,
                      stats: stats,
                      isGridView: isGridView,
                      customerGroups: groups,
                    ),
                  );
                }
              },
            );
          },
        );
      } else {
        emit(const CustomerError('حالة غير صحيحة لتحديث العميل'));
      }
    } finally {
      _isOperating = false;
    }
  }

  Future<void> _onDeleteCustomer(
    DeleteCustomerEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // التحقق من الصلاحية
      final permissionChecker = PermissionChecker();
      final hasPermission = await permissionChecker.hasPermission(
        'customers_delete',
      );

      if (!hasPermission) {
        emit(const CustomerError('ليس لديك صلاحية لحذف العملاء'));
        return;
      }

      if (state is CustomerLoaded) {
        emit(CustomerLoading());
        final result = await deleteCustomer(event.id, event.organizationEmail);
        await result.fold(
          (failure) async => emit(CustomerError(failure.message)),
          (_) async {
            // تسجيل العملية في السجل (بدون انتظار لتجنب مشاكل emit)
            unawaited(
              repository.addCustomerLog(
                organizationEmail: event.organizationEmail,
                userId: 'current_user',
                actionType: 'delete_customer',
                details: 'تم حذف العميل',
                targetId: event.id,
                targetType: 'customer',
              ),
            );

            // ⚠️ عند حذف عميل: فواتيره لا تُحذف بل يتحول customerId فيها
            // إلى 'deleted_customer' — لا دخل لتحديث totalDebt يدوياً هنا.

            // إرسال إشعار تنظيمي بحذف العميل
            final deleteCustomerActorEmail =
                FirebaseAuth.instance.currentUser?.email ?? '';
            if (deleteCustomerActorEmail.isNotEmpty) {
              unawaited(() async {
                try {
                  final isSectionEnabled =
                      await SectionNotificationService.isSectionNotificationsEnabled(
                        'customers',
                      );
                  if (!isSectionEnabled) return;
                  final isTypeEnabled =
                      await SettingsService.isNotificationTypeEnabled(
                        'customer_notify_deleted',
                      );
                  if (!isTypeEnabled) return;
                  await PushNotificationService.sendOrganizationNotification(
                    organizationEmail: event.organizationEmail,
                    title: '🗑️ حذف عميل',
                    body: 'تم حذف عميل من سجل العملاء',
                    type: 'customer_deleted',
                    actorEmail: deleteCustomerActorEmail,
                    data: {'customerId': event.id},
                  );
                } on Exception catch (_) {
                  // فشل الإشعار لا يمنع حذف العميل.
                }
              }());
            }

            emit(const CustomerOperationSuccess('تم حذف العميل بنجاح'));

            // إعادة تحميل البيانات مباشرة مع إجبار التحديث من السيرفر
            final refreshResult = await getCustomers(
              event.organizationEmail,
              forceRefresh: true,
            );
            await refreshResult.fold(
              (failure) async => emit(CustomerError(failure.message)),
              (customers) async {
                final statsResult = await getCustomerStats(
                  event.organizationEmail,
                );
                CustomerStatsEntity? stats;
                statsResult.fold(
                  (failure) => stats = null,
                  (loadedStats) => stats = loadedStats,
                );

                emit(
                  CustomerLoaded(
                    customers: customers,
                    filteredCustomers: customers,
                    selectedFilter: 'all',
                    searchQuery: '',
                    stats: stats,
                    isGridView: false,
                  ),
                );
              },
            );
          },
        );
      }
    } finally {
      _isOperating = false;
    }
  }

  Future<void> _onLoadCustomerStats(
    LoadCustomerStatsEvent event,
    Emitter<CustomerState> emit,
  ) async {
    final result = await getCustomerStats(event.organizationEmail);

    if (state is CustomerLoaded) {
      final currentState = state as CustomerLoaded;
      result.fold(
        // ⚠️ عند فشل تحميل الإحصائيات، لا نمسح القيمة الحالية.
        // إنشاء currentState.copyWith() بدون معاملات ستُنشئ نسخة
        // جديدة مع مسح الإحصائيات، لذا نتجاهل الفشل ونحتفظ بالقيمة السابقة.
        (failure) => null,
        (stats) => emit(currentState.copyWith(stats: stats)),
      );
    } else if (state is CustomerStreamActive) {
      final currentState = state as CustomerStreamActive;
      result.fold(
        // ⚠️ نفس المنطق أعلاه — الاحتف بالقيمة السابقة عند الفشل.
        (failure) => null,
        (stats) => emit(currentState.copyWith(stats: stats)),
      );
    }
    // في الحالات الأخرى (Initial, Loading) نتجاهل الحدث
    // لأن الإحصائيات ستُحمّل تلقائياً مع LoadCustomersEvent
  }

  void _onFilterCustomers(
    FilterCustomersEvent event,
    Emitter<CustomerState> emit,
  ) {
    _selectedFilter = event.filter;

    if (state is CustomerLoaded) {
      final currentState = state as CustomerLoaded;
      final filtered = _applyFilters(_allCustomers);

      emit(
        currentState.copyWith(
          filteredCustomers: filtered,
          selectedFilter: event.filter,
        ),
      );
    } else if (state is CustomerStreamActive) {
      final currentState = state as CustomerStreamActive;
      final filtered = _applyFilters(_allCustomers);

      emit(
        currentState.copyWith(
          filteredCustomers: filtered,
          selectedFilter: event.filter,
        ),
      );
    }
  }

  void _onSearchCustomers(
    SearchCustomersEvent event,
    Emitter<CustomerState> emit,
  ) {
    _searchQuery = event.query;

    // إعادة تشغيل الستريم مع نص البحث للبحث في جميع العملاء
    // وليس فقط العملاء المحملين حالياً (أول 20 عميل)
    final orgEmail = _currentOrganizationEmail;
    if (orgEmail != null && orgEmail.isNotEmpty) {
      add(
        StartCustomersStreamEvent(
          orgEmail,
          limit: event.query.isEmpty ? _pageSize : null,
          searchQuery: event.query.isEmpty ? null : event.query,
        ),
      );
    }

    if (state is CustomerLoaded) {
      final currentState = state as CustomerLoaded;
      final filtered = _applyFilters(_allCustomers);

      emit(
        currentState.copyWith(
          filteredCustomers: filtered,
          searchQuery: event.query,
        ),
      );
    } else if (state is CustomerStreamActive) {
      final currentState = state as CustomerStreamActive;
      final filtered = _applyFilters(_allCustomers);

      emit(
        currentState.copyWith(
          filteredCustomers: filtered,
          searchQuery: event.query,
        ),
      );
    }
  }

  void _onToggleViewMode(
    ToggleViewModeEvent event,
    Emitter<CustomerState> emit,
  ) {
    _isGridView = !_isGridView;

    if (state is CustomerLoaded) {
      final currentState = state as CustomerLoaded;
      emit(currentState.copyWith(isGridView: _isGridView));
    } else if (state is CustomerStreamActive) {
      final currentState = state as CustomerStreamActive;
      emit(currentState.copyWith(isGridView: _isGridView));
    }
  }

  Future<void> _onCreateCustomer(
    CreateCustomerEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      emit(CustomerLoading());

      // إنشاء مكون التحقق من صحة البيانات
      final validator = CustomerValidator(repository);

      // التحقق من صحة البيانات المدخلة
      if (!validator.isValidName(event.name)) {
        emit(const CustomerError('الاسم غير صحيح'));
        return;
      }

      if (!validator.isValidEmail(event.email)) {
        emit(const CustomerError('البريد الإلكتروني غير صحيح'));
        return;
      }

      if (!validator.isValidPhone(event.phone)) {
        emit(const CustomerError('رقم الهاتف غير صحيح'));
        return;
      }

      if (!validator.isValidAmount(event.creditLimit)) {
        emit(const CustomerError('الحد الائتماني غير صحيح'));
        return;
      }

      if (!validator.isValidBalance(event.openingBalance)) {
        emit(const CustomerError('الحساب الافتتاحي غير صحيح'));
        return;
      }

      // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

      // ✅ السماح بإنشاء العميل حتى لو تجاوز الحساب الافتتاحي حد الدين
      // الحساب الافتتاحي لا يتأثر بحد الدين، حد الدين للتعاملات المستقبلية فقط
      final openingBalanceValue = event.openingBalance ?? 0.0;

      if (!validator.isValidCustomerGroup(event.customerGroupId)) {
        emit(const CustomerError('مجموعة العميل غير صحيحة'));
        return;
      }

      // التحقق من تكرار البريد الإلكتروني
      final emailUniqueResult = await validator.isEmailUnique(
        event.email,
        event.organizationEmail,
      );

      if (emailUniqueResult.isRight()) {
        final isUnique = emailUniqueResult.getOrElse(() => false);
        if (!isUnique) {
          emit(const CustomerError('البريد الإلكتروني مستخدم من قبل'));
          return;
        }
      } else {
        // في حالة فشل التحقق، نعيد الخطأ
        final failure = emailUniqueResult.fold((f) => f, (r) => null);
        emit(
          CustomerError(
            'فشل التحقق من البريد الإلكتروني: ${failure?.message ?? 'غير معروف'}',
          ),
        );
        return;
      }

      // التحقق من تكرار رقم الهاتف
      final phoneUniqueResult = await validator.isPhoneUnique(
        event.phone,
        event.organizationEmail,
      );

      if (phoneUniqueResult.isRight()) {
        final isUnique = phoneUniqueResult.getOrElse(() => false);
        if (!isUnique) {
          emit(const CustomerError('رقم الهاتف مستخدم من قبل'));
          return;
        }
      } else {
        // في حالة فشل التحقق، نعيد الخطأ
        final failure = phoneUniqueResult.fold((f) => f, (r) => null);
        emit(
          CustomerError(
            'فشل التحقق من رقم الهاتف: ${failure?.message ?? 'غير معروف'}',
          ),
        );
        return;
      }

      // حساب إجمالي الدين بناءً على الحساب الافتتاحي
      // الحساب الافتتاحي الموجب يعني أن العميل عليه مبلغ (دين موجب)
      // الحساب الافتتاحي السالب يعني أن العميل له مبلغ (دين سالب)
      final totalDebt = openingBalanceValue;

      // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

      final customer = CustomerEntity(
        id: '', // سيتم إنشاء معرف قصير في repository
        organizationEmail: event.organizationEmail,
        name: event.name,
        email: event.email,
        phone: event.phone,
        address: event.address,
        customerGroupId: event.customerGroupId,
        customerGroupName: event.customerGroupName,
        creditLimit: event.creditLimit,
        openingBalance: openingBalanceValue, // الحساب الافتتاحي الفعلي
        totalPurchases: 0,
        totalDebt: totalDebt,
        status: 'active',
        notes: event.notes,
        createdBy: event.createdBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        invoiceIds: const [],
        logIds: const [],
      );

      final result = await addCustomerWithOpeningBalance(
        customer: customer,
        openingBalance: openingBalanceValue,
        createdBy: event.createdBy ?? 'النظام',
      );
      await result.fold((failure) async => emit(CustomerError(failure.message)), (
        savedCustomer,
      ) async {
        // تسجيل العملية في السجل (بدون انتظار لتجنب مشاكل emit)
        unawaited(
          repository.addCustomerLog(
            organizationEmail: event.organizationEmail,
            userId: 'current_user',
            actionType: 'create_customer',
            details: 'تم إنشاء عميل جديد: ${event.name}',
            targetId: savedCustomer.id,
            targetType: 'customer',
            newValues: {
              'name': event.name,
              'email': event.email,
              'phone': event.phone,
              'address': event.address,
              'creditLimit': event.creditLimit,
              'openingBalance': event.openingBalance,
              'status': 'active',
              'customerGroupId': event.customerGroupId,
              'customerGroupName': event.customerGroupName,
              'notes': event.notes,
              'createdBy': event.createdBy,
              'totalDebt':
                  openingBalanceValue, // ⚠️ حقل تراكمي - يجب تحديثه ذرياً فقط
            },
          ),
        );

        // ⚠️ totalDebt حقل تراكمي — قاعدته في الملاحظة العامة أعلى هذا الملف.

        // إرسال إشعار Push إلى بقية مستخدمي المؤسسة؛ الخادم يستثني حساب المنفذ.
        unawaited(_notifyCustomerCreated(savedCustomer));

        emit(const CustomerOperationSuccess('تم إنشاء العميل بنجاح'));
        emit(const CustomerCreated());
      });
    } finally {
      _isOperating = false;
    }
  }

  // ===== Customer Groups Handlers =====

  Future<void> _onLoadCustomerGroups(
    LoadCustomerGroupsEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await repository.getCustomerGroups(event.organizationEmail);
    result.fold(
      (failure) => emit(CustomerError(failure.message)),
      (groups) => emit(CustomerGroupsLoaded(groups: groups)),
    );
  }

  Future<void> _onLoadMoreCustomerGroups(
    LoadMoreCustomerGroupsEvent event,
    Emitter<CustomerState> emit,
  ) async {
    if (_isLoadingMoreGroups || !_hasMoreGroupsData) return;

    _isLoadingMoreGroups = true;

    try {
      final result = await repository.getCustomerGroupsPaginated(
        organizationEmail: event.organizationEmail,
        limit: 20,
        lastDocument: _lastDocumentGroups,
      );

      result.fold((failure) => emit(CustomerError(failure.message)), (page) {
        if (page.groups.isNotEmpty) {
          _lastDocumentGroups = page.lastDocument;
          final currentGroups = <CustomerGroupEntity>[];
          final currentState = state;
          if (currentState is CustomerGroupsLoaded) {
            currentGroups.addAll(currentState.groups);
          }
          currentGroups.addAll(page.groups);
          _hasMoreGroupsData = page.groups.length >= 20;

          emit(
            CustomerGroupsLoaded(
              groups: currentGroups,
              hasMoreGroupsData: _hasMoreGroupsData,
              isLoadingMoreGroups: false,
              lastDocumentGroups: _lastDocumentGroups,
            ),
          );
        } else {
          _hasMoreGroupsData = false;
          final currentState = state;
          if (currentState is CustomerGroupsLoaded) {
            emit(
              currentState.copyWith(
                hasMoreGroupsData: false,
                isLoadingMoreGroups: false,
              ),
            );
          }
        }
        _isLoadingMoreGroups = false;
      });
    } on Exception catch (_) {
      _isLoadingMoreGroups = false;
      final currentState = state;
      if (currentState is CustomerGroupsLoaded) {
        emit(currentState.copyWith(isLoadingMoreGroups: false));
      }
      emit(CustomerError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onCreateCustomerGroup(
    CreateCustomerGroupEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await repository.createCustomerGroup(event.group);
    result.fold((failure) => emit(CustomerError(failure.message)), (_) async {
      // الحصول على organizationEmail من المستخدم الحالي
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationEmail = currentUser?.email;

      if (organizationEmail != null) {
        // تسجيل العملية في السجل (بدون انتظار لتجنب مشاكل emit)
        unawaited(
          repository.addCustomerLog(
            organizationEmail: organizationEmail,
            userId: 'current_user',
            actionType: 'create_customer_group',
            details: 'تم إنشاء مجموعة عملاء جديدة: ${event.group.name}',
            targetId: event.group.id,
            targetType: 'customer_group',
            newValues: {
              'name': event.group.name,
              'description': event.group.description,
              'color': event.group.color,
              'features': event.group.features,
              'isActive': event.group.isActive,
            },
          ),
        );
      }

      emit(
        const CustomerGroupOperationSuccess('تم إنشاء مجموعة العملاء بنجاح'),
      );
    });
  }

  Future<void> _onUpdateCustomerGroup(
    UpdateCustomerGroupEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await repository.updateCustomerGroup(event.group);
    result.fold((failure) => emit(CustomerError(failure.message)), (_) async {
      // الحصول على organizationEmail من المستخدم الحالي
      final currentUser = FirebaseAuth.instance.currentUser;
      final organizationEmail = currentUser?.email;

      if (organizationEmail != null) {
        // تسجيل العملية في السجل (بدون انتظار لتجنب مشاكل emit)
        unawaited(
          repository.addCustomerLog(
            organizationEmail: organizationEmail,
            userId: 'current_user',
            actionType: 'update_customer_group',
            details: 'تم تحديث مجموعة عملاء: ${event.group.name}',
            targetId: event.group.id,
            targetType: 'customer_group',
            newValues: {
              'name': event.group.name,
              'description': event.group.description,
              'color': event.group.color,
              'features': event.group.features,
              'isActive': event.group.isActive,
            },
          ),
        );
      }

      emit(
        const CustomerGroupOperationSuccess('تم تحديث مجموعة العملاء بنجاح'),
      );
    });
  }

  Future<void> _onDeleteCustomerGroup(
    DeleteCustomerGroupEvent event,
    Emitter<CustomerState> emit,
  ) async {
    // التحقق من الصلاحية
    final permissionChecker = PermissionChecker();
    final hasPermission = await permissionChecker.hasPermission(
      'customers_delete',
    );

    if (!hasPermission) {
      emit(const CustomerError('ليس لديك صلاحية لحذف مجموعات العملاء'));
      return;
    }

    emit(CustomerLoading());
    final result = await repository.deleteCustomerGroup(
      event.groupId,
      event.organizationEmail,
    );
    result.fold((failure) => emit(CustomerError(failure.message)), (_) async {
      // تسجيل العملية في السجل (بدون انتظار لتجنب مشاكل emit)
      unawaited(
        repository.addCustomerLog(
          organizationEmail: event.organizationEmail,
          userId: 'current_user',
          actionType: 'delete_customer_group',
          details: 'تم حذف مجموعة عملاء',
          targetId: event.groupId,
          targetType: 'customer_group',
        ),
      );

      emit(const CustomerGroupOperationSuccess('تم حذف مجموعة العملاء بنجاح'));
    });
  }

  // ===== Customer Logs Handlers =====

  Future<void> _onLoadCustomerLogs(
    LoadCustomerLogsEvent event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());

    final params = GetCustomerLogsParams(
      organizationEmail: event.organizationEmail,
      userId: event.userId,
      searchQuery: event.searchQuery,
      actionFilter: event.actionFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: event.limit ?? 50,
    );

    final result = await getCustomerLogs(params);

    result.fold(
      (failure) => emit(CustomerError(failure.message)),
      (logs) => emit(CustomerLogsLoaded(logs)),
    );
  }

  /// بدء الاستماع لسجل نشاطات العملاء مع التحديث الفوري
  Future<void> _onStartCustomerLogsStream(
    StartCustomerLogsStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد لتجنب تسرب الذاكرة
    await _customerLogsStreamSubscription?.cancel();
    _customerLogsStreamSubscription = null;

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is CustomerLogsLoaded ||
        state is CustomerStreamActive ||
        state is CustomerLoaded;
    if (!hasExistingData) {
      emit(CustomerLoading());
    }

    try {
      final stream = repository.getCustomerLogsStream(
        organizationEmail: event.organizationEmail,
        userId: event.userId,
        searchQuery: event.searchQuery,
        actionFilter: event.actionFilter,
        dateFilter: event.dateFilter,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit ?? 50,
      );

      _customerLogsStreamSubscription = stream.listen(
        (result) {
          add(_CustomerLogsStreamDataReceived(result));
        },
        onError: (error) {
          add(
            _CustomerLogsStreamDataReceived(
              Left(ServerFailure(message: 'حدث خطأ في سجل نشاطات العملاء')),
            ),
          );
        },
        onDone: () {
          _customerLogsStreamSubscription = null;
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(CustomerError('حدث خطأ غير متوقع'));
    }
  }

  /// إيقاف الاستماع لسجل نشاطات العملاء
  Future<void> _onStopCustomerLogsStream(
    StopCustomerLogsStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    await _customerLogsStreamSubscription?.cancel();
    _customerLogsStreamSubscription = null;
  }

  /// بدء الاستماع للعملاء مع التحديث الفوري
  Future<void> _onStartCustomersStream(
    StartCustomersStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد لتجنب تسرب الذاكرة
    if (_customersStreamSubscription != null) {
      await _customersStreamSubscription!.cancel();
      _customersStreamSubscription = null;
    }

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is CustomerStreamActive || state is CustomerLoaded;
    if (!hasExistingData) {
      emit(CustomerLoading());
    }

    try {
      _currentOrganizationEmail = event.organizationEmail;
      final params = GetCustomersStreamParams(
        organizationEmail: event.organizationEmail,
        limit: event.limit,
        searchQuery: event.searchQuery,
      );
      final stream = getCustomersStream(params);

      _customersStreamSubscription = stream.listen(
        (result) {
          add(_CustomerStreamDataReceived(result));
        },
        onError: (error) {
          add(_CustomerStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {
          // عند انتهاء stream، نلغي الاشتراك
          _customersStreamSubscription = null;
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(CustomerError('حدث خطأ غير متوقع'));
    }
  }

  /// إيقاف الاستماع للعملاء
  Future<void> _onStopCustomersStream(
    StopCustomersStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    await _customersStreamSubscription?.cancel();
    _customersStreamSubscription = null;
  }

  /// بدء الاستماع لإحصائيات العملاء مع التحديث الفوري
  Future<void> _onStartCustomerStatsStream(
    StartCustomerStatsStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد لتجنب تسرب الذاكرة
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;

    try {
      final stream = getCustomerStatsStream(event.organizationEmail);

      _statsStreamSubscription = stream.listen(
        (result) {
          add(_CustomerStatsStreamDataReceived(result));
        },
        onError: (error) {
          add(_CustomerStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {},
      );
    } on Exception catch (_) {
      // تجاهل الأخطاء في إنشاء stream الإحصائيات
    }
  }

  /// إيقاف الاستماع لإحصائيات العملاء
  Future<void> _onStopCustomerStatsStream(
    StopCustomerStatsStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
  }

  Future<void> _onStartCustomerGroupsStream(
    StartCustomerGroupsStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    await _customerGroupsStreamSubscription?.cancel();

    try {
      final stream = repository.getCustomerGroupsStream();

      _customerGroupsStreamSubscription = stream.listen(
        (result) {
          if (!isClosed) {
            result.fold(
              (failure) {
                if (!isClosed) {
                  add(_CustomerStreamErrorReceived(failure.message));
                }
              },
              (groups) {
                if (!isClosed) {
                  add(_CustomerGroupsStreamDataReceived(groups));
                }
              },
            );
          }
        },
        onError: (error) {
          if (!isClosed) {
            add(_CustomerStreamErrorReceived('حدث خطأ غير متوقع'));
          }
        },
        onDone: () {},
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(CustomerError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onStopCustomerGroupsStream(
    StopCustomerGroupsStreamEvent event,
    Emitter<CustomerState> emit,
  ) async {
    await _customerGroupsStreamSubscription?.cancel();
    _customerGroupsStreamSubscription = null;
  }

  /// تطبيق الفلاتر والبحث على العملاء
  List<CustomerEntity> _applyFilters(List<CustomerEntity> customers) {
    var filtered = customers;

    // تطبيق فلتر الحالة
    if (_selectedFilter != 'all') {
      filtered = filtered.where((customer) {
        switch (_selectedFilter) {
          case 'active':
            return customer.isActive;
          case 'inactive':
            return customer.isInactive;
          case 'blocked':
            return customer.isBlocked;
          case 'debt':
            return customer.hasDebt;
          case 'credit':
            return customer.hasCredit;
          case 'balanced':
            return customer.isBalanced;
          case 'with_group':
            return customer.hasGroup;
          case 'without_group':
            return !customer.hasGroup;
          case 'individual':
            // ⚠️ ملاحظة للمبرمجين المستقبليين: الكيان الحالي لا يحتوي على حقل نوع العميل (individual/company).
            // هذا الفلتر مخصص للتوسعات المستقبلية عند إضافة حقل customerType إلى CustomerEntity.
            return false;
          case 'company':
            // ⚠️ ملاحظة للمبرمجين المستقبليين: الكيان الحالي لا يحتوي على حقل نوع العميل (individual/company).
            // هذا الفلتر مخصص للتوسعات المستقبلية عند إضافة حقل customerType إلى CustomerEntity.
            return false;
          default:
            return true;
        }
      }).toList();
    }

    // تطبيق البحث النصي
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((customer) {
        final query = _searchQuery.toLowerCase();
        return customer.name.toLowerCase().contains(query) ||
            customer.email.toLowerCase().contains(query) ||
            customer.phone.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// معالج استلام البيانات من stream العملاء
  void _onCustomerStreamDataReceived(
    _CustomerStreamDataReceived event,
    Emitter<CustomerState> emit,
  ) {
    event.result.fold(
      (failure) {
        emit(CustomerError(failure.message));
      },
      (customers) {
        // ✅ حفظ كل العملاء للفلترة الكاملة
        _allCustomers = customers;

        final filteredCustomers = _applyFilters(_allCustomers);

        // التحقق من الحالة الحالية لتحديد نوع الحالة التي يجب إصدارها
        if (state is CustomerLoaded) {
          final currentState = state as CustomerLoaded;

          // ✅ التحقق من تغير البيانات قبل emit
          final customersChanged = !listEquals(
            customers,
            currentState.customers,
          );
          // ✅ ملاحظة للمبرمجين المستقبليين: يُقارن filteredCustomers بالمفلتر الحالي
          // وليس بنسخة محدودة — لأن المقارنة بين قوائم مختلفة
          // تؤدي إلى اكتشاف تغييرات خاطئة في الفلاتر.
          final filteredChanged = !listEquals(
            currentState.filteredCustomers,
            filteredCustomers,
          );

          if (customersChanged || filteredChanged) {
            emit(
              CustomerLoaded(
                customers: customers,
                filteredCustomers: filteredCustomers,
                selectedFilter: _selectedFilter,
                searchQuery: _searchQuery,
                stats: currentState.stats,
                isGridView: currentState.isGridView,
              ),
            );
          }
        } else if (state is CustomerStreamActive) {
          final currentState = state as CustomerStreamActive;

          // ✅ التحقق من تغير البيانات قبل emit
          final customersChanged = !listEquals(
            customers,
            currentState.customers,
          );
          final filteredChanged = !listEquals(
            currentState.filteredCustomers,
            filteredCustomers,
          );

          if (customersChanged || filteredChanged) {
            emit(
              CustomerStreamActive(
                customers: _allCustomers,
                filteredCustomers: filteredCustomers,
                selectedFilter: _selectedFilter,
                searchQuery: _searchQuery,
                isGridView: _isGridView,
                stats: currentState.stats,
              ),
            );
          }
        } else {
          // ===== ملاحظة للمبرمجين المستقبليين =====
          // لماذا نستخدم _pendingStats هنا؟
          // لأنه في الصفحة الرئيسية للعملاء، يبدأ stream الإحصائيات
          // وstream العملاء في نفس الوقت. من المحتمل أن يصل
          // stream الإحصائيات قبل stream العملاء.
          // إذا لم نستخدم _pendingStats، سنفقد الإحصائيات الواصلة
          // أثناء حالة CustomerLoading، وسيتم عرض أصفار في النظرة العامة.
          // ==========================================
          final statsToUse = _pendingStats;
          _pendingStats = null; // مسح بعد الاستخدام

          emit(
            CustomerStreamActive(
              customers: _allCustomers,
              filteredCustomers: filteredCustomers,
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

  /// معالج استلام خطأ من stream العملاء
  void _onCustomerStreamErrorReceived(
    _CustomerStreamErrorReceived event,
    Emitter<CustomerState> emit,
  ) {
    emit(CustomerError(event.error));
  }

  /// معالج استلام البيانات من stream الإحصائيات
  void _onCustomerStatsStreamDataReceived(
    _CustomerStatsStreamDataReceived event,
    Emitter<CustomerState> emit,
  ) {
    event.result.fold(
      (failure) {
        // لا نوقف التطبيق بسبب خطأ في الإحصائيات
      },
      (stats) {
        // ===== ملاحظة للمبرمجين المستقبليين =====
        // لماذا نخزن الإحصائيات في _pendingStats هنا؟ نفس سبب
        // استخدامها في _onCustomerStreamDataReceived (أعلاه):
        // stream الإحصائيات قد يصل قبل stream العملاء، وتجاهلها
        // يفقدها إلى الأبد (لن يُعاد إرسالها ما لم يتغير مستند).
        // ==========================================

        if (state is CustomerStreamActive) {
          final currentState = state as CustomerStreamActive;

          // ✅ التحقق من تغير الإحصائيات قبل emit
          final statsChanged = currentState.stats != stats;

          if (statsChanged) {
            emit(currentState.copyWith(stats: stats));
          }
        } else if (state is CustomerLoaded) {
          final currentState = state as CustomerLoaded;

          // ✅ التحقق من تغير الإحصائيات قبل emit
          final statsChanged = currentState.stats != stats;

          if (statsChanged) {
            emit(currentState.copyWith(stats: stats));
          }
        } else if (state is CustomerLoading || state is CustomerInitial) {
          // ✅ تخزين الإحصائيات مؤقتاً لاستخدامها عند وصول بيانات العملاء
          _pendingStats = stats;
        }
      },
    );
  }

  void _onCustomerGroupsStreamDataReceived(
    _CustomerGroupsStreamDataReceived event,
    Emitter<CustomerState> emit,
  ) {
    final groups = event.groups;
    if (state is CustomerGroupsLoaded) {
      final currentState = state as CustomerGroupsLoaded;
      final groupsChanged = currentState.groups != groups;
      if (groupsChanged) {
        emit(CustomerGroupsLoaded(groups: groups));
      }
    } else {
      emit(CustomerGroupsLoaded(groups: groups));
    }
  }

  /// معالج استلام البيانات من stream سجلات العملاء
  void _onCustomerLogsStreamDataReceived(
    _CustomerLogsStreamDataReceived event,
    Emitter<CustomerState> emit,
  ) {
    event.result.fold((failure) => emit(CustomerError(failure.message)), (
      logs,
    ) {
      if (state is CustomerLogsLoaded) {
        final currentState = state as CustomerLogsLoaded;
        // ✅ التحقق من تغير السجلات قبل emit لتجنب إعادة بناء واجهة غير ضرورية
        if (!listEquals(currentState.logs, logs)) {
          emit(CustomerLogsLoaded(logs));
        }
      } else {
        emit(CustomerLogsLoaded(logs));
      }
    });
  }

  @override
  Future<void> close() async {
    await _customersStreamSubscription?.cancel();
    _customersStreamSubscription = null;
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
    await _customerGroupsStreamSubscription?.cancel();
    _customerGroupsStreamSubscription = null;
    await _customerLogsStreamSubscription?.cancel();
    _customerLogsStreamSubscription = null;
    return super.close();
  }
}
