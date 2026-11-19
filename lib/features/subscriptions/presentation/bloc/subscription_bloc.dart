import 'dart:async';

import 'package:ashur/core/services/pdf/invoice_pdf_automation_service.dart';
import 'package:ashur/core/services/push_notification_service.dart';
import 'package:ashur/core/services/section_notification_service.dart';
import 'package:ashur/core/services/settings_service.dart';
import 'package:ashur/core/services/subscription_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/subscription_log_entity.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/create_subscription.dart';
import '../../domain/usecases/get_subscription_stats_simple.dart';
import '../../domain/usecases/get_subscription_stats_stream.dart';
import '../../domain/usecases/get_subscription_types_simple.dart';
import '../../domain/usecases/get_subscriptions.dart';
import '../../domain/usecases/get_subscriptions_stream.dart';
import '../../domain/usecases/update_subscription_status.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

// ════════════════════════════════════════════════════════════
// 🔍 التحقق اليدوي الدقيق من الذريّة — BLoC الاشتراكات (تاريخ التحقق: 2026-10-12 — أُعيد التحقق بنفس التاريخ بقراءة كاملة لكل معالجات الكتابة: لا انحرافات جديدة)
// ════════════════════════════════════════════════════════════
//
// ⚠️ ملاحظة للمبرمجين المستقبليين:
// هذا التحقق (قراءة فقط، بدون أي تعديل في أي سطر
// تنفيذي) أعاد قراءة كل معالجات الكتابة في هذا الملف
// سطراً بسطر. لماذا يوجد هذا التحقق؟ لأن كل معالج
// يعدل مستندات مترابطة (اشتراك ↔ نوع ↔ سجلات ↔
// صندوق ↔ فواتير ↔ عميل): لو فشل جزء ونجح جزء صارت
// البيانات غير متسقة. الذرية تُضمن في المستودع
// (subscription_repository_impl.dart) عبر runTransaction
// واحدة — هذا الملف يستدعيها فقط.
// ✅ النتيجة: لا انحراف جديد — كل معالجات الكتابة
// تستدعي طرق المستودع الذرية مباشرة:
// _onCreateSubscription و _onRenewSubscription يمرران
// invoiceBuilder (الفاتورة + دين العميل و invoiceIds و
// relatedInvoiceIds وسجل الفاتورة تُنشأ داخل نفس
// معاملة الاشتراك/التجديد — all-or-nothing)؛
// _onUpdateSubscription و _onUpgradeSubscription
// يستخدمان expectedUpdatedAt (Optimistic Locking —
// بدونه يُتجاوز القفل بالكامل)؛ _onDeleteSubscription و
// _onUpdateSubscriptionStatus و _onRechargeActivations
// و _onCreateSubscriptionType و _onUpdateSubscriptionType
// تستدعي الطرق الذرية بالمستودع مباشرة.
// ⚠️ الاستثناءات الموثقة الوحيدة (لا تُصلح دون مراجعة):
// 1. _onUpgradeSubscription — سجل الترقية يُنشأ بعد
//    المعاملة عبر addSubscriptionLog (مقبول: الترقية
//    تنجح بلا سجل إذا فشل السجل — موثق داخل المعالج).
// 2. _applyDefaultSubscriptionTime (في المستودع) — أُصلح
//    2026-10-12: قراءة SettingsService صارت خارج معاملة
//    التجديد وتُطبق داخلها متزامناً — لم يعد يطيل عمر
//    المعاملة.
// 🔒 القواعد الذهبية (لا تنتهكها أبداً):
// 1. لا تُنشئ معاملة منفصلة للفاتورة بعد الاشتراك/
//    التجديد — مرر invoiceBuilder دائماً (وإلا صار
//    اشتراك بلا فاتورة أو فاتورة بلا اشتراك).
// 2. لا تستدعِ updateSubscription/upgrade بلا
//    expectedUpdatedAt.
// 3. الآثار الجانبية غير الفايرستورية (إشعارات Push +
//    PDF) تبقى خارج المعاملة دائماً — لا يمكن وضعها
//    داخلها.
// 🔒 نهاية التحقق اليدوي — لا تعدّل المنطق دون مراجعة هذا التحقق 🔒
// ⚠️ ملاحظات توثيقية للمبرمجين المستقبليين — اقرأ قبل أي تعديل (مدمجة لتجنب الاطاله):
// [منطق] _onLoadSubscriptions (السطر 480): filteredSubscriptions تُمرّر ككل الاشتراكات
// دون تطبيق الفلاتر/البحث عند التحميل الأولي → تُعرض كل الاشتراكات غير المفلترة.
// العلاج المتوقع: تطبيق _applyFilters(subscriptions) قبل الإرسال، أو تمرير قائمة فارغة
// والاعتماد على حدث البحث اللاحق.
// [منطق] _canAccessOrganization (الاستخدام في bloc السطر 177): يتحقق فقط من تطابق الإيميل
// المطبّع مع المنظمة المطلوبة — لا يتحقق من انتماء المنظمة الفعلي في قاعدة البيانات.
// [أداء] _onGetCustomerSubscriptions (السطر 1607)، _onGetExpiredSubscriptions (السطر 1650)،
// _onGetSubscriptionInvoices (السطر 1771): يحمل كل الاشتراكات/الفواتير ثم يصفّي في الذاكرة
// → بطيء للمجموعات الكبيرة. يفضل استخدام استعلامات المستودع المباشرة (getCustomerSubscriptions,
// getExpiredSubscriptions) بدلاً من التحميل الكامل.
// [أداء] close() (السطر 1545): يُلغي جميع الاشتراكات ما عدا _logsStreamSubscription → تسرب مورد
// محتمل إذا تم بدء سجلات الاشتراكات ولم تُوقف.
// [منطق] _onCreateSubscription (السطر 677): fold يستدعي دوال async في الفرع success
// دون await صريح للعمليات الجانبية (الإشعارات، Push، PDF) → احتمال سباق بين emit
// وانتهاء العمليات الجانبية. يُنصح بـ await صريح أو فصل العمليات الجانبية.
// [منطق] _onRenewSubscription (السطر 930-943): إذا فشل جلب الاشتراك الحالي يُوقف العملية
// بشكل صحيح (تم إصلاحه) — لا يُستكمل التجديد ببيانات ناقصة.
// [إشعارات] كتل الإشعارات (مثل الأسطر 696-718، 877-902): الأخطاء تُسجل بـ debugPrint فقط
// ولا تُضاف إلى سجل الاشتراكات → لا يوجد أثر operacional للإشعارات الفاشلة.
// [إحصائيات] _onStartSubscriptionStatsStream (السطر 262): onError في النسخة القديمة كان فارغاً
// — تم إصلاحه ليُemit خطأ للمستخدم (السطر 278-280).
// ═════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════

