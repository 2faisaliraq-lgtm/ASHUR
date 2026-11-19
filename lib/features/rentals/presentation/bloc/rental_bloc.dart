import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../../../core/services/rental_notification_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../invoices/domain/entities/invoice_entity.dart';
import '../../../invoices/presentation/bloc/invoice_bloc.dart' as invoice_bloc;
import '../../domain/entities/rental_entity.dart';
import '../../domain/entities/rental_log_entity.dart';
import '../../domain/repositories/rental_repository.dart';
import '../../domain/usecases/create_rental.dart';
import '../../domain/usecases/get_rental_logs_stream.dart';
import '../../domain/usecases/get_rental_stats.dart';
import '../../domain/usecases/get_rentals.dart';
import '../../domain/usecases/get_rentals_stats_stream.dart';
import '../../domain/usecases/get_rentals_stream.dart';
import '../../domain/usecases/update_rental.dart';

part 'rental_event.dart';
part 'rental_state.dart';

class RentalBloc extends Bloc<RentalEvent, RentalState> {
  RentalBloc({
    required this.getRentals,
    required this.getRentalsStream,
    required this.getRentalsStatsStream,
    required this.createRental,
    required this.updateRental,
    required this.getRentalStats,
    required this.getRentalLogsStream,
    required this.repository,
  }) : super(RentalInitial()) {
    on<LoadRentalsEvent>(_onLoadRentals);
    on<CreateRentalEvent>(_onCreateRental);
    on<UpdateRentalEvent>(_onUpdateRental);
    on<DeleteRentalEvent>(_onDeleteRental);
    on<SearchRentalsEvent>(_onSearchRentals);
    on<FilterRentalsEvent>(_onFilterRentals);
    on<ToggleRentalViewModeEvent>(_onToggleViewMode);
    on<ReturnRentalEvent>(_onReturnRental);
    on<LoadRentalLogsEvent>(_onLoadRentalLogs);
    on<LoadMoreRentalsEvent>(_onLoadMoreRentals);

    // Logs stream handlers
    on<StartRentalLogsStreamEvent>(_onStartRentalLogsStream);
    on<StopRentalLogsStreamEvent>(_onStopRentalLogsStream);
    on<RentalLogsStreamDataReceived>(_onRentalLogsStreamDataReceived);

    // Stream handlers
    // ⚠️ ملاحظة للمبرمجين المستقبليين: _onDeleteRental يتحقق من صلاحية rentals_delete
    // داخل البلوك، بينما _onCreateRental و _onUpdateRental لا يتحقان هنا — عدم اتساق مقصود حالياً،
    // راجع توحيد السلوك إذا أُضيف التحقق في المستقبل.
    on<StartRentalsStreamEvent>(_onStartRentalsStream);
    on<StopRentalsStreamEvent>(_onStopRentalsStream);
    on<StartRentalsStatsStreamEvent>(_onStartRentalsStatsStream);
    on<StopRentalsStatsStreamEvent>(_onStopRentalsStatsStream);
    on<RentalsStreamDataReceived>(_onRentalsStreamDataReceived);
    on<RentalsStreamErrorReceived>(_onRentalsStreamErrorReceived);
    on<RentalsStatsStreamDataReceived>(_onRentalsStatsStreamDataReceived);
  }
  final GetRentals getRentals;
  final GetRentalsStream getRentalsStream;
  final GetRentalsStatsStream getRentalsStatsStream;
  final CreateRental createRental;
  final UpdateRental updateRental;
  final GetRentalStats getRentalStats;
  final GetRentalLogsStream getRentalLogsStream;
  final RentalRepository repository;

  List<RentalEntity> _allRentals = [];
  DocumentSnapshot<Object?>? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String _searchQuery =
      ''; // متغير قابل للتعديل ليتم تحديثه من حدث البحث (كان final ولا يُحدّث أبدًا، مما جعل البحث معطلاً)
  StreamSubscription<Either<Failure, List<RentalEntity>>>?
  _rentalsStreamSubscription;
  StreamSubscription<Either<Failure, Map<String, dynamic>>>?
  _rentalsStatsStreamSubscription;
  StreamSubscription<Either<Failure, List<RentalLogEntity>>>?
  _rentalLogsStreamSubscription;
  Map<String, dynamic>?
  _pendingStats; // ✅ تخزين الإحصائيات الواصلة قبل بيانات الإيجارات