/// BLoC الاشتراكات مع التحديث الفوري
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc({
    required this.getSubscriptions,
    required this.getSubscriptionsStream,
    required this.getSubscriptionStatsStream,
    required this.createSubscription,
    required this.updateSubscriptionStatus,
    required this.getSubscriptionTypes,
    required this.getSubscriptionStats,
    required this.repository,
  }) : super(SubscriptionInitial()) {
    on<LoadSubscriptionsEvent>(_onLoadSubscriptions);
    on<StartSubscriptionsStreamEvent>(_onStartSubscriptionsStream);
    on<StopSubscriptionsStreamEvent>(_onStopSubscriptionsStream);
    on<StartSubscriptionStatsStreamEvent>(_onStartSubscriptionStatsStream);
    on<StopSubscriptionStatsStreamEvent>(_onStopSubscriptionStatsStream);
    on<StartSubscriptionTypesStreamEvent>(_onStartSubscriptionTypesStream);
    on<StopSubscriptionTypesStreamEvent>(_onStopSubscriptionTypesStream);
    on<StartSubscriptionLogsStreamEvent>(_onStartSubscriptionLogsStream);
    on<StopSubscriptionLogsStreamEvent>(_onStopSubscriptionLogsStream);
    on<CreateSubscriptionEvent>(_onCreateSubscription);
    on<CreateSubscriptionTypeEvent>(_onCreateSubscriptionType);
    on<UpdateSubscriptionTypeEvent>(_onUpdateSubscriptionType);
    on<UpdateSubscriptionStatusEvent>(_onUpdateSubscriptionStatus);
    on<LoadSubscriptionTypesEvent>(_onLoadSubscriptionTypes);
    on<LoadMoreSubscriptionTypesEvent>(_onLoadMoreSubscriptionTypes);
    on<LoadSubscriptionStatsEvent>(_onLoadSubscriptionStats);
    on<SearchSubscriptionsEvent>(_onSearchSubscriptions);
    on<FilterSubscriptionsEvent>(_onFilterSubscriptions);
    on<ToggleViewModeEvent>(_onToggleViewMode);
    on<DeleteSubscriptionEvent>(_onDeleteSubscription);
    on<RenewSubscriptionEvent>(_onRenewSubscription);
    on<UpdateSubscriptionEvent>(_onUpdateSubscription);
    on<LoadSubscriptionLogsEvent>(_onLoadSubscriptionLogs);
    on<RechargeActivationsEvent>(_onRechargeActivations);
    on<LoadActivationRechargesEvent>(_onLoadActivationRecharges);
    on<GetCustomerSubscriptionsEvent>(_onGetCustomerSubscriptions);
    on<GetExpiredSubscriptionsEvent>(_onGetExpiredSubscriptions);
    on<UpgradeSubscriptionEvent>(_onUpgradeSubscription);
    on<GetSubscriptionByIdEvent>(_onGetSubscriptionById);
    on<GetSubscriptionInvoicesEvent>(_onGetSubscriptionInvoices);
    on<LoadMoreSubscriptionsEvent>(_onLoadMoreSubscriptions);
    // Stream handlers
    on<_SubscriptionsStreamDataReceived>(_onSubscriptionsStreamDataReceived);
    on<_SubscriptionsStreamErrorReceived>(_onSubscriptionsStreamErrorReceived);
    on<_SubscriptionStatsStreamDataReceived>(
      _onSubscriptionStatsStreamDataReceived,
    );
    on<_SubscriptionStatsStreamErrorReceived>(
      _onSubscriptionStatsStreamErrorReceived,
    );
    on<_SubscriptionTypesStreamDataReceived>(
      _onSubscriptionTypesStreamDataReceived,
    );
    on<_SubscriptionTypesStreamErrorReceived>(
      _onSubscriptionTypesStreamErrorReceived,
    );
    on<_SubscriptionLogsStreamDataReceived>(
      _onSubscriptionLogsStreamDataReceived,
    );
    on<_SubscriptionLogsStreamErrorReceived>(
      _onSubscriptionLogsStreamErrorReceived,
    );
  }

  final GetSubscriptions getSubscriptions;
  final GetSubscriptionsStream getSubscriptionsStream;
  final GetSubscriptionStatsStream getSubscriptionStatsStream;
  final CreateSubscription createSubscription;
  final UpdateSubscriptionStatus updateSubscriptionStatus;
  final GetSubscriptionTypesSimple getSubscriptionTypes;
  final GetSubscriptionStatsSimple getSubscriptionStats;
  final SubscriptionRepository repository;

  final _emailService = EmailNormalizationService();

  // متغيرات للتحكم في الـ streams
  StreamSubscription<dynamic>? _subscriptionsStreamSubscription;
  StreamSubscription<dynamic>? _statsStreamSubscription;
  StreamSubscription<dynamic>? _typesStreamSubscription;
  DocumentSnapshot<Object?>? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  StreamSubscription<dynamic>? _logsStreamSubscription;
  String _searchQuery = '';
  String? _statusFilter;
  String? _typeFilter;
  List<SubscriptionEntity> _allSubscriptions = [];
  bool _isGridView = false;

  // ✅ تخزين مؤقت لأنواع الاشتراكات لتجنب استدعاء getSubscriptionTypes() عند كل إصدار من الستريم
  List<String>? _cachedSubscriptionTypes;
  DateTime? _subscriptionTypesCacheTime;
  static const Duration _subscriptionTypesCacheExpiry = Duration(minutes: 5);

  // متغيرات للتحكم في ترحيل أنواع الاشتراكات
  DocumentSnapshot<Object?>? _lastDocumentTypes;
  bool _isLoadingMoreTypes = false;
  bool _hasMoreTypesData = true;

  /// التحقق من إمكانية الوصول للمؤسسة
  // ✅ تم الإصلاح: تُقارن منظمة المستخدم الحالية مع المنظمة المطلوبة
  // عبر normalize لمنع الوصول لأي مؤسسة بمجرد تسجيل الدخول.
  Future<bool> _canAccessOrganization(String organizationEmail) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      if (organizationEmail.isEmpty || !organizationEmail.contains('@')) {
        return false;
      }

      // مقارنة فعلية بين بريد المستخدم الحالي وبريد المنظمة المطلوب
      final userEmail = user.email;
      if (userEmail == null || userEmail.isEmpty) return false;

      final currentOrgId = _emailService.normalize(userEmail);
      final requestedOrgId = _emailService.normalize(organizationEmail);
      return currentOrgId == requestedOrgId;
    } on Exception catch (_) {
      return false;
    }
  }

  /// بدء الاستماع للاشتراكات مع التحديث الفوري
  Future<void> _onStartSubscriptionsStream(
    StartSubscriptionsStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _subscriptionsStreamSubscription?.cancel();

    // فحص إمكانية الوصول للمؤسسة
    if (!await _canAccessOrganization(event.organizationEmail)) {
      emit(const SubscriptionError('ليس لديك صلاحية للوصول لهذه المؤسسة'));
      return;
    }

    // إيقاف الاستماع السابق إن وجد
    await _subscriptionsStreamSubscription?.cancel();

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند إعادة
    // بدء الستريم إذا كانت البيانات موجودة لأنها تمزق الواجهة وتغلق
    // الكيبورد — الستريم سيوصل البيانات المحدثة تلقائياً
    final hasExistingData =
        state is SubscriptionsStreamActive || state is SubscriptionLoaded;
    if (!hasExistingData) {
      emit(SubscriptionLoading());
    }

    try {
      final stream = getSubscriptionsStream(
        GetSubscriptionsStreamParams(
          organizationEmail: event.organizationEmail,
          limit: event.limit,
          searchQuery: event.searchQuery,
        ),
      );

      _subscriptionsStreamSubscription = stream.listen(
        (result) {
          if (!isClosed) {
            add(_SubscriptionsStreamDataReceived(result));
          }
        },
        onError: (error) {
          if (!isClosed) {
            add(_SubscriptionsStreamErrorReceived('حدث خطأ غير متوقع'));
          }
        },
        onDone: () {},
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  /// إيقاف الاستماع للاشتراكات
  Future<void> _onStopSubscriptionsStream(
    StopSubscriptionsStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _subscriptionsStreamSubscription?.cancel();
    _subscriptionsStreamSubscription = null;
  }

  /// بدء الاستماع لإحصائيات الاشتراكات مع التحديث الفوري
  Future<void> _onStartSubscriptionStatsStream(
    StartSubscriptionStatsStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _statsStreamSubscription?.cancel();

    try {
      final stream = getSubscriptionStatsStream(event.organizationEmail);

      _statsStreamSubscription = stream.listen(
        (result) {
          add(_SubscriptionStatsStreamDataReceived(result));
        },
        // ✅ عدم ابتلاع أخطاء ستريم الإحصائيات — emit حالة خطأ حتى يظهر للمستخدم
        // والمطور أي مؤشر على الفشل بدلاً من passar بصمت.
        onError: (Object error) {
          if (!isClosed) {
            add(
              _SubscriptionStatsStreamErrorReceived(
                'خطأ في تحميل إحصائيات الاشتراكات: $error',
              ),
            );
          }
        },
        onDone: () {},
      );
    } on Exception catch (error) {
      if (!emit.isDone) {
        emit(SubscriptionError('خطأ في تحميل إحصائيات الاشتراكات: $error'));
      }
    }
  }

  void _onSubscriptionStatsStreamErrorReceived(
    _SubscriptionStatsStreamErrorReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(SubscriptionError(event.error));
  }

  /// إيقاف الاستماع لإحصائيات الاشتراكات
  Future<void> _onStopSubscriptionStatsStream(
    StopSubscriptionStatsStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
  }

  /// تطبيق الفلاتر والبحث على الاشتراكات
  List<SubscriptionEntity> _applyFilters(
    List<SubscriptionEntity> subscriptions,
  ) {
    var filtered = subscriptions;

    // تطبيق فلتر الحالة
    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      if (_statusFilter == 'expiring_soon') {
        // استخدم التعريف نفسه للإحصاء والقائمة حتى تُستثنى المنتهية والملغاة والمعلقة.
        filtered = filtered
            .where((subscription) => subscription.isExpiringSoon)
            .toList();
      } else if (_statusFilter == 'active') {
        // ملاحظة: نستبعد الاشتراكات المنتهية حتى لو كان حالتها نشطة في قاعدة البيانات
        filtered = filtered
            .where(
              (subscription) =>
                  subscription.status == 'active' && !subscription.isExpired,
            )
            .toList();
      } else if (_statusFilter == 'expired') {
        // ملاحظة: نعرض أي اشتراك منتهي سواء كانت حالته منتهية أو نشطة منتهي التاريخ
        filtered = filtered
            .where((subscription) => subscription.isExpired)
            .toList();
      } else {
        filtered = filtered
            .where((subscription) => subscription.status == _statusFilter)
            .toList();
      }
    }

    // تطبيق فلتر النوع
    if (_typeFilter != null && _typeFilter!.isNotEmpty) {
      filtered = filtered
          .where((subscription) => subscription.type == _typeFilter)
          .toList();
    }

    // تطبيق البحث النصي
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((subscription) {
        return subscription.name.toLowerCase().contains(query) ||
            subscription.type.toLowerCase().contains(query) ||
            subscription.status.toLowerCase().contains(query) ||
            (subscription.customerName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  /// معالج استلام البيانات من stream الاشتراكات
  Map<String, dynamic> _calculateStats(List<SubscriptionEntity> subscriptions) {
    final total = subscriptions.length;
    // ملاحظة: نحسب النشطين كاشتراكات حالتها نشطة وليست منتهية حتى لو لم يتم تحديث الحالة في قاعدة البيانات
    final active = subscriptions
        .where((s) => s.status == 'active' && !s.isExpired)
        .length;
    final expired = subscriptions.where((s) => s.isExpired).length;
    final expiringSoon = subscriptions.where((s) => s.isExpiringSoon).length;

    return {
      'total': total,
      'active': active,
      'expired': expired,
      'expiringSoon': expiringSoon,
    };
  }

  void _onSubscriptionsStreamDataReceived(
    _SubscriptionsStreamDataReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    // إشعارات قرب/انتهاء الاشتراك تُدار من Firebase Function المجدولة
    // لتصل للمستخدمين حتى عندما تكون أجهزتهم أو التطبيق مغلقاً.
    event.result.fold(
      (failure) {
        emit(SubscriptionError(failure.message));
      },
      (subscriptions) async {
        // ✅ حفظ كل الاشتراكات في _allSubscriptions للفلترة الكاملة
        _allSubscriptions = subscriptions;

        // ✅ حساب الإحصائيات محلياً من البيانات الحالية لضمان اتساقها
        final stats = _calculateStats(subscriptions);

        final filteredSubscriptions = _applyFilters(_allSubscriptions);

        // ✅ جلب أنواع الاشتراكات مع تخزين مؤقت لمدة 5 دقائق لتجنب استدعاء
        // getSubscriptionTypes() عند كل إصدار من الستريم (أداء).
        final now = DateTime.now();
        final typesCacheValid =
            _cachedSubscriptionTypes != null &&
            _subscriptionTypesCacheTime != null &&
            now.difference(_subscriptionTypesCacheTime!) <
                _subscriptionTypesCacheExpiry;
        List<String> types;
        if (typesCacheValid) {
          types = _cachedSubscriptionTypes!;
        } else {
          types = await getSubscriptionTypes();
          _cachedSubscriptionTypes = types;
          _subscriptionTypesCacheTime = now;
        }

        // ✅ تطبيق الحد الأقصى على النتائج المفلترة للعرض في الداشبورد فقط
        final displayedFilteredSubscriptions = filteredSubscriptions.length > 10
            ? filteredSubscriptions.sublist(0, 10)
            : filteredSubscriptions;

        emit(
          SubscriptionsStreamActive(
            // ✅ إرسال كل الاشتراكات للـ state (وليس فقط 10)
            subscriptions: _allSubscriptions,
            filteredSubscriptions: displayedFilteredSubscriptions,
            subscriptionTypes: types,
            searchQuery: _searchQuery,
            statusFilter: _statusFilter,
            typeFilter: _typeFilter,
            isGridView: _isGridView,
            stats: stats,
            hasMoreData: _hasMoreData,
            isLoadingMore: _isLoadingMore,
            lastDocument: _lastDocument,
          ),
        );


      },
    );
  }

  /// معالج استلام خطأ من stream الاشتراكات
  void _onSubscriptionsStreamErrorReceived(
    _SubscriptionsStreamErrorReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(SubscriptionError(event.error));
  }

  /// معالج استلام البيانات من stream الإحصائيات
  void _onSubscriptionStatsStreamDataReceived(
    _SubscriptionStatsStreamDataReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    event.result.fold(
      (failure) {
        // لا نوقف التطبيق بسبب خطأ في الإحصائيات
      },
      (stats) {
        // ✅ التحقق من تغير الإحصائيات قبل emit
        final statsChanged = state is SubscriptionsStreamActive
            ? (state as SubscriptionsStreamActive).stats != stats
            : state is SubscriptionLoaded
            ? (state as SubscriptionLoaded).stats != stats
            : true;

        if (statsChanged) {
          if (state is SubscriptionsStreamActive) {
            final currentState = state as SubscriptionsStreamActive;
            emit(currentState.copyWith(stats: stats));
          } else if (state is SubscriptionLoaded) {
            final currentState = state as SubscriptionLoaded;
            emit(currentState.copyWith(stats: stats));
          }
        }
      },
    );
  }

  Future<void> _onLoadSubscriptions(
    LoadSubscriptionsEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    _lastDocument = null;
    _hasMoreData = true;
    try {
      if (!await _canAccessOrganization(event.organizationEmail)) {
        emit(const SubscriptionError('ليس لديك صلاحية للوصول لهذه المؤسسة'));
        return;
      }

      final subscriptionsResult = await getSubscriptions(
        event.organizationEmail,
      );
      final types = await getSubscriptionTypes();

      subscriptionsResult.fold((failure) => emit(SubscriptionError(failure.message)), (
        subscriptions,
      ) {
        _allSubscriptions = subscriptions;
        _lastDocument = null;
        _hasMoreData = false;
        final stats = _calculateStats(subscriptions);
        emit(
          SubscriptionLoaded(
            subscriptions: subscriptions,
            // ⚠️ ملاحظة للمبرمجين المستقبليين (مكتشفة في التدقيق): filteredSubscriptions = كل الاشتراكات
            // بدون تطبيق الفلاتر/البحث عند التحميل الأولي → تُعرض كل الاشتراكات غير المفلترة.
            // السبب: عند التحميل الأولي عبر _onLoadSubscriptions لا يُستدعى _applyFilters على القائمة،
            // عكس ما يحدث في _onSubscriptionsStreamDataReceived وفي أحداث البحث/التصفية لاحقاً.
            // إذا احتاجت الواجهة عرض الفلاتر المحفوظة فور التحميل يجب تطبيق _applyFilters(subscriptions)
            // هنا قبل الإرسال، أو تمرير filtredSubscriptions فارغة والاعتماد على حدث البحث اللاحق.
            filteredSubscriptions: subscriptions,
            subscriptionTypes: types,
            stats: stats,
          ),
        );
      });
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadMoreSubscriptions(
    LoadMoreSubscriptionsEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (_isLoadingMore || !_hasMoreData) return;

    final currentState = state;
    if (currentState is! SubscriptionsStreamActive) return;
    _isLoadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final subscriptionsResult = await repository.getSubscriptionsPaginated(
        organizationEmail: event.organizationEmail,
        limit: 20,
        lastDocument: _lastDocument,
      );

      subscriptionsResult.fold(
        (failure) => emit(SubscriptionError(failure.message)),
        (page) {
          if (page.subscriptions.isNotEmpty) {
            _lastDocument = page.lastDocument;
            _allSubscriptions.addAll(page.subscriptions);
            _hasMoreData = page.subscriptions.length >= 20;
          } else {
            _hasMoreData = false;
          }

          final latestState = state;
          if (latestState is SubscriptionsStreamActive) {
            emit(
              latestState.copyWith(
                subscriptions: _allSubscriptions,
                filteredSubscriptions: _applyFilters(_allSubscriptions),
                hasMoreData: _hasMoreData,
                isLoadingMore: false,
                lastDocument: _lastDocument,
              ),
            );
          }
          _isLoadingMore = false;
        },
      );
    } on Exception catch (_) {
      _isLoadingMore = false;
      final currentState = state;
      if (currentState is SubscriptionsStreamActive) {
        emit(currentState.copyWith(isLoadingMore: false));
      }
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  void _onSearchSubscriptions(
    SearchSubscriptionsEvent event,
    Emitter<SubscriptionState> emit,
  ) {
    _searchQuery = event.query;

    if (state is SubscriptionsStreamActive) {
      final currentState = state as SubscriptionsStreamActive;
      // ✅ استخدام _allSubscriptions بدلاً من currentState.subscriptions للبحث الكامل
      final filteredSubscriptions = _applyFilters(_allSubscriptions);

      // ✅ تطبيق الحد الأقصى على النتائج المفلترة
      final displayedFilteredSubscriptions = filteredSubscriptions.length > 10
          ? filteredSubscriptions.sublist(0, 10)
          : filteredSubscriptions;

      emit(
        currentState.copyWith(
          filteredSubscriptions: displayedFilteredSubscriptions,
          searchQuery: _searchQuery,
        ),
      );
    } else if (state is SubscriptionLoaded) {
      final currentState = state as SubscriptionLoaded;
      final query = event.query.toLowerCase();

      final filtered = _allSubscriptions.where((subscription) {
        return subscription.name.toLowerCase().contains(query) ||
            subscription.type.toLowerCase().contains(query) ||
            subscription.status.toLowerCase().contains(query);
      }).toList();

      emit(currentState.copyWith(filteredSubscriptions: filtered));
    }
  }

  void _onFilterSubscriptions(
    FilterSubscriptionsEvent event,
    Emitter<SubscriptionState> emit,
  ) {
    _statusFilter = event.status;
    _typeFilter = event.type;

    if (state is SubscriptionsStreamActive) {
      final currentState = state as SubscriptionsStreamActive;
      final filteredSubscriptions = _applyFilters(_allSubscriptions);

      // ✅ تطبيق الحد الأقصى على النتائج المفلترة
      final displayedFilteredSubscriptions = filteredSubscriptions.length > 10
          ? filteredSubscriptions.sublist(0, 10)
          : filteredSubscriptions;

      emit(
        currentState.copyWith(
          filteredSubscriptions: displayedFilteredSubscriptions,
          statusFilter: _statusFilter,
          typeFilter: _typeFilter,
        ),
      );
    } else if (state is SubscriptionLoaded) {
      final currentState = state as SubscriptionLoaded;

      var filtered = _allSubscriptions;

      if (event.status != null && event.status!.isNotEmpty) {
        if (event.status == 'expiring_soon') {
          // وحّد فلتر الداشبورد مع عداد الإحصائيات، واستبعد المنتهية والملغاة والمعلقة.
          filtered = filtered
              .where((subscription) => subscription.isExpiringSoon)
              .toList();
        } else {
          filtered = filtered
              .where((subscription) => subscription.status == event.status)
              .toList();
        }
      }

      if (event.type != null && event.type!.isNotEmpty) {
        filtered = filtered
            .where((subscription) => subscription.type == event.type)
            .toList();
      }

      emit(currentState.copyWith(filteredSubscriptions: filtered));
    }
  }

  void _onToggleViewMode(
    ToggleViewModeEvent event,
    Emitter<SubscriptionState> emit,
  ) {
    _isGridView = !_isGridView;

    if (state is SubscriptionsStreamActive) {
      final currentState = state as SubscriptionsStreamActive;
      emit(currentState.copyWith(isGridView: _isGridView));
    } else if (state is SubscriptionLoaded) {
      final currentState = state as SubscriptionLoaded;
      emit(currentState.copyWith(isGridView: _isGridView));
    }
  }

  // باقي المعالجات (مبسطة للتركيز على الـ streams)
  Future<void> _onCreateSubscription(
    CreateSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      // ⚠️ إصلاح الذرية (2026-10-11): كانت الفاتورة تُنشأ
      // في معاملة منفصلة بعد الاشتراك عبر InvoiceBloc
      // (_createSubscriptionInvoiceAutomatically) — إذا فشل
      // إنشاء الفاتورة بقي اشتراك بلا فاتورة (بيانات غير
      // متسقة: العميل بلا فاتورة، والإحصائيات ناقصة). الآن
      // تُجهَّز الفاتورة قبل المعاملة وتُنشأ داخل نفس
      // معاملة الاشتراك عبر invoiceBuilder (all-or-nothing).
      //
      // قراءة بيانات العميل (الدين/حد الائتمان/الهاتف)
      // وفحص الصلاحية وحد الائتمان قبل المعاملة لأن
      // Firestore لا تدعم استعلامات داخل runTransaction.
      _SubscriptionInvoiceData? invoiceData;
      if (event.subscription.customerId != null &&
          event.subscription.customerId!.isNotEmpty) {
        invoiceData = await _prepareSubscriptionInvoiceData(event.subscription);
      }

      // الفاتورة التي ستُنشأ ذرياً مع الاشتراك — تُبنى
      // داخل المعاملة من الاشتراك المُنشأ (بعد تطبيق
      // type) وتُحفظ في المتغير لاستخدامها في الإشعارات
      // و PDF بعد نجاح المعاملة.
      InvoiceEntity? createdInvoice;

      final result = await createSubscription(
        event.subscription,
        event.type,
        invoiceBuilder: invoiceData == null
            ? null
            : (createdSubscription) {
                createdInvoice = _buildSubscriptionInvoice(
                  createdSubscription,
                  invoiceData!,
                );
                return createdInvoice!;
              },
      );
      // انتظار الإشعارات والآثار الجانبية قبل إنهاء معالج الحدث.
      await result.fold(
        (failure) async {
          emit(SubscriptionError(failure.message));
        },
        (success) async {
          // الآثار الجانبية للفاتورة (غير ذرية — خارج
          // Firestore: إشعار Push + توليد وإرسال PDF)
          // مطابقةً لما كان يفعله InvoiceBloc بعد حفظ الفاتورة.
          if (createdInvoice != null) {
            _notifySubscriptionInvoiceCreated(createdInvoice!);
          }

          await SubscriptionNotificationService.notifyNewSubscription(
            event.subscription,
            actorUid: event.subscription.createdBy,
          );

          // إرسال إشعار تنظيمي بإنشاء اشتراك جديد
          final subscriptionActorEmail = event.subscription.createdBy;
          if (subscriptionActorEmail.isNotEmpty) {
            unawaited(() async {
              try {
                final isSectionEnabled =
                    await SectionNotificationService.isSectionNotificationsEnabled(
                      'subscriptions',
                    );
                if (!isSectionEnabled) return;
                final isTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'pushOnSubscriptionNew',
                    );
                if (!isTypeEnabled) return;
                await PushNotificationService.sendOrganizationNotification(
                  organizationEmail: event.subscription.organizationEmail,
                  title: '🔄 اشتراك جديد',
                  body:
                      'تم إنشاء اشتراك جديد للعميل ${event.subscription.customerName} بخطة ${event.subscription.name}. البداية: ${_formatDateTime(event.subscription.startDate)}، النهاية: ${_formatDateTime(event.subscription.endDate)}',
                  type: 'subscription_created',
                  actorEmail: subscriptionActorEmail,
                  data: {'subscriptionId': event.subscription.id},
                );
              } on Exception catch (_) {
                debugPrint(
                  'Failed to send subscription_created notification: حدث خطأ',
                );
              }
            }());
          }

          emit(const SubscriptionOperationSuccess('تم إنشاء الاشتراك بنجاح'));
        },
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onCreateSubscriptionType(
    CreateSubscriptionTypeEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final result = await repository.createSubscriptionType(event.type);
      result.fold(
        (failure) {
          emit(SubscriptionError(failure.message));
        },
        (success) {
          emit(
            const SubscriptionOperationSuccess('تم إنشاء نوع الاشتراك بنجاح'),
          );
        },
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onUpdateSubscriptionType(
    UpdateSubscriptionTypeEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final result = await repository.updateSubscriptionType(event.type);
      result.fold(
        (failure) {
          emit(SubscriptionError(failure.message));
        },
        (success) {
          emit(
            const SubscriptionOperationSuccess('تم تحديث نوع الاشتراك بنجاح'),
          );
        },
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onUpdateSubscriptionStatus(
    UpdateSubscriptionStatusEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final result = await updateSubscriptionStatus(
        subscriptionId: event.subscriptionId,
        status: event.status,
        organizationEmail: event.organizationEmail,
        reason: event.reason,
        updatedBy: event.updatedBy,
      );
      result.fold(
        (failure) => emit(SubscriptionError(failure.message)),
        (success) => emit(
          const SubscriptionOperationSuccess('تم تحديث حالة الاشتراك بنجاح'),
        ),
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadSubscriptionTypes(
    LoadSubscriptionTypesEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      // تحميل أنواع الاشتراكات من repository
      // ⚠️ إصلاح (2026-10-11): كانت تُرجع قائمة
      // فارغة (placeholder) — صفحة شحن التفعيلات
      // تُعيد تحميل الأنواع بعد كل شحن عبر هذا
      // الحدث، وكانت القائمة الفارغة تمحو قائمة
      // الأنواع في الصفحة المفتوحة. الآن تُرجع
      // الأنواع الحقيقية من المستودع.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        emit(const SubscriptionError('لم يتم تسجيل الدخول'));
        return;
      }
      final result = await repository.getSubscriptionTypes(currentUser.email!);
      result.fold(
        (failure) => emit(SubscriptionError(failure.message)),
        (types) => emit(SubscriptionTypesLoaded(types: types)),
      );
    } on Exception catch (_) {
      emit(SubscriptionError('فشل تحميل أنواع الاشتراكات: حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadMoreSubscriptionTypes(
    LoadMoreSubscriptionTypesEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (_isLoadingMoreTypes || !_hasMoreTypesData) return;

    _isLoadingMoreTypes = true;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        emit(const SubscriptionError('لم يتم تسجيل الدخول'));
        return;
      }
      final result = await repository.getSubscriptionTypesPaginated(
        organizationEmail: currentUser.email!,
        limit: 20,
        lastDocument: _lastDocumentTypes,
      );

      result.fold((failure) => emit(SubscriptionError(failure.message)), (
        page,
      ) {
        if (page.types.isNotEmpty) {
          _lastDocumentTypes = page.lastDocument;
          final currentTypes = <SubscriptionTypeEntity>[];
          final currentState = state;
          if (currentState is SubscriptionTypesLoaded) {
            currentTypes.addAll(currentState.types);
          }
          currentTypes.addAll(page.types);
          _hasMoreTypesData = page.types.length >= 20;

          emit(
            SubscriptionTypesLoaded(
              types: currentTypes,
              hasMoreTypesData: _hasMoreTypesData,
              isLoadingMoreTypes: false,
              lastDocumentTypes: _lastDocumentTypes,
            ),
          );
        } else {
          _hasMoreTypesData = false;
          final currentState = state;
          if (currentState is SubscriptionTypesLoaded) {
            emit(
              currentState.copyWith(
                hasMoreTypesData: false,
                isLoadingMoreTypes: false,
              ),
            );
          }
        }
        _isLoadingMoreTypes = false;
      });
    } on Exception catch (_) {
      _isLoadingMoreTypes = false;
      if (state is SubscriptionTypesLoaded) {
        final currentState = state as SubscriptionTypesLoaded;
        emit(currentState.copyWith(isLoadingMoreTypes: false));
      }
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadSubscriptionStats(
    LoadSubscriptionStatsEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: هذا معالج حدث LoadSubscriptionStatsEvent
    /// كان فارغاً (placeholder) منذ الإنشاء. تم تفعيله الآن لجلب الإحصائيات
    /// باستخدام GetSubscriptionStatsSimple عند طلب تحميل الإحصائيات لمرة واحدة.
    try {
      final stats = await getSubscriptionStats(event.organizationEmail);
      if (!isClosed) {
        if (state is SubscriptionsStreamActive) {
          final currentState = state as SubscriptionsStreamActive;
          emit(currentState.copyWith(stats: stats));
        } else if (state is SubscriptionLoaded) {
          final currentState = state as SubscriptionLoaded;
          emit(currentState.copyWith(stats: stats));
        }
      }
    } on Exception catch (_) {
      if (!emit.isDone) emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onDeleteSubscription(
    DeleteSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    // التحقق من الصلاحية
    final permissionChecker = PermissionChecker();
    final hasPermission = await permissionChecker.hasPermission(
      'subscriptions_delete',
    );

    if (!hasPermission) {
      emit(const SubscriptionError('ليس لديك صلاحية لحذف الاشتراكات'));
      return;
    }

    emit(SubscriptionLoading());
    try {
      final result = await repository.deleteSubscription(event.subscriptionId);
      result.fold((failure) => emit(SubscriptionError(failure.message)), (
        success,
      ) {
        emit(const SubscriptionOperationSuccess('تم حذف الاشتراك بنجاح'));

        unawaited(
          SubscriptionNotificationService.cancelSubscriptionNotifications(
            event.subscriptionId,
          ),
        );

        // إرسال إشعار تنظيمي بحذف الاشتراك
        final deleteSubActorEmail =
            FirebaseAuth.instance.currentUser?.email ?? '';
        if (deleteSubActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'subscriptions',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'pushOnSubscriptionDeleted',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.organizationEmail,
                title: '🗑️ حذف اشتراك',
                body: 'تم حذف اشتراك من النظام',
                type: 'subscription_deleted',
                actorEmail: deleteSubActorEmail,
                data: {'subscriptionId': event.subscriptionId},
              );
            } on Exception catch (_) {
              debugPrint(
                'Failed to send subscription_deleted notification: حدث خطأ',
              );
            }
          }());
        }

        add(LoadSubscriptionsEvent(event.organizationEmail));
      });
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onRenewSubscription(
    RenewSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      // ⚠️ إصلاح الذرية (2026-10-11): كانت فاتورة التجديد
      // تُنشأ في معاملة منفصلة بعد التجديد عبر InvoiceBloc
      // — إذا فشل إنشاء الفاتورة بقي اشتراك مُجدَّد بلا
      // فاتورة (بيانات غير متسقة). الآن تُجهَّز الفاتورة
      // قبل المعاملة وتُنشأ داخل نفس معاملة التجديد عبر
      // invoiceBuilder (all-or-nothing) — وتُبنى من الاشتراك
      // المُجدَّد (بالتواريخ الجديدة) داخل المعاملة.
      //
      // قراءة الاشتراك الحالي قبل المعاملة للحصول على
      // customerId (الحدث لا يحمله) — ثم قراءة بيانات
      // العميل وفحص الصلاحية وحد الائتمان (Firestore
      // لا تدعم استعلامات داخل runTransaction).
      // ✅ التحقق من توفر الاشتراك الحالي قبل المتابعة — إذا فشل الجلْب
      // أو لم يُوجد اشتراك، تُوقف العملية وتُبلغ المستخدم بدلاً من
      // المتابعة ببيانات ناقصة قد تنتج فاتورة أو تحديثاً بدون بيانات عميل صحيحة.
      _SubscriptionInvoiceData? invoiceData;
      final currentSubscriptionResult = await repository.getSubscriptionById(
        event.subscriptionId,
      );
      final currentSubscription = currentSubscriptionResult.fold(
        (failure) => null,
        (subscription) => subscription,
      );
      if (currentSubscription == null) {
        emit(const SubscriptionError('الاشتراك الحالي غير موجود'));
        return;
      }
      if (currentSubscription.customerId != null &&
          currentSubscription.customerId!.isNotEmpty) {
        invoiceData = await _prepareSubscriptionInvoiceData(
          currentSubscription,
        );
      }

      // الفاتورة التي ستُنشأ ذرياً مع التجديد — تُبنى
      // داخل المعاملة من الاشتراك المُجدَّد (بالتواريخ
      // الجديدة) وتُحفظ في المتغير لاستخدامها في
      // الإشعارات و PDF بعد نجاح المعاملة.
      InvoiceEntity? createdInvoice;

      final result = await repository.renewSubscription(
        subscriptionId: event.subscriptionId,
        organizationEmail: event.organizationEmail,
        customStartDate: event.customStartDate,
        isAutoRenew: event.isAutoRenew,
        isPaid: event.isPaid,
        invoiceBuilder: invoiceData == null
            ? null
            : (renewedSubscription) {
                createdInvoice = _buildSubscriptionInvoice(
                  renewedSubscription,
                  invoiceData!,
                );
                return createdInvoice!;
              },
      );
      await result.fold((failure) async => emit(SubscriptionError(failure.message)), (
        subscription,
      ) async {
        // إلغاء التنبيهات القديمة قبل إنشاء إشعار التجديد الجديد؛
        // الإشعاران يستخدمان معرف التجديد نفسه، لذا يجب منع سباق الإلغاء والجدولة.
        await SubscriptionNotificationService.cancelSubscriptionNotifications(
          subscription.id,
        );

        // الآثار الجانبية للفاتورة (غير ذرية — خارج
        // Firestore: إشعار Push + توليد وإرسال PDF)
        // مطابقةً لما كان يفعله InvoiceBloc بعد حفظ الفاتورة.
        if (createdInvoice != null) {
          _notifySubscriptionInvoiceCreated(createdInvoice!);
        }

        await SubscriptionNotificationService.notifyRenewedSubscription(
          subscription,
          actorUid: FirebaseAuth.instance.currentUser?.uid,
        );

        // إرسال إشعار تنظيمي بتجديد الاشتراك
        final renewActorEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        if (renewActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'subscriptions',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'pushOnSubscriptionRenewed',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.organizationEmail,
                title: '🔄 تجديد اشتراك',
                body:
                    'تم تجديد اشتراك العميل ${subscription.customerName} بخطة ${subscription.name}. البداية: ${_formatDateTime(subscription.startDate)}، النهاية: ${_formatDateTime(subscription.endDate)}',
                type: 'subscription_renewed',
                actorEmail: renewActorEmail,
                data: {'subscriptionId': subscription.id},
              );
            } on Exception catch (_) {
              debugPrint(
                'Failed to send subscription_renewed notification: حدث خطأ',
              );
            }
          }());
        }

        emit(const SubscriptionOperationSuccess('تم تجديد الاشتراك بنجاح'));
      });
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onUpdateSubscription(
    UpdateSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      // ⚠️ ملاحظة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ expectedUpdatedAt إلزامي هنا (القاعدة الذهبية
      // 5 في أعلى ملف المستودع: بدونه يُتجاوز القفل
      // بالكامل). event.subscription.updatedAt هو
      // updatedAt الأصلي المخزن (حُفظ في صفحة التعديل
      // عبر widget.subscription.updatedAt) — تُقارن
      // القيمة المخزنة الحالية داخل المعاملة: لو
      // عدّل مستخدم آخر الاشتراك منذ فتح الصفحة
      // تُلغى المعاملة ويظهر خطأ واضح بدلاً من
      // فقدان تحديثه بصمت (Lost Update Problem).
      // نفس نمط _onUpgradeSubscription أدناه.
      final result = await repository.updateSubscription(
        event.subscription,
        expectedUpdatedAt: event.subscription.updatedAt.millisecondsSinceEpoch,
      );
      await result.fold(
        (failure) async => emit(SubscriptionError(failure.message)),
        (success) async {
          await SubscriptionNotificationService.cancelSubscriptionNotifications(
            event.subscription.id,
          );

          emit(const SubscriptionOperationSuccess('تم تحديث الاشتراك بنجاح'));

          // إرسال إشعار تنظيمي بتحديث الاشتراك
          final updateSubActorEmail =
              event.subscription.updatedBy ?? event.subscription.createdBy;
          if (updateSubActorEmail.isNotEmpty) {
            unawaited(() async {
              try {
                final isSectionEnabled =
                    await SectionNotificationService.isSectionNotificationsEnabled(
                      'subscriptions',
                    );
                if (!isSectionEnabled) return;
                final isTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'pushOnSubscriptionUpdated',
                    );
                if (!isTypeEnabled) return;
                await PushNotificationService.sendOrganizationNotification(
                  organizationEmail: event.subscription.organizationEmail,
                  title: '✏️ تعديل اشتراك',
                  body:
                      'تم تحديث اشتراك العميل ${event.subscription.customerName}. البداية: ${_formatDateTime(event.subscription.startDate)}، النهاية: ${_formatDateTime(event.subscription.endDate)}',
                  type: 'subscription_updated',
                  actorEmail: updateSubActorEmail,
                  data: {'subscriptionId': event.subscription.id},
                );
              } on Exception catch (_) {
                debugPrint(
                  'Failed to send subscription_updated notification: حدث خطأ',
                );
              }
            }());
          }
        },
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadSubscriptionLogs(
    LoadSubscriptionLogsEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final result = await repository.getSubscriptionLogs(
        userId: event.userId,
        searchQuery: event.searchQuery,
        actionFilter: event.actionFilter,
        dateFilter: event.dateFilter,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit,
      );

      result.fold(
        (failure) => emit(SubscriptionError(failure.message)),
        (logs) => emit(SubscriptionLogsLoaded(logs: logs)),
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  // Stream handlers for Subscription Types
  Future<void> _onStartSubscriptionTypesStream(
    StartSubscriptionTypesStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _typesStreamSubscription?.cancel();
    _typesStreamSubscription = null;

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is SubscriptionsStreamActive ||
        state is SubscriptionLoaded ||
        state is SubscriptionTypesLoaded;
    if (!hasExistingData) {
      emit(SubscriptionLoading());
    }

    try {
      // الحصول على البريد الإلكتروني للمستخدم الحالي
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        emit(const SubscriptionError('لم يتم تسجيل الدخول'));
        return;
      }

      // ⚠️ إصلاح (2026-10-11): كانت هذه الدالة تحمل
      // الأنواع مرة واحدة فقط (getSubscriptionTypes)
      // دون الاستماع للتغييرات — صفحة الأنواع لا
      // تتحدث عند شحن تفعيلات أو تعديل/حذف نوع.
      // الآن تستمع للستريم الحقيقي من المستودع
      // للتحديث الفوري.
      final stream = repository.getSubscriptionTypesStream(currentUser.email!);
      _typesStreamSubscription = stream.listen(
        (result) {
          if (!isClosed) {
            result.fold(
              (failure) =>
                  add(_SubscriptionTypesStreamErrorReceived(failure.message)),
              (types) => add(_SubscriptionTypesStreamDataReceived(types)),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            add(
              _SubscriptionTypesStreamErrorReceived(
                'فشل تحميل أنواع الاشتراكات: $error',
              ),
            );
          }
        },
      );
    } on Exception catch (_) {
      emit(SubscriptionError('فشل تحميل أنواع الاشتراكات: حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onStopSubscriptionTypesStream(
    StopSubscriptionTypesStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _typesStreamSubscription?.cancel();
    _typesStreamSubscription = null;
  }

  Future<void> _onSubscriptionTypesStreamDataReceived(
    _SubscriptionTypesStreamDataReceived event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionTypesLoaded(types: event.types));
  }

  void _onSubscriptionTypesStreamErrorReceived(
    _SubscriptionTypesStreamErrorReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(SubscriptionError(event.error));
  }

  // Stream handlers for Subscription Logs
  Future<void> _onStartSubscriptionLogsStream(
    StartSubscriptionLogsStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _logsStreamSubscription?.cancel();
    _logsStreamSubscription = null;

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is SubscriptionsStreamActive ||
        state is SubscriptionLoaded ||
        state is SubscriptionLogsLoaded;
    if (!hasExistingData) {
      emit(SubscriptionLoading());
    }

    try {
      // ⚠️ ملاحظة (2026-10-11): سجلات الاشتراكات
      // كانت تُحمل مرة واحدة فقط — الصفحة لا
      // تتحدث عند إضافة سجل جديد (إنشاء/تعديل/
      // حذف/تجديد اشتراك). الآن تستمع للستريم
      // الحقيقي من المستودع للتحديث الفوري.
      final stream = repository.getSubscriptionLogsStream(
        userId: event.userId,
        searchQuery: event.searchQuery,
        actionFilter: event.actionFilter,
        dateFilter: event.dateFilter,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit,
      );
      _logsStreamSubscription = stream.listen(
        (result) {
          if (!isClosed) {
            result.fold(
              (failure) =>
                  add(_SubscriptionLogsStreamErrorReceived(failure.message)),
              (logs) => add(_SubscriptionLogsStreamDataReceived(logs)),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            add(
              _SubscriptionLogsStreamErrorReceived(
                'خطأ في تحميل سجلات الاشتراكات: $error',
              ),
            );
          }
        },
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  void _onSubscriptionLogsStreamDataReceived(
    _SubscriptionLogsStreamDataReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(SubscriptionLogsLoaded(logs: event.logs));
  }

  void _onSubscriptionLogsStreamErrorReceived(
    _SubscriptionLogsStreamErrorReceived event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(SubscriptionError(event.error));
  }

  Future<void> _onStopSubscriptionLogsStream(
    StopSubscriptionLogsStreamEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _logsStreamSubscription?.cancel();
    _logsStreamSubscription = null;
  }

  /// تجهيز بيانات فاتورة الاشتراك قبل المعاملة
  ///
  /// ⚠️ ملاحظة ذرية (إصلاح 2026-10-11):
  /// كانت الفاتورة تُنشأ في معاملة منفصلة بعد
  /// الاشتراك/التجديد عبر InvoiceBloc — إذا فشل إنشاء
  /// الفاتورة بقي اشتراك بلا فاتورة (بيانات غير متسقة).
  /// الآن تُنشأ الفاتورة داخل نفس معاملة الاشتراك عبر
  /// invoiceBuilder في Repository (all-or-nothing).
  ///
  /// هذه الدالة تُنفذ قبل المعاملة لأن Firestore لا
  /// تدعم استعلامات (getCustomers) داخل runTransaction:
  /// 1. فحص صلاحية invoices_subscription_manage
  /// 2. قراءة بيانات العميل (الدين/حد الائتمان/الهاتف)
  /// 3. تحذير حد الائتمان (تحذير فقط — الفاتورة تُنشأ
  ///    دائماً مطابقةً لسلوك InvoiceBloc السابق)
  /// 4. توليد معرف الفاتورة مسبقاً — يُحترم في
  ///    _createInvoiceInTransaction (يُستخدم invoice.id
  ///    إن لم يكن فارغاً) ليعرفه الطرف المُنشئ لتوليد
  ///    PDF والإشعارات بعد نجاح المعاملة.
  ///
  /// تُرجع null إذا لم تُنشأ فاتورة (بلا صلاحية).
  Future<_SubscriptionInvoiceData?> _prepareSubscriptionInvoiceData(
    SubscriptionEntity subscription,
  ) async {
    // التحقق من الصلاحية أولاً
    final permissionChecker = GetIt.instance<PermissionChecker>();
    final hasPermission = await permissionChecker.hasPermission(
      'invoices_subscription_manage',
    );

    if (!hasPermission) {
      // تسجيل الخطأ
      final currentUser = FirebaseAuth.instance.currentUser;
      unawaited(
        repository.addSubscriptionLog(
          userId: currentUser?.uid ?? 'unknown',
          userName: currentUser?.displayName,
          userEmail: currentUser?.email,
          actionType: 'auto_invoice_creation_permission_denied',
          details: 'ليس لديه صلاحية إنشاء فاتورة اشتراك',
          targetId: subscription.id,
          targetType: 'subscription',
          isSuccess: false,
        ),
      );
      return null; // الخروج بدون إنشاء الفاتورة
    }

    // قراءة بيانات العميل الحالية (خارج المعاملة —
    // Firestore لا تدعم استعلامات داخل runTransaction)
    // ⚡ تحسين أداء (2026-10-12): تُقرأ بيانات العميل
    // عبر getCustomerById (مستند واحد O(1) محدد نطاق
    // مؤسسة المستخدم الحالي) بدلاً من getCustomers
    // التي تجلب كل العملاء O(n) ثم firstWhere — كان
    // هذا أبطأ مسار في القسم عند إنشاء/تجديد اشتراك
    // لعميل في مؤسسة لها عملاء كثر (مؤسسة بـ 1000
    // عميل كانت تقرأ 1000 مستند لتعرف دين عميل واحد).
    // النتيجة متطابقة: نفس الحقول (totalDebt/phone/
    // name/creditLimit) من نفس المستند، والمؤسسة واحدة
    // (التطبيق يفرض مؤسسة واحدة لكل مستخدم —
    // _getCurrentOrganizationId يعيد بريد المستخدم
    // الحالي المطبّع دائماً، والمستخدم المحوّل إليه
    // يغير الاسم فقط لا المؤسسة).
    var currentBalance = 0.0;
    var customerPhone = '';
    var customerName = '';
    var creditLimit = 0.0;
    final customerRepository = GetIt.instance<CustomerRepository>();
    final customerId = subscription.customerId;
    if (customerId != null && customerId.isNotEmpty) {
      final customerResult = await customerRepository.getCustomerById(
        customerId,
      );
      customerResult.fold(
        (failure) {
          // العميل غير موجود أو فشلت القراءة —
          // تُترك القيم الافتراضية (نفس سلوك
          // firstWhere الذي يرمي Exception عند
          // عدم العثور على العميل)
        },
        (customer) {
          currentBalance = customer.totalDebt;
          customerPhone = customer.phone;
          customerName = customer.name;
          creditLimit = customer.creditLimit ?? 0;
        },
      );
    }

    // فحص حد الائتمان — تحذير فقط ولا يمنع إنشاء الفاتورة
    // (مطابقةً لسلوك InvoiceBloc._onAddInvoice السابق حيث
    // كان التحذير يُعرض للمستخدم وتُحفظ الفاتورة دائماً).
    // ⚠️ لا يمكن إصدار InvoiceCreditLimitWarning من هنا
    // لأنها حدث خاص بـ InvoiceBloc stream — لذلك تُوثَّق
    // في سجل الاشتراك بدلاً منها.
    final newDebt = currentBalance + subscription.price;
    if (creditLimit > 0 && newDebt > creditLimit) {
      final currentUser = FirebaseAuth.instance.currentUser;
      unawaited(
        repository.addSubscriptionLog(
          userId: currentUser?.uid ?? 'unknown',
          userName: currentUser?.displayName,
          userEmail: currentUser?.email,
          actionType: 'credit_limit_warning',
          details:
              'تجاوز حد الائتمان عند إنشاء فاتورة اشتراك: الدين الحالي $currentBalance + الفاتورة ${subscription.price} = $newDebt (الحد المسموح: $creditLimit) للعميل $customerName',
          targetId: subscription.id,
          targetType: 'subscription',
          isSuccess: true,
        ),
      );
    }

    // توليد معرف الفاتورة مسبقاً (معرّف عشوائي لا يتأثر
    // بالمسار) ليُحترم في _createInvoiceInTransaction
    final invoiceId = FirebaseFirestore.instance
        .collection(subscription.organizationEmail)
        .doc('invoices')
        .collection('invoices')
        .doc()
        .id;

    return _SubscriptionInvoiceData(
      invoiceId: invoiceId,
      customerPhone: customerPhone,
      currentBalance: currentBalance,
    );
  }

  /// بناء فاتورة الاشتراك (دالة نقية — تُستدعى داخل
  /// المعاملة عبر invoiceBuilder مع الاشتراك المُنشأ
  /// أو المُجدَّد لضمان أن بيانات الفاتورة (خاصة
  /// التواريخ) مطابقة للاشتراك المحفوظ فعلياً)
  InvoiceEntity _buildSubscriptionInvoice(
    SubscriptionEntity subscription,
    _SubscriptionInvoiceData data,
  ) {
    // إنشاء رقم فاتورة تلقائي
    final now = DateTime.now();
    final invoiceNumber =
        'SUB-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    // إنشاء عنصر الفاتورة للاشتراك
    final subscriptionItem = InvoiceItemEntity(
      productName: 'اشتراك - ${subscription.name}',
      quantity: 1,
      unitPrice: subscription.price,
      totalPrice: subscription.price,
      unit: _getDurationLabel(subscription.duration),
    );

    // إنشاء ملاحظات الفاتورة مع معلومات الاشتراك والميزات
    String featuresNotes = '';
    if (subscription.features != null && subscription.features!.isNotEmpty) {
      // الميزات مخزنة كـ {'items': ['ميزة 1', 'ميزة 2']}
      final items = subscription.features!['items'];
      if (items is List) {
        final featuresList = items.cast<String>().toList();
        if (featuresList.isNotEmpty) {
          featuresNotes =
              '\nالميزات:\n${featuresList.map((f) => '• $f').join('\n')}';
        }
      }
    }

    // إضافة معلومات الضرائب والخصم
    String taxAndDiscountNotes = '';
    if (subscription.discountAmount > 0 || subscription.taxAmount > 0) {
      if (subscription.discountAmount > 0) {
        taxAndDiscountNotes += '\nالخصم: ${subscription.discountAmount}';
      }
      if (subscription.taxAmount > 0) {
        taxAndDiscountNotes += '\nالضريبة: ${subscription.taxAmount}';
      }
      // إضافة تفاصيل الضرائب المتعددة
      if (subscription.taxes != null && subscription.taxes!.isNotEmpty) {
        for (var tax in subscription.taxes!) {
          final taxName = tax['name'] as String;
          final taxAmount = tax['amount'] as double;
          taxAndDiscountNotes += '\n$taxName: $taxAmount';
        }
      }
    }

    final notes =
        'فاتورة اشتراك تم إنشاؤها تلقائياً: ${subscription.name}\nالنوع: ${subscription.type}\nالمدة: ${_getDurationLabel(subscription.duration, customDays: subscription.customDays)}\nمن ${_formatDateTime(subscription.startDate)} إلى ${_formatDateTime(subscription.endDate)}$featuresNotes$taxAndDiscountNotes';

    // إنشاء الفاتورة
    return InvoiceEntity(
      id: data.invoiceId,
      invoiceNumber: invoiceNumber,
      customerName: subscription.customerName ?? 'عميل',
      customerPhone: data.customerPhone,
      customerId: subscription.customerId,
      subscriptionId: subscription.id,
      invoiceDate: DateTime.now(),
      totalAmount: subscription.price,
      paidAmount: 0,
      remainingAmount: subscription.price,
      status: 'unpaid',
      type: 'subscription',
      items: [subscriptionItem],
      notes: notes,
      organizationEmail: subscription.organizationEmail,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'النظام',
      balanceBeforeInvoice: data.currentBalance,
      balanceAfterInvoice: data.currentBalance + subscription.price,
      discountAmount: subscription.discountAmount,
      taxAmount: subscription.taxAmount,
      taxes: subscription.taxes,
    );
  }

  /// الآثار الجانبية لإنشاء فاتورة الاشتراك (غير ذرية —
  /// تتطلب عمليات خارج Firestore مثل إشعارات Push و
  /// توليد PDF فلا يمكن وضعها داخل المعاملة).
  /// مطابقةً لما كان يفعله InvoiceBloc._onAddInvoice
  /// بعد حفظ الفاتورة: إشعار تنظيمي + توليد وإرسال PDF.
  void _notifySubscriptionInvoiceCreated(InvoiceEntity invoice) {
    // إرسال إشعار تنظيمي لبقية المستخدمين في نفس المؤسسة
    final actorEmail = invoice.createdBy;

    if (actorEmail.isNotEmpty) {
      unawaited(() async {
        try {
          final isSectionEnabled =
              await SectionNotificationService.isSectionNotificationsEnabled(
                'invoices',
              );
          if (!isSectionEnabled) return;
          final isTypeEnabled = await SettingsService.isNotificationTypeEnabled(
            'invoice_notify_new',
          );
          if (!isTypeEnabled) return;
          await PushNotificationService.sendOrganizationNotification(
            organizationEmail: invoice.organizationEmail,
            title: '📄 فاتورة جديدة (${invoice.invoiceNumber})',
            body:
                'تم إصدار فاتورة جديدة للعميل ${invoice.customerName} بمبلغ إجمالي ${invoice.totalAmount.toStringAsFixed(0)} د.ع',
            type: 'invoice_created',
            actorEmail: actorEmail,
            data: {
              'invoiceId': invoice.id,
              'invoiceNumber': invoice.invoiceNumber,
            },
          );
        } on Exception catch (_) {
          debugPrint('Failed to send invoice_created notification: حدث خطأ');
        }
      }());
    }

    // توليد وإرسال PDF تلقائياً للفاتورة
    if (invoice.customerPhone.isNotEmpty) {
      try {
        final pdfAutomationService = InvoicePdfAutomationService();
        unawaited(
          pdfAutomationService.generateAndSendInvoicePdf(
            invoice: invoice,
            organizationEmail: invoice.organizationEmail,
          ),
        );
      } on Exception catch (_) {
        // تجاهل أخطاء توليد PDF
      }
    }
  }

  /// الحصول على تسمية المدة
  String _getDurationLabel(String duration, {int? customDays}) {
    switch (duration) {
      case 'daily':
        return 'يوم';
      case 'weekly':
        return 'أسبوع';
      case 'monthly':
        return 'شهر';
      case 'quarterly':
        return '3 أشهر';
      case 'yearly':
        return 'سنة';
      case 'custom':
        // عرض عدد الأيام المخصصة بدلاً من كلمة "مخصص"
        if (customDays != null && customDays > 0) {
          return '$customDays يوم';
        }
        return 'مخصص';
      default:
        return duration;
    }
  }

  /// تنسيق التاريخ والوقت لحفظهما ضمن ملاحظات الفاتورة وإظهارهما للعميل.
  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> close() async {
    await _subscriptionsStreamSubscription?.cancel();
    await _statsStreamSubscription?.cancel();
    await _typesStreamSubscription?.cancel();
    await _logsStreamSubscription?.cancel();
    return super.close();
  }

  // ===== Activation Recharge Handlers =====

  Future<void> _onRechargeActivations(
    RechargeActivationsEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final result = await repository.rechargeActivations(
        subscriptionTypeId: event.subscriptionTypeId,
        subscriptionTypeName: event.subscriptionTypeName,
        quantity: event.quantity,
        pricePerActivation: event.pricePerActivation,
        organizationEmail: event.organizationEmail,
        createdBy: event.createdBy,
        boxId: event.boxId,
      );

      result.fold(
        (failure) => emit(SubscriptionError(failure.message)),
        (success) => emit(
          const ActivationRechargeSuccess(message: 'تم شحن التفعيلات بنجاح'),
        ),
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadActivationRecharges(
    LoadActivationRechargesEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final result = await repository.getActivationRecharges(
        subscriptionTypeId: event.subscriptionTypeId,
        organizationEmail: event.organizationEmail,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit,
      );

      result.fold(
        (failure) => emit(SubscriptionError(failure.message)),
        (recharges) => emit(ActivationRechargesLoaded(recharges: recharges)),
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  // ===== Missing Event Handlers =====

  Future<void> _onGetCustomerSubscriptions(
    GetCustomerSubscriptionsEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      if (!await _canAccessOrganization(event.organizationEmail)) {
        emit(const SubscriptionError('ليس لديك صلاحية للوصول لهذه المؤسسة'));
        return;
      }

      // ⚠️ ملاحظة أداء للمبرمجين المستقبليين: الكود يحمل كل الاشتراكات ثم
      /// يصفّي في الذاكرة عبر where(customerId). للمجموعات الكبيرة هذا بطيء.
      /// المستودع يوفر getSubscriptionTypes/getCustomerSubscriptions الذي
      /// يستعلم عبر Firestore مباشرة — يُنصح باستخدامه بدلاً من التحميل الكامل.
      final result = await getSubscriptions(event.organizationEmail);
      result.fold((failure) => emit(SubscriptionError(failure.message)), (
        subscriptions,
      ) {
        final customerSubs = subscriptions
            .where((s) => s.customerId == event.customerId)
            .toList();

        List<SubscriptionEntity> filtered = customerSubs;
        if (event.status != null && event.status!.isNotEmpty) {
          filtered = customerSubs
              .where((s) => s.status == event.status)
              .toList();
        }

        emit(
          CustomerSubscriptionsLoaded(
            customerId: event.customerId,
            subscriptions: filtered,
          ),
        );
      });
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onGetExpiredSubscriptions(
    GetExpiredSubscriptionsEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      if (!await _canAccessOrganization(event.organizationEmail)) {
        emit(const SubscriptionError('ليس لديك صلاحية للوصول لهذه المؤسسة'));
        return;
      }

      // ⚠️ ملاحظة أداء للمبرمجين المستقبليين: الكود يحمل كل الاشتراكات ثم
      /// يصفّي عبر isExpired في الذاكرة. المستودع يوفر getExpiredSubscriptions
      /// الذي يستعلم عبر Firestore مباشرة — يُنصح باستخدامه بدلاً من التحميل الكامل.
      final result = await getSubscriptions(event.organizationEmail);
      result.fold((failure) => emit(SubscriptionError(failure.message)), (
        subscriptions,
      ) {
        final expired = subscriptions.where((s) => s.isExpired).toList();
        emit(ExpiredSubscriptionsLoaded(subscriptions: expired));
      });
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onUpgradeSubscription(
    UpgradeSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final subscription = event.subscription;

      // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ نستخدم expectedUpdatedAt لمنع Lost Update Problem.
      // ⚠️ يجب أن يكون الاشتراك قد تم جلبه قبل التحديث
      // ⚠️ لضمان أن expectedUpdatedAt صحيح.
      // ⚠️ إذا لم تكن لديك expectedUpdatedAt، لا تستدعي هذه الدالة
      // ⚠️ لأنك ستكون عرضة لـ Lost Update Problem.
      final expectedUpdatedAt = subscription.updatedAt.millisecondsSinceEpoch;

      // جلب الاشتراك الحالي للحصول على oldValues
      final currentResult = await repository.getSubscriptionById(
        subscription.id,
      );
      final oldValues = currentResult.fold(
        (failure) => null,
        (sub) => sub?.toJson(),
      );

      final newValues = subscription.toJson();

      final result = await repository.updateSubscription(
        subscription,
        expectedUpdatedAt: expectedUpdatedAt,
      );

      result.fold((failure) => emit(SubscriptionError(failure.message)), (
        success,
      ) async {
        // ⚠️ ملاحظة مهمة للمبرمجين المستقبليين حول الذرية (Atomicity):
        // ⚠️ إنشاء سجل الترقية يتم بعد انتهاء Transaction!
        // ⚠️ هذا يعني أنه إذا فشل إنشاء السجل، فإن الترقية ستنجح
        // ⚠️ بدون سجل. هذا مقبول حالياً لأن سجل الترقية
        // ⚠️ ليس جزءاً من Transaction الأساسية.
        // ⚠️ إذا كنتَ تريد ذرية كاملة، استخدم Cloud Function.
        if (oldValues != null) {
          unawaited(
            repository.addSubscriptionLog(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              userName: FirebaseAuth.instance.currentUser?.displayName,
              userEmail: FirebaseAuth.instance.currentUser?.email,
              actionType: 'upgrade_subscription',
              details: 'تم ترقية الاشتراك: ${subscription.name}',
              targetId: subscription.id,
              targetType: 'subscription',
              oldValues: oldValues,
              newValues: newValues,
              isSuccess: true,
            ),
          );
        }

        emit(const SubscriptionOperationSuccess('تم ترقية الاشتراك بنجاح'));
      });
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onGetSubscriptionById(
    GetSubscriptionByIdEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      if (!await _canAccessOrganization(event.organizationEmail)) {
        emit(const SubscriptionError('ليس لديك صلاحية للوصول لهذه المؤسسة'));
        return;
      }

      final result = await repository.getSubscriptionById(event.subscriptionId);
      result.fold(
        (failure) => emit(SubscriptionError(failure.message)),
        (subscription) => emit(
          SubscriptionByIdLoaded(
            subscriptionId: event.subscriptionId,
            subscription: subscription,
          ),
        ),
      );
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onGetSubscriptionInvoices(
    GetSubscriptionInvoicesEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(SubscriptionLoading());
    try {
      final invoiceRepository = GetIt.instance<InvoiceRepository>();
      // ⚠️ ملاحظة أداء للمبرمجين المستقبليين: الكود يحمل كل الفواتير ثم يصفّي
      /// في الذاكرة عبر subscriptionId. للمجموعات الكبيرة هذا بطيء. يُنصح
      /// بإضافة استعلام مخصص في InvoiceRepository يجلب فواتير الاشتراك المحدد فقط.
      final result = await invoiceRepository.getInvoices(
        event.organizationEmail,
      );
      result.fold((failure) => emit(SubscriptionError(failure.message)), (
        invoices,
      ) {
        final subscriptionInvoices = invoices
            .where((i) => i.subscriptionId == event.subscriptionId)
            .toList();
        emit(SubscriptionInvoicesLoaded(invoices: subscriptionInvoices));
      });
    } on Exception catch (_) {
      emit(SubscriptionError('حدث خطأ غير متوقع'));
    }
  }
}

/// بيانات فاتورة الاشتراك المُقرأة قبل المعاملة
/// (معرف الفاتورة المُولَّد مسبقاً + بيانات العميل)
class _SubscriptionInvoiceData {
  const _SubscriptionInvoiceData({
    required this.invoiceId,
    required this.customerPhone,
    required this.currentBalance,
  });

  final String invoiceId;
  final String customerPhone;
  final double currentBalance;
}

// Internal Stream Events
class _SubscriptionsStreamDataReceived extends SubscriptionEvent {
  const _SubscriptionsStreamDataReceived(this.result);
  final Either<Failure, List<SubscriptionEntity>> result;

  @override
  List<Object?> get props => [result];
}

class _SubscriptionsStreamErrorReceived extends SubscriptionEvent {
  const _SubscriptionsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

class _SubscriptionStatsStreamDataReceived extends SubscriptionEvent {
  const _SubscriptionStatsStreamDataReceived(this.result);
  final Either<Failure, Map<String, dynamic>> result;

  @override
  List<Object?> get props => [result];
}

class _SubscriptionStatsStreamErrorReceived extends SubscriptionEvent {
  const _SubscriptionStatsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

class _SubscriptionTypesStreamErrorReceived extends SubscriptionEvent {
  const _SubscriptionTypesStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

class _SubscriptionLogsStreamDataReceived extends SubscriptionEvent {
  const _SubscriptionLogsStreamDataReceived(this.logs);
  final List<SubscriptionLogEntity> logs;

  @override
  List<Object?> get props => [logs];
}

class _SubscriptionLogsStreamErrorReceived extends SubscriptionEvent {
  const _SubscriptionLogsStreamErrorReceived(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}

class _SubscriptionTypesStreamDataReceived extends SubscriptionEvent {
  const _SubscriptionTypesStreamDataReceived(this.types);
  final List<SubscriptionTypeEntity> types;

  @override
  List<Object?> get props => [types];
}