  Future<void> _onLoadRentals(
    LoadRentalsEvent event,
    Emitter<RentalState> emit,
  ) async {
    emit(RentalLoading());
    _lastDocument = null;
    _isLoadingMore = false;
    _hasMoreData = true;
    try {
      final rentalsResult = await getRentals(event.organizationEmail);

      rentalsResult.fold((failure) => emit(RentalError(failure.message)), (
        rentals,
      ) {
        _allRentals = rentals;
        // ⚡ تحسين أداء (2026-10-12): حساب الإحصائيات
        // من القائمة المجلوبة بدلاً من getRentalStats
        // التي تعيد جلب كل العقود مرة أخرى (كان التحميل
        // الأولي يجلب العقود مرتين). المنطق مطابق
        // تماماً لمنطق getRentalStats في المستودع.
        emit(
          RentalLoaded(
            rentals: rentals,
            filteredRentals: rentals,
            stats: _computeStats(rentals),
          ),
        );
      });
    } on Exception catch (_) {
      emit(RentalError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onLoadMoreRentals(
    LoadMoreRentalsEvent event,
    Emitter<RentalState> emit,
  ) async {
    if (_isLoadingMore || !_hasMoreData) return;

    final currentState = state;
    if (currentState is! RentalsStreamActive) return;
    _isLoadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final rentalsResult = await repository.getRentalsPaginated(
        organizationEmail: event.organizationEmail,
        limit: 20,
        lastDocument: _lastDocument,
      );

      rentalsResult.fold((failure) => emit(RentalError(failure.message)), (
        page,
      ) {
        if (page.rentals.isNotEmpty) {
          _lastDocument = page.lastDocument;
          _allRentals.addAll(page.rentals);
          _hasMoreData = page.rentals.length >= 20;
        } else {
          _hasMoreData = false;
        }

        final currentState = state;
        if (currentState is RentalsStreamActive) {
          emit(
            currentState.copyWith(
              rentals: _allRentals,
              filteredRentals: _allRentals,
              hasMoreData: _hasMoreData,
              isLoadingMore: false,
            ),
          );
        }
        _isLoadingMore = false;
      });
    } on Exception catch (_) {
      _isLoadingMore = false;
      final currentState = state;
      if (currentState is RentalsStreamActive) {
        emit(currentState.copyWith(isLoadingMore: false));
      }
      emit(RentalError('حدث خطأ غير متوقع'));
    }
  }

  /// حساب إحصائيات الإيجارات من قائمة العقود المحملة
  /// (مطابق لمنطق getRentalStats في المستودع — لتجنب
  /// جلب العقود مرتين عند التحميل الأولي)
  /// ملاحظة للمبرمجين المستقبليين: مفاتيح الخريطة موحدة مع RentalStatsSection
  /// (total, active, expired, expiringSoon, totalMonthlyIncome) ومع
  /// getRentalsStatisticsStream في المستودع لتجنب عرض أصفار عند التبديل
  /// بين وضع الستريم والوضع العادي.
  Map<String, dynamic> _computeStats(List<RentalEntity> rentals) {
    return {
      'total': rentals.length,
      'active': rentals.where((r) => r.isActive).length,
      'expired': rentals.where((r) => r.isExpired).length,
      'expiringSoon': rentals.where((r) => r.isExpiringSoon).length,
      'totalMonthlyIncome': rentals
          .where((r) => r.isActive)
          .fold<double>(0, (total, r) => total + r.rentalPrice),
    };
  }

  Future<void> _onCreateRental(
    CreateRentalEvent event,
    Emitter<RentalState> emit,
  ) async {
    // التحقق من الصلاحية قبل الإنشاء
    final permissionChecker = PermissionChecker();
    final hasCreatePermission = await permissionChecker.hasPermission(
      'rentals_create',
    );
    if (!hasCreatePermission) {
      emit(const RentalError('ليس لديك صلاحية لإنشاء عقود الإيجار'));
      return;
    }

    try {
      emit(RentalLoading());
      final result = await createRental(event.rental);
      await result.fold((failure) async => emit(RentalError(failure.message)), (
        _,
      ) async {
        // ===== ملاحظة ذرية للمبرمجين المستقبليين (تحقق 2026-10-11) =====
        // لماذا لا نضع السجل والإشعار والفاتورة في نفس runTransaction مع العقد؟
        // لأنها تأثيرات جانبية: فشلها لا يجب أن يتراجع عن إنشاء العقد الأصلي.
        // السجل fire-and-forget عمداً، والفاتورة أفضل جهد مع مهلة 10 ثوانٍ.
        // العقد نفسه ذري بالفعل في createRental داخل المستودع
        // (مع تأجير الوحدة المرتبطة في نفس المعاملة).
        // ما يجب أن يكون ذرياً: العقد والوحدة معاً. ما يجب
        // ألا يكون ذرياً معهما: السجل والإشعار والفاتورة.
        // (تُطبق نفس القاعدة في _onUpdateRental و _onDeleteRental)
        // ===============================================
        // تسجيل العملية في السجل
        unawaited(
          repository.addRentalLog(
            userId: 'current_user',
            actionType: 'create_rental',
            details: 'تم إنشاء عقد إيجار جديد: ${event.rental.itemName}',
            targetId: event.rental.id,
            targetType: 'rental',
            newValues: {
              'itemName': event.rental.itemName,
              'itemDescription': event.rental.itemDescription,
              'renterName': event.rental.renterName,
              'renterPhone': event.rental.renterPhone,
              'renterEmail': event.rental.renterEmail,
              'rentalPrice': event.rental.rentalPrice,
              'deposit': event.rental.deposit,
              'startDate': event.rental.startDate.toIso8601String(),
              'endDate': event.rental.endDate.toIso8601String(),
              'status': event.rental.status,
              'paymentFrequency': event.rental.paymentFrequency,
              'paymentDay': event.rental.paymentDay,
              'unitId': event.rental.unitId,
            },
          ),
        );

        // إرسال إشعار تنظيمي بإنشاء عقد إيجار جديد
        final rentalActorEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        if (rentalActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'rentals',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'rental_notify_new',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.rental.organizationEmail,
                title: '🏠 عقد إيجار جديد',
                body:
                    'تم إنشاء عقد إيجار جديد: ${event.rental.itemName} للمستأجر ${event.rental.renterName}',
                type: 'rental_created',
                actorEmail: rentalActorEmail,
                data: {'rentalId': event.rental.id},
              );
            } on Exception catch (e) {
              debugPrint('Failed to send rental_created notification: $e');
            }
          }());
        }

        // إنشاء فاتورة الإيجار تلقائياً إذا كان مرتبط بعميل
        var invoiceCreated = false;
        final shouldCreateInvoice =
            event.rental.customerId != null &&
            event.rental.customerId!.isNotEmpty &&
            event.rental.customerName != null &&
            event.rental.customerName!.isNotEmpty;
        if (shouldCreateInvoice) {
          invoiceCreated = await _createRentalInvoiceAutomatically(
            event.rental,
            skipCreditCheck: event.skipInvoiceCreditCheck,
          );
        }

        // توضيح النتيجة الفعلية؛ إنشاء العقد لا يعني أن الفاتورة حُفظت.
        emit(
          RentalOperationSuccess(
            shouldCreateInvoice
                ? invoiceCreated
                      ? 'تم إنشاء عقد الإيجار وفاتورته بنجاح'
                      : 'تم إنشاء عقد الإيجار، لكن تعذر حفظ فاتورة الإيجار'
                : 'تم إنشاء عقد الإيجار بنجاح',
          ),
        );

        // ⚡ تحسين أداء (2026-10-12): عندما يكون
        // ستريم الإيجارات نشطاً تصل البيانات
        // المحدثة تلقائياً عبر
        // _onRentalsStreamDataReceived — لا حاجة
        // لإعادة الجلب اليدوي. نعيد التحميل
        // فقط عندما لا يوجد ستريم نشط (صفحات
        // لا تستخدم الستريم)، والإحصائيات تُحسب
        // من القائمة المجلوبة (نفس نمط
        // _onLoadRentals) بدلاً من getRentalStats
        // التي تعيد جلب كل العقود مرة أخرى
        // (جلب مزدوج — المنطق مطابق تماماً
        // لمنطقها في المستودع).
        if (_rentalsStreamSubscription == null) {
          final rentalsResult = await getRentals(
            event.rental.organizationEmail,
          );

          rentalsResult.fold((failure) => emit(RentalError(failure.message)), (
            rentals,
          ) {
            _allRentals = rentals;
            emit(
              RentalLoaded(
                rentals: rentals,
                filteredRentals: rentals,
                stats: _computeStats(rentals),
              ),
            );
          });
        }
      });
    } on Exception catch (_) {
      emit(RentalError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onUpdateRental(
    UpdateRentalEvent event,
    Emitter<RentalState> emit,
  ) async {
    // التحقق من الصلاحية قبل التحديث
    final permissionChecker = PermissionChecker();
    final hasEditPermission = await permissionChecker.hasPermission(
      'rentals_edit',
    );
    if (!hasEditPermission) {
      emit(const RentalError('ليس لديك صلاحية لتعديل عقود الإيجار'));
      return;
    }

    try {
      emit(RentalLoading());
      final result = await updateRental(event.rental);
      await result.fold((failure) async => emit(RentalError(failure.message)), (
        _,
      ) async {
        // تسجيل العملية في السجل (تأثير جانبي متعمد خارج معاملة العقد —
        // انظر ملاحظة الذرية في _onCreateRental)
        unawaited(
          repository.addRentalLog(
            userId: 'current_user',
            actionType: 'update_rental',
            details: 'تم تحديث عقد الإيجار: ${event.rental.itemName}',
            targetId: event.rental.id,
            targetType: 'rental',
            newValues: {
              'itemName': event.rental.itemName,
              'itemDescription': event.rental.itemDescription,
              'renterName': event.rental.renterName,
              'renterPhone': event.rental.renterPhone,
              'renterEmail': event.rental.renterEmail,
              'rentalPrice': event.rental.rentalPrice,
              'deposit': event.rental.deposit,
              'startDate': event.rental.startDate.toIso8601String(),
              'endDate': event.rental.endDate.toIso8601String(),
              'status': event.rental.status,
              'paymentFrequency': event.rental.paymentFrequency,
              'paymentDay': event.rental.paymentDay,
              'unitId': event.rental.unitId,
            },
          ),
        );

        // إرسال إشعار تنظيمي بتحديث عقد الإيجار
        final updateRentalActorEmail =
            FirebaseAuth.instance.currentUser?.email ?? '';
        if (updateRentalActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'rentals',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'rental_notify_updated',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.rental.organizationEmail,
                title: '✏️ تعديل عقد إيجار (${event.rental.itemName})',
                body:
                    'تم تحديث عقد إيجار ${event.rental.itemName} للمستأجر ${event.rental.renterName}',
                type: 'rental_updated',
                actorEmail: updateRentalActorEmail,
                data: {'rentalId': event.rental.id},
              );
            } on Exception catch (e) {
              debugPrint('Failed to send rental_updated notification: $e');
            }
          }());
        }

        // إرسال رسالة النجاح أولاً
        emit(const RentalOperationSuccess('تم تحديث عقد الإيجار بنجاح'));

        // ⚡ تحسين أداء (2026-10-12): نفس نمط
        // _onCreateRental — عندما يكون ستريم
        // الإيجارات نشطاً تصل البيانات
        // تلقائياً، ولا نعيد الجلب اليدوي.
        // نعيد التحميل فقط عندما لا يوجد ستريم
        // نشط، والإحصائيات تُحسب من القائمة
        // المجلوبة (نفس نمط _onLoadRentals)
        // بدلاً من getRentalStats (جلب مزدوج).
        if (_rentalsStreamSubscription == null) {
          final rentalsResult = await getRentals(
            event.rental.organizationEmail,
          );

          rentalsResult.fold((failure) => emit(RentalError(failure.message)), (
            rentals,
          ) {
            _allRentals = rentals;
            emit(
              RentalLoaded(
                rentals: rentals,
                filteredRentals: rentals,
                stats: _computeStats(rentals),
              ),
            );
          });
        }
      });
    } on Exception catch (_) {
      emit(RentalError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> _onDeleteRental(
    DeleteRentalEvent event,
    Emitter<RentalState> emit,
  ) async {
    // ملاحظة للمبرمجين المستقبليين: delete يتحقق من الصلاحية داخل البلوك،
    // بينما create/update لا يتحققان هنا — عدم اتساق مقصود حالياً، راجع توحيد السلوك.
    final permissionChecker = PermissionChecker();
    final hasPermission = await permissionChecker.hasPermission(
      'rentals_delete',
    );

    if (!hasPermission) {
      emit(const RentalError('ليس لديك صلاحية لحذف عقود الإيجار'));
      return;
    }

    try {
      emit(RentalLoading());
      final result = await repository.deleteRental(
        event.id,
        event.organizationEmail,
      );
      await result.fold((failure) async => emit(RentalError(failure.message)), (
        _,
      ) async {
        // تسجيل العملية في السجل (تأثير جانبي متعمد خارج معاملة العقد —
        // انظر ملاحظة الذرية في _onCreateRental)
        unawaited(
          repository.addRentalLog(
            userId: 'current_user',
            actionType: 'delete_rental',
            details: 'تم حذف عقد الإيجار',
            targetId: event.id,
            targetType: 'rental',
          ),
        );

        // إرسال إشعار تنظيمي بحذف عقد الإيجار
        final deleteRentalActorEmail =
            FirebaseAuth.instance.currentUser?.email ?? '';
        if (deleteRentalActorEmail.isNotEmpty) {
          unawaited(() async {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'rentals',
                  );
              if (!isSectionEnabled) return;
              final isTypeEnabled =
                  await SettingsService.isNotificationTypeEnabled(
                    'rental_notify_deleted',
                  );
              if (!isTypeEnabled) return;
              await PushNotificationService.sendOrganizationNotification(
                organizationEmail: event.organizationEmail,
                title: '🗑️ حذف عقد إيجار',
                body: 'تم حذف عقد إيجار من النظام',
                type: 'rental_deleted',
                actorEmail: deleteRentalActorEmail,
                data: {'rentalId': event.id},
              );
            } on Exception catch (e) {
              debugPrint('Failed to send rental_deleted notification: $e');
            }
          }());
        }

        // إرسال رسالة النجاح (مطابقة للإنشاء والتعديل —
        // تُضاف لاستكمال المعالج حال تمرير الحدث من
        // أي صفحة مستقبلاً؛ الحذف الحالي يتم من حوار
        // الحذف مباشرة إلى المستودع مع السجل والإشعار)
        emit(const RentalOperationSuccess('تم حذف عقد الإيجار بنجاح'));

        // ⚡ تحسين أداء (2026-10-12): نفس نمط
        // _onCreateRental — عندما يكون ستريم
        // الإيجارات نشطاً تصل البيانات
        // تلقائياً، ولا نعيد الجلب اليدوي.
        // نعيد التحميل فقط عندما لا يوجد ستريم
        // نشط، والإحصائيات تُحسب من القائمة
        // المجلوبة (نفس نمط _onLoadRentals)
        // بدلاً من getRentalStats (جلب مزدوج).
        if (_rentalsStreamSubscription == null) {
          final rentalsResult = await getRentals(event.organizationEmail);

          rentalsResult.fold((failure) => emit(RentalError(failure.message)), (
            rentals,
          ) {
            _allRentals = rentals;
            emit(
              RentalLoaded(
                rentals: rentals,
                filteredRentals: rentals,
                stats: _computeStats(rentals),
              ),
            );
          });
        }
      });
    } on Exception catch (_) {
      emit(RentalError('حدث خطأ غير متوقع'));
    }
  }

  /// تطبيق الفلاتر على الإيجارات (البحث النصي + حالة العقد)
  /// ملاحظة للمبرمجين المستقبليين: هذه الدالة تُطبَّق على _allRentals في الذاكرة.
  /// يُنصح بعدم إضافة حد اصطناعي هنا (مثل sublist(0, 10)) لأن ذلك يقطع نتائج البحث/الفلترة
  /// ويُربك المستخدم. يُ laiss الحد للتطبيق في واجهة المستخدم فقط (RentalsGrid يعرض أول 10 في الداشبورد).
  List<RentalEntity> _applyFilters(
    List<RentalEntity> rentals, {
    String? statusFilter,
  }) {
    var filtered = rentals;

    // تطبيق فلتر الحالة إذا تم تمريره
    if (statusFilter != null && statusFilter != 'all') {
      filtered = filtered
          .where((rental) => rental.status == statusFilter)
          .toList();
    }

    // تطبيق البحث النصي
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((rental) {
        return rental.itemName.toLowerCase().contains(query) ||
            rental.renterName.toLowerCase().contains(query) ||
            (rental.itemDescription?.toLowerCase().contains(query) ?? false) ||
            (rental.renterPhone?.toLowerCase().contains(query) ?? false) ||
            (rental.renterEmail?.toLowerCase().contains(query) ?? false) ||
            (rental.customerName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  void _onSearchRentals(SearchRentalsEvent event, Emitter<RentalState> emit) {
    _searchQuery =
        event.query; // تحديث متغير البحث ليتم تطبيقه في _applyFilters
    // ملاحظة للمبرمجين المستقبليين: يتم تطبيق البحث مع فلتر الحالة الحالي (إن وُجد)
    // عبر _applyFilters دون قطع النتائج إلى 10 عناصر.
    if (state is RentalsStreamActive) {
      final currentState = state as RentalsStreamActive;
      final filtered = _applyFilters(
        _allRentals,
        statusFilter: currentState.statusFilter,
      );
      emit(currentState.copyWith(filteredRentals: filtered));
    } else if (state is RentalLoaded) {
      final currentState = state as RentalLoaded;
      // ملاحظة للمبرمجين المستقبليين: RentalLoaded لا تحتفظ بحالة فلتر الحالة (statusFilter)،
      // لذلك يُمرَّر null هنا؛ يُطبَّق البحث النصي فقط في هذا المسار.
      final filtered = _applyFilters(_allRentals, statusFilter: null);
      emit(currentState.copyWith(filteredRentals: filtered));
    }
  }

  void _onFilterRentals(FilterRentalsEvent event, Emitter<RentalState> emit) {
    // ملاحظة للمبرمجين المستقبليين: تم إزالة الحد الاصطناعي البالغ 10 عناصر (sublist(0, 10))
    // الذي كان يقطع نتائج الفلترة. الآن يُطبَّق البحث النصي والحالة معاً عبر _applyFilters
    // بدون أي حد اصطناعي على عدد النتائج المعروضة.
    final filtered = _applyFilters(_allRentals, statusFilter: event.status);

    final currentState = state;
    if (currentState is RentalsStreamActive) {
      emit(currentState.copyWith(filteredRentals: filtered));
    } else if (currentState is RentalLoaded) {
      emit(currentState.copyWith(filteredRentals: filtered));
    }
  }

  void _onToggleViewMode(
    ToggleRentalViewModeEvent event,
    Emitter<RentalState> emit,
  ) {
    if (state is RentalLoaded) {
      final currentState = state as RentalLoaded;
      emit(currentState.copyWith(isGridView: !currentState.isGridView));
    }
  }

  /// معالج إرجاع عقد إيجار — يستخدم إعداد rental_notify_returned للإشعار
  Future<void> _onReturnRental(
    ReturnRentalEvent event,
    Emitter<RentalState> emit,
  ) async {
    // التحقق من الصلاحية قبل الإرجاع
    final permissionChecker = PermissionChecker();
    final hasEditPermission = await permissionChecker.hasPermission(
      'rentals_edit',
    );
    if (!hasEditPermission) {
      emit(const RentalError('ليس لديك صلاحية لإرجاع عقود الإيجار'));
      return;
    }

    try {
      emit(RentalLoading());

      // جلب العقد الحالي لتحديثه
      final rentalResult = await repository.getRentalById(
        event.id,
        event.organizationEmail,
      );

      rentalResult.fold((failure) => emit(RentalError(failure.message)), (
        rental,
      ) async {
        final returnedRental = rental.copyWith(
          status: 'returned',
          updatedAt: DateTime.now(),
        );

        final updateResult = await updateRental(returnedRental);

        updateResult.fold((failure) => emit(RentalError(failure.message)), (
          _,
        ) async {
          // تسجيل العملية في السجل
          unawaited(
            repository.addRentalLog(
              userId: 'current_user',
              actionType: 'return',
              details: 'تم إرجاع عقد الإيجار: ${returnedRental.itemName}',
              targetId: event.id,
              targetType: 'rental',
              newValues: {
                'status': 'returned',
                'updatedAt': returnedRental.updatedAt?.toIso8601String(),
              },
            ),
          );

          // إرسال إشعار تنظيمي بإرجاع عقد الإيجار (إذا كان الإعداد مفعلاً)
          final returnRentalActorEmail =
              FirebaseAuth.instance.currentUser?.email ?? '';
          if (returnRentalActorEmail.isNotEmpty) {
            unawaited(() async {
              try {
                final isSectionEnabled =
                    await SectionNotificationService.isSectionNotificationsEnabled(
                      'rentals',
                    );
                if (!isSectionEnabled) return;
                final isTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'rental_notify_returned',
                    );
                if (!isTypeEnabled) return;
                await PushNotificationService.sendOrganizationNotification(
                  organizationEmail: returnedRental.organizationEmail,
                  title: '↩️ إرجاع عقد إيجار',
                  body:
                      'تم إرجاع عقد الإيجار: ${returnedRental.itemName} للمستأجر ${returnedRental.renterName}',
                  type: 'rental_returned',
                  actorEmail: returnRentalActorEmail,
                  data: {'rentalId': returnedRental.id},
                );
              } on Exception catch (e) {
                debugPrint('Failed to send rental_returned notification: $e');
              }
            }());
          }

          // إرسال رسالة النجاح
          emit(const RentalOperationSuccess('تم إرجاع عقد الإيجار بنجاح'));

          // إعادة تحميل البيانات إذا لم يكن هناك ستريم نشط
          if (_rentalsStreamSubscription == null) {
            final rentalsResult = await getRentals(
              returnedRental.organizationEmail,
            );
            rentalsResult.fold(
              (failure) => emit(RentalError(failure.message)),
              (rentals) {
                _allRentals = rentals;
                emit(
                  RentalLoaded(
                    rentals: rentals,
                    filteredRentals: rentals,
                    stats: _computeStats(rentals),
                  ),
                );
              },
            );
          }
        });
      });
    } on Exception catch (_) {
      emit(RentalError('حدث خطأ غير متوقع'));
    }
  }

  /// معالج تحميل سجلات الإيجارات
  Future<void> _onLoadRentalLogs(
    LoadRentalLogsEvent event,
    Emitter<RentalState> emit,
  ) async {
    emit(RentalLoading());
    try {
      final result = await repository.getRentalLogs(
        userId: event.userId,
        searchQuery: event.searchQuery,
        actionFilter: event.actionFilter,
        dateFilter: event.dateFilter,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit ?? 50,
      );

      result.fold(
        (failure) => emit(RentalError(failure.message)),
        (logs) => emit(RentalLogsLoaded(logs)),
      );
    } on Exception catch (_) {
      emit(RentalError('حدث خطأ غير متوقع'));
    }
  }

  // Logs stream handlers
  Future<void> _onStartRentalLogsStream(
    StartRentalLogsStreamEvent event,
    Emitter<RentalState> emit,
  ) async {
    await _rentalLogsStreamSubscription?.cancel();
    _rentalLogsStreamSubscription =
        getRentalLogsStream(
          GetRentalLogsStreamParams(
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
            (failure) => emit(RentalError(failure.message)),
            (logs) => add(RentalLogsStreamDataReceived(logs)),
          );
        });
  }

  Future<void> _onStopRentalLogsStream(
    StopRentalLogsStreamEvent event,
    Emitter<RentalState> emit,
  ) async {
    await _rentalLogsStreamSubscription?.cancel();
    _rentalLogsStreamSubscription = null;
  }

  void _onRentalLogsStreamDataReceived(
    RentalLogsStreamDataReceived event,
    Emitter<RentalState> emit,
  ) {
    emit(RentalLogsLoaded(event.logs));
  }

  /// إنشاء فاتورة إيجار تلقائياً
  Future<bool> _createRentalInvoiceAutomatically(
    RentalEntity rental, {
    required bool skipCreditCheck,
  }) async {
    try {
      // ⚡ تحسين أداء (2026-10-12): جلب العميل بمعرفه
      // مباشرة (مستند واحد) بدلاً من تحميل كل العملاء
      // ثم البحث بالقائمة — getCustomerById مقيّد
      // بمؤسسة المستخدم الحالي ويقرأ مستنداً واحداً
      // فقط (O(1) بدلاً من جلب المجموعة كاملة).
      final customerRepository = GetIt.instance<CustomerRepository>();
      final customerResult = await customerRepository.getCustomerById(
        rental.customerId!,
      );

      double currentBalance = 0;
      CustomerEntity? customer;

      customerResult.fold((failure) {}, (foundCustomer) {
        customer = foundCustomer;
        currentBalance = foundCustomer.totalDebt;
      });

      // حساب الحساب بعد الفاتورة (فاتورة إيجار تزيد الدين)
      final balanceAfter = currentBalance + rental.rentalPrice;

      // ملاحظة: لا نقوم بتحديث حساب العميل هنا مباشرة
      // سيتم تحديثه تلقائياً عند حفظ الفاتورة في InvoiceBloc

      // إنشاء رقم فاتورة تلقائي
      final now = DateTime.now();
      final invoiceNumber = InvoiceNumberingService.generateNumberSync(
        section: 'rental',
      );

      // إنشاء عنصر الفاتورة للإيجار
      final rentalItem = InvoiceItemEntity(
        productName: 'إيجار - ${rental.itemName}',
        quantity: 1,
        unitPrice: rental.rentalPrice,
        totalPrice: rental.rentalPrice,
        unit: 'فترة',
      );

      // إنشاء الفاتورة
      final invoice = InvoiceEntity(
        id: '',
        invoiceNumber: invoiceNumber,
        customerName: rental.customerName!,
        customerPhone: rental.renterPhone ?? '',
        customerId: rental.customerId,
        invoiceDate: DateTime.now(),
        totalAmount: rental.rentalPrice,
        paidAmount: 0,
        remainingAmount: rental.rentalPrice,
        status: 'unpaid',
        type: 'rental',
        items: [rentalItem],
        notes:
            '''
فاتورة إيجار تم إنشاؤها تلقائياً
الصنف: ${rental.itemName}
الوصف: ${rental.itemDescription ?? 'لا يوجد'}
سعر الإيجار: ${rental.rentalPrice.toStringAsFixed(2)} د.ع
التأمين: ${rental.deposit.toStringAsFixed(2)} د.ع
فترة الإيجار: من ${_formatDate(rental.startDate)} إلى ${_formatDate(rental.endDate)}
تكرار الدفع: ${_getPaymentFrequencyName(rental.paymentFrequency)}''',
        organizationEmail: rental.organizationEmail,
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
                Exception('تم رفض فاتورة الإيجار بسبب تجاوز حد الدين'),
              );
            }
          } else if (state is invoice_bloc.InvoiceOperationSuccess) {
            invoiceStreamSubscription?.cancel();
            completer.complete();
          } else if (state is invoice_bloc.InvoiceError) {
            invoiceStreamSubscription?.cancel();
            completer.completeError(state.message);
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
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            invoiceStreamSubscription?.cancel();
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('انتهت مهلة انتظار معالجة الفاتورة'),
              );
            }
          },
        );

        // توليد وإرسال PDF تلقائياً للفاتورة
        try {
          final pdfAutomationService = InvoicePdfAutomationService();
          unawaited(
            pdfAutomationService.generateAndSendInvoicePdf(
              invoice: invoice,
              organizationEmail: rental.organizationEmail,
            ),
          );
        } on Exception catch (_) {
          // تجاهل أخطاء توليد PDF بعد نجاح حفظ الفاتورة
        }
        return true;
      }
      return false;
    } on Exception catch (e) {
      debugPrint('Failed to create automatic rental invoice: $e');
      return false;
    }
  }

  // Stream handlers
  Future<void> _onStartRentalsStream(
    StartRentalsStreamEvent event,
    Emitter<RentalState> emit,
  ) async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل
    // هنا لأنها تهدم الواجهة وتغلق الكيبورد — الستريم
    // سيوصل البيانات المحدثة تلقائياً
    await _rentalsStreamSubscription?.cancel();
    _lastDocument = null;
    _isLoadingMore = false;
    _hasMoreData = true;
    _allRentals = [];

    final params = GetRentalsStreamParams(
      limit: event.limit,
      searchQuery: event.searchQuery,
      statusFilter: event.statusFilter,
      customerFilter: event.customerFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
    );

    _rentalsStreamSubscription = getRentalsStream(params).listen((result) {
      result.fold(
        (failure) => add(RentalsStreamErrorReceived(failure.message)),
        (rentals) => add(RentalsStreamDataReceived(rentals)),
      );
    });
  }

  Future<void> _onStopRentalsStream(
    StopRentalsStreamEvent event,
    Emitter<RentalState> emit,
  ) async {
    await _rentalsStreamSubscription?.cancel();
    _rentalsStreamSubscription = null;
  }

  Future<void> _onStartRentalsStatsStream(
    StartRentalsStatsStreamEvent event,
    Emitter<RentalState> emit,
  ) async {
    await _rentalsStatsStreamSubscription?.cancel();

    _rentalsStatsStreamSubscription = getRentalsStatsStream(NoParams()).listen((
      result,
    ) {
      result.fold(
        (failure) => add(RentalsStreamErrorReceived(failure.message)),
        (stats) => add(RentalsStatsStreamDataReceived(stats)),
      );
    });
  }

  Future<void> _onStopRentalsStatsStream(
    StopRentalsStatsStreamEvent event,
    Emitter<RentalState> emit,
  ) async {
    await _rentalsStatsStreamSubscription?.cancel();
    _rentalsStatsStreamSubscription = null;
  }

  void _onRentalsStreamDataReceived(
    RentalsStreamDataReceived event,
    Emitter<RentalState> emit,
  ) {
    // ✅ حفظ كل الإيجارات للفلترة الكاملة
    _allRentals = event.rentals;

    // ملاحظة للمبرمجين المستقبليين: عند وصول بيانات الستريم تلقائياً (تغيير خارجي)،
    // يُطبَّق _applyFilters دون statusFilter، مما يفقد فلتر الحالة المحدد مسبقاً في
    // RentalsStreamActive. إذا كان فلتر الحالة مطلوباً هنا، يجب تمريره من الحالة الحالية.
    //
    // ⚠️ ملاحظة: تم إزالة الحد الاصطناعي البالغ 10 عناصر لتجنب قطع نتائج الفلترة.
    // يتم عرض جميع الإيجارات دون حد اصطناعي، ويترك الحد لواجهة المستخدم فقط.
    var filteredRentals = _applyFilters(_allRentals);

    // الحفاظ على فلتر الحالة من الحالة السابقة إذا كان موجوداً
    String? currentStatusFilter;
    RentalsStreamActive? streamActiveState;
    if (state is RentalsStreamActive) {
      streamActiveState = state as RentalsStreamActive;
    }
    if (streamActiveState != null) {
      currentStatusFilter = streamActiveState.statusFilter;
    } else {
      currentStatusFilter = null;
    }
    if (currentStatusFilter != null && currentStatusFilter != 'all') {
      filteredRentals = filteredRentals
          .where((rental) => rental.status == currentStatusFilter)
          .toList();
    }

    final displayedFilteredRentals = filteredRentals;

    // تطبيق الفلتر إذا كان هناك حالة سابقة
    if (state is RentalsStreamActive) {
      final currentState = state as RentalsStreamActive;

      // ✅ التحقق من تغير البيانات قبل emit
      final rentalsChanged = !listEquals(currentState.rentals, _allRentals);
      final filteredRentalsChanged = !listEquals(
        currentState.filteredRentals,
        displayedFilteredRentals,
      );

      if (rentalsChanged || filteredRentalsChanged) {
        emit(
          currentState.copyWith(
            rentals: _allRentals,
            filteredRentals: displayedFilteredRentals,
            statistics: currentState.statistics, // ✅ حفظ الإحصائيات
          ),
        );
      }
    } else if (state is RentalLoaded) {
      final currentState = state as RentalLoaded;

      emit(
        RentalsStreamActive(
          rentals: _allRentals,
          filteredRentals: displayedFilteredRentals,
          statusFilter: null,
          searchQuery: '',
          // لماذا _pendingStats هنا؟ لأن الإحصائيات قد تصل
          // قبل بيانات الإيجارات — الشرح الكامل في
          // _onRentalsStatsStreamDataReceived.
          statistics: _pendingStats ?? currentState.stats,
          isGridView: currentState.isGridView,
        ),
      );
      _pendingStats = null; // مسح بعد الاستخدام
    } else {
      emit(
        RentalsStreamActive(
          rentals: _allRentals,
          filteredRentals: filteredRentals,
          // لماذا _pendingStats هنا؟ لأن الإحصائيات قد تصل
          // قبل بيانات الإيجارات — الشرح الكامل في
          // _onRentalsStatsStreamDataReceived.
          statistics: _pendingStats,
        ),
      );
      _pendingStats = null; // مسح بعد الاستخدام
    }
  }

  void _onRentalsStreamErrorReceived(
    RentalsStreamErrorReceived event,
    Emitter<RentalState> emit,
  ) {
    emit(RentalError(event.error));
  }

  void _onRentalsStatsStreamDataReceived(
    RentalsStatsStreamDataReceived event,
    Emitter<RentalState> emit,
  ) {
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا نقوم بتخزين الإحصائيات في _pendingStats عندما تكون
    // الحالة RentalLoading أو RentalInitial؟
    // لأنه في صفحة الداشبورد، يبدأ stream الإحصائيات
    // وstream الإيجارات في نفس الوقت. من المحتمل أن يصل
    // stream الإحصائيات قبل stream الإيجارات.
    // إذا تجاهلنا الإحصائيات في هذه الحالة، سنفقدها إلى الأبد
    // لأن stream الإحصائيات لن يعيد إرسالها ما لم يتغير
    // أي مستند في المجموعة.
    // ==========================================

    // ✅ التحقق من تغير الإحصائيات قبل emit
    final statsChanged = state is RentalsStreamActive
        ? (state as RentalsStreamActive).statistics != event.statistics
        : state is RentalLoaded
        ? (state as RentalLoaded).stats !=
              Map<String, dynamic>.from(event.statistics)
        : true;

    if (statsChanged) {
      if (state is RentalsStreamActive) {
        final currentState = state as RentalsStreamActive;
        emit(currentState.copyWith(statistics: event.statistics));
      } else if (state is RentalLoaded) {
        final currentState = state as RentalLoaded;
        emit(
          currentState.copyWith(
            stats: Map<String, dynamic>.from(event.statistics),
          ),
        );
      } else if (state is RentalLoading || state is RentalInitial) {
        // ✅ تخزين الإحصائيات مؤقتاً لاستخدامها عند وصول بيانات الإيجارات
        _pendingStats = event.statistics;
      }
    }
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  /// الحصول على اسم تكرار الدفع
  String _getPaymentFrequencyName(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربع سنوي';
      case 'yearly':
        return 'سنوي';
      default:
        return frequency;
    }
  }

  @override
  Future<void> close() {
    _rentalsStreamSubscription?.cancel();
    _rentalsStatsStreamSubscription?.cancel();
    _rentalLogsStreamSubscription?.cancel();
    return super.close();
  }
}
