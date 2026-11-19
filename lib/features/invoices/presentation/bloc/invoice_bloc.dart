import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/services/pdf/invoice_pdf_automation_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/pdf/pdf_settings_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/services/settings_service.dart';
import 'package:ashur/core/services/push_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/entities/invoice_log_entity.dart';
import '../../domain/entities/invoice_stats_entity.dart';
import '../../domain/entities/invoice_template_entity.dart';
import '../../domain/entities/invoices_page.dart';
import '../../domain/entities/returned_item_entity.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/usecases/add_invoice.dart';
import '../../domain/usecases/delete_invoice.dart';
import '../../domain/usecases/get_invoice_logs.dart';
import '../../domain/usecases/get_invoice_logs_stream.dart';
import '../../domain/usecases/get_invoice_stats.dart';
import '../../domain/usecases/get_invoice_stats_stream.dart';
import '../../domain/usecases/get_invoices.dart';
import '../../domain/usecases/get_invoices_paginated.dart';
import '../../domain/usecases/get_invoices_stream.dart';
import '../../domain/usecases/update_invoice.dart';
import '../../domain/usecases/get_archived_invoices.dart';

part 'invoice_event.dart';
part 'invoice_state.dart';

class InvoiceBloc extends Bloc<InvoiceEvent, InvoiceState> {
  // ============================================================
  // ملاحظة للمبرمجين المستقبليين:
  // العمليات الأساسية للفواتير (إضافة/تحديث/حذف) أصبحت ذرية بالكامل داخل InvoiceRepositoryImpl
  // داخل runTransaction واحد يشمل:
  // - حفظ/تحديث/حذف الفاتورة
  // - تحديث المخزون وسجلات حركة المنتجات
  // - تحديث الصندوق
  // - تحديث دين العميل
  // - إنشاء سجل نشاط الفاتورة
  // ما يبقى غير ذري هو عمليات ما بعد الـ transaction في BLoC:
  // - الإشعارات Push
  // - توليد وإرسال PDF
  // - إعادة تحميل البيانات
  // هذه العمليات تتطلب موارد خارجية ولا يمكن وضعها داخل Firestore transaction.
  // الحل الأمثل لجعلها ذرية هو استخدام Cloud Functions أو queues.

  InvoiceBloc({
    required this.getInvoices,
    required this.getInvoicesPaginated,
    required this.getInvoicesStream,
    required this.getInvoiceStatsStream,
    required this.addInvoice,
    required this.updateInvoice,
    required this.deleteInvoice,
    required this.getInvoiceStats,
    required this.getInvoiceLogs,
    required this.getInvoiceLogsStream,
    required this.getArchivedInvoices,
    required this.repository,
    required this.customerRepository,
    required this.permissionChecker,
  }) : super(InvoiceInitial()) {
    on<LoadInvoicesEvent>(_onLoadInvoices);
    on<LoadInvoicesPaginatedEvent>(_onLoadInvoicesPaginated);
    on<LoadMoreInvoicesEvent>(_onLoadMoreInvoices);
    on<StartInvoicesStreamEvent>(_onStartInvoicesStream);
    on<StopInvoicesStreamEvent>(_onStopInvoicesStream);
    on<StartInvoiceStatsStreamEvent>(_onStartInvoiceStatsStream);
    on<StopInvoiceStatsStreamEvent>(_onStopInvoiceStatsStream);
    on<AddInvoiceEvent>(_onAddInvoice);
    on<UpdateInvoiceEvent>(_onUpdateInvoice);
    on<DeleteInvoiceEvent>(_onDeleteInvoice);
    on<LoadInvoiceStatsEvent>(_onLoadInvoiceStats);
    on<FilterInvoicesEvent>(_onFilterInvoices);
    on<SearchInvoicesEvent>(_onSearchInvoices);
    on<ToggleViewModeEvent>(_onToggleViewMode);
    on<LoadInvoiceLogsEvent>(_onLoadInvoiceLogs);
    on<StartInvoiceLogsStreamEvent>(_onStartInvoiceLogsStream);
    on<StopInvoiceLogsStreamEvent>(_onStopInvoiceLogsStream);
    on<_InvoiceLogsStreamDataReceived>(_onInvoiceLogsStreamDataReceived);
    on<_InvoiceLogsStreamErrorReceived>(_onInvoiceLogsStreamErrorReceived);
    on<_InvoiceStreamDataReceived>(_onInvoiceStreamDataReceived);
    on<_InvoiceStreamErrorReceived>(_onInvoiceStreamErrorReceived);
    on<_InvoiceStatsStreamDataReceived>(_onInvoiceStatsStreamDataReceived);
    on<GenerateInvoicePdfEvent>(_onGenerateInvoicePdf);
    on<LoadInvoiceTemplatesEvent>(_onLoadInvoiceTemplates);
    on<SaveInvoiceTemplateEvent>(_onSaveInvoiceTemplate);
    on<DeleteInvoiceTemplateEvent>(_onDeleteInvoiceTemplate);
    on<LoadArchivedInvoicesEvent>(_onLoadArchivedInvoices);
    on<ExportInvoicesHistoryEvent>(_onExportInvoicesHistory);
  }
  final GetInvoices getInvoices;
  final GetInvoicesPaginated getInvoicesPaginated;
  final GetInvoicesStream getInvoicesStream;
  final GetInvoiceStatsStream getInvoiceStatsStream;
  final AddInvoice addInvoice;
  final UpdateInvoice updateInvoice;
  final DeleteInvoice deleteInvoice;
  final GetInvoiceStats getInvoiceStats;
  final GetInvoiceLogs getInvoiceLogs;
  final GetInvoiceLogsStream getInvoiceLogsStream;
  final GetArchivedInvoices getArchivedInvoices;
  final InvoiceRepository repository;
  final CustomerRepository customerRepository;
  final PermissionChecker permissionChecker;

  /// ✅ ملاحظة للمبرمجين المستقبليين: _isOperating هو قفل خشن (coarse lock)
  /// يمنع التشغيل المزدوج لجميع العمليات في البلوك. هذا يعني أن عملية جارية
  /// تمنع أي عملية أخرى حتى تنكمل. للاستخدام الحالي هذا مقبول، لكن إذا احتاج
  /// النظام لعمليات متوازية مختلفة (مثل تحميل الفواتير والإحصائيات معًا)،
  /// يُنصح باستبداله بقفل منفصل لكل عملية على حدة.
  ///
  /// ⚠️ مشكلة محتملة: إذا فشل أي معالج حدث قبل استدعاء finally، يظل _isOperating = true
  /// مما يمنع جميع العمليات اللاحقة إلى أن يُعاد فتح الصفحة. جميع المعالجات تستخدم
  /// try/finally لضمان إعادة تعيينه، لكن أي استثناء غير ملتقط قد يترك القفل مغلقاً.
  /// ملحوظة إضافية: _onLoadInvoiceStats (السطر 785) لا يتحقق من _isOperating ولا يضبطه،
  /// مما يسمح بتحميل الإحصائيات بشكل متوازٍ مع أي عملية أخرى — هذا غير متسق مع بقية المعالجات.
  bool _isOperating = false;

  // متغيرات للتحكم في الـ streams
  StreamSubscription<dynamic>? _invoicesStreamSubscription;
  StreamSubscription<dynamic>? _statsStreamSubscription;
  StreamSubscription<dynamic>? _invoiceLogsStreamSubscription;
  List<InvoiceEntity> _allInvoices = []; // ✅ حفظ كل الفواتير للفلترة
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isGridView = false;
  DateTime? _startDate; // ✅ فلتر تاريخ البدء للتصفية في الذاكرة كتجميع احتياطي
  DateTime? _endDate; // ✅ فلتر تاريخ الانتهاء للتصفية في الذاكرة كتجميع احتياطي
  InvoiceStatsEntity?
  _pendingStats; // ✅ تخزين الإحصائيات الواصلة قبل بيانات الفواتير

  Future<void> _onLoadInvoices(
    LoadInvoicesEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    emit(InvoiceLoading());
    final result = await getInvoices(event.organizationEmail);
    await result.fold(
      (failure) async => emit(InvoiceError(failure.message)),
      (invoices) async {
        // تحميل الإحصائيات (كل الفواتير)
        final statsResult = await getInvoiceStats(
          GetInvoiceStatsParams(organizationEmail: event.organizationEmail),
        );
        InvoiceStatsEntity? stats;
        // 🔧 ملاحظة للمبرمجين: في حال فشل جلب الإحصائيات، تُكمل العملية
        // وتعرض الفواتير بدون إحصائيات بدلاً من إيقاف toda الصفحة.
        // يمكن تسجيل الخطأ هنا مستقبلاً باستخدام خدمة log.
        statsResult.fold(
          (failure) => stats = null,
          (loadedStats) => stats = loadedStats,
        );

        emit(
          InvoiceLoaded(
            invoices: invoices,
            filteredInvoices: invoices,
            selectedFilter: 'all',
            searchQuery: '',
            stats: stats,
            isGridView: false,
          ),
        );
      },
    );
  }

  /// تحميل الفواتير المؤرشفة فقط لصفحة الأرشيف
  Future<void> _onLoadArchivedInvoices(
    LoadArchivedInvoicesEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    emit(InvoiceLoading());
    final result = await getArchivedInvoices(event.organizationEmail);
      await result.fold(
        (failure) async {
          emit(InvoiceError(failure.message));
        },
      (invoices) {
        emit(
          InvoiceLoaded(
            invoices: invoices,
            filteredInvoices: invoices,
            selectedFilter: 'all',
            searchQuery: '',
            stats: null,
            isGridView: false,
          ),
        );
      },
    );
  }

  Future<void> _onExportInvoicesHistory(
    ExportInvoicesHistoryEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      final result = await getInvoices(event.organizationEmail);
      await result.fold(
        (failure) {
          emit(InvoiceError(failure.message));
        },
        (allInvoices) async {
          // فلترة حسب العميل إذا تم تحديده
          var filtered = allInvoices;
          if (event.customerId != null && event.customerId!.isNotEmpty) {
            filtered = filtered
                .where((inv) => inv.customerId == event.customerId)
                .toList();
          }

          // ترتيب تنازلي حسب تاريخ الإنشاء
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (filtered.isEmpty) {
            emit(
              InvoiceError(
                'لا توجد فواتير للتصدير${event.customerName != null ? ' للعميل ${event.customerName}' : ''}',
              ),
            );
            return;
          }

          // إعداد معلومات المؤسسة من الإعدادات إن توفرّت
          String orgName = event.organizationEmail.split('@').first;
          String orgPhone = '';
          String orgAddress = '';
          Uint8List? logoBytes;

          try {
            final settingsService = PdfSettingsService();
            final settings = await settingsService.getSettings(
              event.organizationEmail,
            );
            orgName = settings.organizationName.isNotEmpty
                ? settings.organizationName
                : orgName;
            orgPhone = settings.organizationPhone;
            orgAddress = settings.organizationAddress;

            // محاولة تحميل شعار المؤسسة من الأصول (مثل فاتورة التفاصيل)
            try {
              final logoData = await rootBundle.load(
                'assets/images/lamassu2.png',
              );
              logoBytes = logoData.buffer.asUint8List();
            } on Exception {
              // تجاهل خطأ قراءة الشعار
            }

            // جلب القالب المحدد
            InvoiceTemplateEntity? template;
            if (event.templateId != null && event.templateId!.isNotEmpty) {
              final templateResult = await repository.getTemplateById(
                event.organizationEmail,
                event.templateId!,
              );
              template = templateResult.fold((failure) => null, (t) => t);
            }

            // إذا لم يتم تحديد قالب، نستخدم القالب الافتراضي حسب النوع
            if (template == null) {
              final templateResult = await repository.getTemplateByType(
                event.organizationEmail,
                'sales',
              );
              template = templateResult.fold((failure) => null, (t) => t);
            }

            // إذا لم يوجد قالب، نستخدم القالب الافتراضي مع عرض الشعار ومعلومات الشركة
            template ??= InvoiceTemplateEntity(
              id: 'template_default',
              name: 'القالب الافتراضي',
              type: 'general',
              headerColor: '#1B365D',
              accentColor: '#D4AF37',
              showLogo: true,
              logoPosition: 'right',
              showCompanyInfo: true,
              showCustomerInfo: true,
              showItemsTable: true,
              showNotes: true,
              showSignature: false,
              footerText: 'شكراً لتعاملكم معنا',
              isDefault: true,
              customFields: {
                'pageMarginTopMM': 0.0,
                'pageMarginBottomMM': 0.0,
                'pageMarginLeftMM': 0.0,
                'pageMarginRightMM': 0.0,
                'titleFontSizeValue': 18.0,
                'subtitleFontSizeValue': 14.0,
                'headerFontSizeValue': 12.0,
                'bodyFontSizeValue': 11.0,
                'footerFontSizeValue': 8.0,
                'tableCellPadding': 6.0,
                'logoWidth': 120.0,
                'logoHeight': 120.0,
                'headerPadding': 20.0,
                'headerBorderRadius': 0.0,
                'companyNameFontSize': 24.0,
                'companyInfoFontSize': 12.0,
                'invoiceTitleFontSize': 20.0,
                'invoiceInfoFontSize': 12.0,
                'customerInfoPadding': 15.0,
                'customerInfoBorderWidth': 2.0,
                'customerInfoBorderRadius': 0.0,
                'customerInfoTitleFontSize': 16.0,
                'customerInfoTextFontSize': 12.0,
                'tableBorderWidth': 1.0,
                'tableHeaderFontSize': 12.0,
                'tableRowFontSize': 10.0,
                'alternateRowColors': true,
                'alternateRowColor': '#F5F5F5',
                'footerPadding': 10.0,
                'footerBorderWidth': 2.0,
                'footerFontSize': 10.0,
                'showBorderAroundTable': true,
                'useRoundCorners': false,
                'useGradientHeader': false,
                'showInvoiceNumberLarge': false,
                'useCardStyleForSections': false,
              },
            );

            // ضمان عرض الشعار عندما يكون متوفراً، حتى لو كان القالب المحدد لا يُظهره
            final bool showLogo = template.showLogo && logoBytes != null;

            final pdfService = PdfService();
            final pdfFile = await pdfService.generateInvoicesHistoryPdf(
              invoices: filtered,
              organizationName: orgName,
              organizationPhone: orgPhone,
              organizationAddress: orgAddress,
              logoBytes: logoBytes,
              template: template.copyWith(showLogo: showLogo),
              customerName: event.customerName,
            );

            emit(InvoiceHistoryExported(pdfFile));
          } on Exception {
            emit(InvoiceError('فشل تصدير سجل الفواتير'));
          }
        },
      );
    } on Exception catch (_) {
      emit(InvoiceError('فشل تصدير سجل الفواتير: حدث خطأ غير متوقع'));
    }
  }

  DocumentSnapshot<Object?>? _lastDocument;
  static const int _pageSize = 20;
  String? _customerId; // معرف العميل الحالي - لا يتغير إلا عند تغيير الصفحة

  Future<void> _onLoadInvoicesPaginated(
    LoadInvoicesPaginatedEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    if (event.customerId != null && event.customerId!.isNotEmpty) {
      _customerId = event.customerId;
    }

    if (event.isRefresh) {
      _lastDocument = null;
      _customerId = event.customerId;
      emit(InvoiceLoading());
    }

    final result = await getInvoicesPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
      customerId: _customerId,
      searchQuery: event.searchQuery,
    );

    await result.fold((failure) async => emit(InvoiceError(failure.message)), (
      page,
    ) async {
      // ✅ تحسين (2026-10-12): مؤشر الصفحة يأتي من
      // نتيجة الاستعلام مباشرة (آخر مستند في الصفحة)
      // بدلاً من جلب المستند مجدداً عبر getInvoiceDocument
      // — كان يضيف جولة شبكة زائدة بعد كل تحميل صفحة.
      if (page.invoices.isNotEmpty) {
        _lastDocument = page.lastDocument;
      }

      emit(
        InvoiceLoaded(
          invoices: page.invoices,
          filteredInvoices: page.invoices,
          selectedFilter: 'all',
          searchQuery: '',
          stats: null,
          isGridView: false,
          hasMore: page.invoices.length >= _pageSize,
          lastDocument: _lastDocument,
        ),
      );
    });
  }

  Future<void> _onLoadMoreInvoices(
    LoadMoreInvoicesEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    final currentState = state;
    if (currentState is! InvoiceLoaded &&
        currentState is! InvoiceStreamActive) {
      return;
    }

    final lastDoc = currentState is InvoiceLoaded
        ? currentState.lastDocument
        : (currentState as InvoiceStreamActive).lastDocument;
    final hasMore = currentState is InvoiceLoaded
        ? currentState.hasMore
        : (currentState as InvoiceStreamActive).hasMore;
    final isLoadingMore = currentState is InvoiceLoaded
        ? currentState.isLoadingMore
        : (currentState as InvoiceStreamActive).isLoadingMore;

    if (!hasMore || isLoadingMore) return;

    if (currentState is InvoiceLoaded) {
      emit(currentState.copyWith(isLoadingMore: true));
    } else {
      final streamState = currentState as InvoiceStreamActive;
      emit(
        InvoiceStreamActive(
          invoices: streamState.invoices,
          filteredInvoices: streamState.filteredInvoices,
          selectedFilter: streamState.selectedFilter,
          searchQuery: streamState.searchQuery,
          isGridView: streamState.isGridView,
          stats: streamState.stats,
          hasMore: streamState.hasMore,
          isLoadingMore: true,
          lastDocument: streamState.lastDocument,
        ),
      );
    }

    final customerId = (event.customerId?.isNotEmpty ?? false)
        ? event.customerId
        : _customerId;

    final result = await getInvoicesPaginated(
      organizationEmail: event.organizationEmail,
      limit: _pageSize,
      lastDocument: lastDoc,
      customerId: customerId,
    );

    await result.fold(
      (failure) async {
        InvoiceState failState;
        if (currentState is InvoiceLoaded) {
          failState = currentState.copyWith(isLoadingMore: false);
        } else {
          final streamState = currentState as InvoiceStreamActive;
          failState = InvoiceStreamActive(
            invoices: streamState.invoices,
            filteredInvoices: streamState.filteredInvoices,
            selectedFilter: streamState.selectedFilter,
            searchQuery: streamState.searchQuery,
            isGridView: streamState.isGridView,
            stats: streamState.stats,
            hasMore: streamState.hasMore,
            isLoadingMore: false,
            lastDocument: streamState.lastDocument,
          );
        }
        // ✅ تم الإصلاح: دمج الخطأ في نفس الحالة المرسلة بدلاً من إرسال
        // failState ثم InvoiceError فوراً، مما يسبب وميض واجهة المستخدم
        // (ظهور رسالة خطأ مع مؤشر تحميل مضلّل). تُرسل InvoiceError فقط
        // دون failState مسبق لتجنب وميض واجهة المستخدم.
        emit(InvoiceError(failure.message));
      },
      (page) async {
        final newInvoices = page.invoices;

        // ✅ تحسين (2026-10-12): مؤشر الصفحة من نتيجة
        // الاستعلام مباشرة بدلاً من جلب المستند مجدداً
        // عبر getInvoiceDocument (جولة شبكة زائدة).
        if (newInvoices.isNotEmpty) {
          _lastDocument = page.lastDocument;
        }

        final currentInvoices = currentState is InvoiceLoaded
            ? currentState.invoices
            : (currentState as InvoiceStreamActive).invoices;
        final allInvoices = [...currentInvoices, ...newInvoices];

        if (currentState is InvoiceLoaded) {
          emit(
            currentState.copyWith(
              invoices: allInvoices,
              filteredInvoices: allInvoices,
              hasMore: newInvoices.length >= _pageSize,
              isLoadingMore: false,
              lastDocument: _lastDocument,
            ),
          );
        } else {
          final streamState = currentState as InvoiceStreamActive;
          emit(
            InvoiceStreamActive(
              invoices: allInvoices,
              filteredInvoices: allInvoices,
              selectedFilter: streamState.selectedFilter,
              searchQuery: streamState.searchQuery,
              isGridView: streamState.isGridView,
              stats: streamState.stats,
              hasMore: newInvoices.length >= _pageSize,
              isLoadingMore: false,
              lastDocument: _lastDocument,
            ),
          );
        }
      },
    );
  }

  Future<void> _onAddInvoice(
    AddInvoiceEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    try {
      // التحقق من حد الائتمان قبل إنشاء الفاتورة
      // يتم فحص جميع أنواع الفواتير التي لها عميل (مبيعات، اشتراك، صيانة، إيجار)
      bool creditLimitExceeded = false;
      if (!event.skipCreditCheck && event.invoice.customerId != null) {
        try {
          // الحصول على بيانات العميل
          // ⚠️ ملاحظة للمبرمجين المستقبليين — استخدام CustomerRepository المحقون عبر المنشئ:
          // هذا يجعل اختبار الوحدة أسهل لأن يمكن محاكاة المستودع بسهولة.
          // تم نقله من GetTo.instance() إلى معامل المنشئ في الإصلاح 2026-10-22.
          final customerResult = await customerRepository.getCustomers(
            event.invoice.organizationEmail,
          );

          await customerResult.fold((failure) async {}, (customers) async {
            try {
              final customer = customers.firstWhere(
                (c) => c.id == event.invoice.customerId,
              );

              final currentDebt = customer.totalDebt;
              final creditLimit = customer.creditLimit ?? 0;
              final additionalAmount = event.invoice.calculateRemainingAmount();
              final newDebt = currentDebt + additionalAmount;

              // إذا تجاوز حد الائتمان، أرسل تحذير وأوقف عملية الإنشاء
              if (creditLimit > 0 && newDebt > creditLimit) {
                creditLimitExceeded = true;
                emit(
                  InvoiceCreditLimitWarning(
                    invoice: event.invoice,
                    customerName: customer.name,
                    currentDebt: currentDebt,
                    creditLimit: creditLimit,
                    newDebt: newDebt,
                  ),
                );
              }
            } on Exception catch (e) {
              // تجاهل الأخطاء في التحقق من حد الائتمان مع تسجيلها للتصحيح
              debugPrint('Credit limit check error: $e');
            }
          });
        } on Exception catch (_) {
          // نستمر في الحفظ حتى لو فشل التحقق
        }
      }

      // إذا تجاوز حد الائتمان، لا تكمل إنشاء الفاتورة
      if (creditLimitExceeded) {
        _isOperating = false;
        return;
      }

      // التحقق من صحة الفاتورة (فقط للفواتير غير النقدية)
      if (event.invoice.type != 'cash') {
        final itemsTotal = event.invoice.items.fold<double>(
          0,
          (total, item) => total + item.totalPrice,
        );
        if ((itemsTotal - event.invoice.totalAmount).abs() > 0.01) {
          emit(InvoiceError('إجمالي الفاتورة لا يساوي مجموع أسعار العناصر'));
          _isOperating = false;
          return;
        }

        if (event.invoice.paidAmount.abs() > event.invoice.totalAmount + 0.01) {
          emit(InvoiceError('المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي'));
          _isOperating = false;
          return;
        }

        final expectedRemaining =
            event.invoice.totalAmount - event.invoice.paidAmount.abs();
        if ((event.invoice.remainingAmount - expectedRemaining).abs() > 0.01) {
          emit(InvoiceError('المبلغ المتبقي غير صحيح'));
          _isOperating = false;
          return;
        }
      } else if (!event.invoice.isCashAccountReceipt) {
        final itemsTotal = event.invoice.items.fold<double>(
          0,
          (total, item) => total + item.totalPrice,
        );
        if ((itemsTotal - event.invoice.totalAmount).abs() > 0.01) {
          emit(InvoiceError('إجمالي الفاتورة لا يساوي مجموع أسعار العناصر'));
          _isOperating = false;
          return;
        }
        if ((event.invoice.paidAmount.abs() - event.invoice.totalAmount).abs() >
            0.01) {
          emit(InvoiceError('البيع النقدي يجب أن يكون مدفوعاً بالكامل'));
          _isOperating = false;
          return;
        }
      } else {
        // ✅ تحقق مبسط لإيصالات الحساب النقدية
        if (event.invoice.paidAmount.abs() >
            event.invoice.totalAmount.abs() + 0.01) {
          emit(
            InvoiceError(
              'المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي في الفاتورة النقدية',
            ),
          );
          _isOperating = false;
          return;
        }
      }

      emit(InvoiceLoading());

      final result = await addInvoice(event.invoice);
      await result.fold(
        (failure) async {
          emit(InvoiceError(failure.message));
        },
        (_) async {
          // ✅ ملاحظة للمبرمجين المستقبليين:
          // العملية الأساسية أصبحت ذرية بالكامل في Repository داخل runTransaction:
          // - حفظ الفاتورة
          // - تحديث المخزون وسجلات حركة المنتجات
          // - تحديث الصندوق
          // - تحديث دين العميل
          // - إنشاء سجل نشاط الفاتورة
          // لكن ما يلي لا يزال غير ذري لأنها تتطلب عمليات خارجية:
          // 1. الإشعارات Push
          // 2. توليد وإرسال PDF
          // 3. إعادة تحميل الفواتير والإحصائيات
          // إذا فشل أي من هذه الخطوات بعد نجاح العملية الأساسية،
          // تظل الفاتورة محفوظة مع بيانات أساسية صحيحة وسجل النشاط مُنشأ،
          // لكن هناك بيانات جانبية مفقودة/قديمة.
          // لجعل العملية ذرية بالكامل، يجب دمج كل ما فوق
          // داخل UseCase/Repository داخل transaction/batch واحد.
          // ⚠️ ملاحظة: الإشعارات والـ PDF تتطلب عمليات خارج Firestore
          // (مثل HTTP requests أو Cloud Functions) ولا يمكن وضعها
          // داخل transaction Firestore. الحل الأمثل هو استخدام
          // Cloud Functions أو queues لضمان التنفيذ الموثوق.

          // إرسال إشعار تنظيمي لبقية المستخدمين في نفس المؤسسة
          final actorEmail = event.invoice.createdBy;

          if (actorEmail.isNotEmpty) {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'invoices',
                  );
              if (isSectionEnabled) {
                if (event.invoice.type == 'cash') {
                  final invoiceCashEnabled =
                      await SettingsService.isNotificationTypeEnabled(
                        'invoice_notify_cash',
                      );
                  final customerCashEnabled =
                      await SettingsService.isNotificationTypeEnabled(
                        'customer_notify_cash_invoice',
                      );
                  if (invoiceCashEnabled || customerCashEnabled) {
                    await PushNotificationService.sendOrganizationNotification(
                      organizationEmail: event.invoice.organizationEmail,
                      title: '💵 فاتورة نقدية (${event.invoice.invoiceNumber})',
                      body:
                          'تم تسجيل فاتورة نقدية للعميل ${event.invoice.customerName} بمبلغ ${event.invoice.totalAmount.toStringAsFixed(0)} د.ع',
                      type: invoiceCashEnabled
                          ? 'invoice_cash'
                          : 'customer_cash_invoice',
                      actorEmail: actorEmail,
                      data: {
                        'invoiceId': event.invoice.id,
                        'invoiceNumber': event.invoice.invoiceNumber,
                      },
                    );
                  }
                } else {
                  final isTypeEnabled =
                      await SettingsService.isNotificationTypeEnabled(
                        'invoice_notify_new',
                      );
                  if (isTypeEnabled) {
                    await PushNotificationService.sendOrganizationNotification(
                      organizationEmail: event.invoice.organizationEmail,
                      title: '📄 فاتورة جديدة (${event.invoice.invoiceNumber})',
                      body:
                          'تم إصدار فاتورة جديدة للعميل ${event.invoice.customerName} بمبلغ إجمالي ${event.invoice.totalAmount.toStringAsFixed(0)} د.ع',
                      type: 'invoice_created',
                      actorEmail: actorEmail,
                      data: {
                        'invoiceId': event.invoice.id,
                        'invoiceNumber': event.invoice.invoiceNumber,
                      },
                    );
                  }
                }
              }
            } on Exception catch (e) {
              debugPrint('Failed to send invoice_created notification: $e');
            }
          }
          // توليد وإرسال PDF تلقائياً للفاتورة
          if (event.invoice.customerPhone.isNotEmpty) {
            try {
              final pdfAutomationService = InvoicePdfAutomationService();
              await pdfAutomationService.generateAndSendInvoicePdf(
                invoice: event.invoice,
                organizationEmail: event.invoice.organizationEmail,
              );
            } on Exception catch (_) {
              // تجاهل أخطاء توليد PDF
            }
          }

          // ✅ ملاحظة للمبرمجين المستقبليين:
          // لا نعيد تحميل الفواتير والإحصائيات يدوياً بعد كل عملية.
          // السبب: إذا كان هناك Stream نشط (StartInvoicesStreamEvent + StartInvoiceStatsStreamEvent)،
          // فإن Stream سيحدث تلقائياً عند أي تغيير في قاعدة البيانات.
          // إعادة التحميل اليدوية تسبب استعلامات إضافية غير ضرورية وتؤدي إلى بطء.
          // نكتفي بإرسال رسالة النجاح فقط، وStream سيقوم بتحديث الواجهة تلقائياً.

          // إرسال رسالة النجاح
          emit(
            InvoiceOperationSuccess(
              'تم إضافة الفاتورة بنجاح',
              invoiceId: event.invoice.id,
              operationType: 'add',
            ),
          );
        },
      );
    } finally {
      _isOperating = false;
    }
  }

  Future<void> _onUpdateInvoice(
    UpdateInvoiceEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    if (_isOperating) {
      return;
    }
    _isOperating = true;
    try {
      emit(InvoiceLoading());

      // التحقق من صحة الفاتورة
      if (event.invoice.type != 'cash') {
        final itemsTotal = event.invoice.items.fold<double>(
          0,
          (total, item) => total + item.totalPrice,
        );
        if ((itemsTotal - event.invoice.totalAmount).abs() > 0.01) {
          emit(InvoiceError('إجمالي الفاتورة لا يساوي مجموع أسعار العناصر'));
          return;
        }

        if (event.invoice.paidAmount.abs() > event.invoice.totalAmount + 0.01) {
          emit(InvoiceError('المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي'));
          return;
        }

        final expectedRemaining =
            event.invoice.totalAmount - event.invoice.paidAmount.abs();
        if ((event.invoice.remainingAmount - expectedRemaining).abs() > 0.01) {
          emit(InvoiceError('المبلغ المتبقي غير صحيح'));
          return;
        }
      } else if (event.invoice.effectiveCashTransactionType == 'sale') {
        final itemsTotal = event.invoice.items.fold<double>(
          0,
          (total, item) => total + item.totalPrice,
        );
        if ((itemsTotal - event.invoice.totalAmount).abs() > 0.01) {
          emit(InvoiceError('إجمالي الفاتورة لا يساوي مجموع أسعار العناصر'));
          return;
        }
        if ((event.invoice.paidAmount.abs() - event.invoice.totalAmount).abs() >
            0.01) {
          emit(InvoiceError('البيع النقدي يجب أن يكون مدفوعاً بالكامل'));
          return;
        }
      } else {
        // ✅ تحقق مبسط للفواتير النقدية
        if (event.invoice.paidAmount.abs() >
            event.invoice.totalAmount.abs() + 0.01) {
          emit(
            InvoiceError(
              'المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي في الفاتورة النقدية',
            ),
          );
          return;
        }
      }

      final result = await updateInvoice(event.invoice);
      await result.fold(
        (failure) async {
          emit(InvoiceError(failure.message));
        },
        (_) async {
          // ✅ ملاحظة للمبرمجين المستقبليين:
          // التحديث الأساسي أصبح ذرياً بالكامل في Repository داخل runTransaction:
          // - عكس تأثير الفاتورة القديمة على المخزون
          // - عكس تأثير الفاتورة القديمة على الصندوق ودين العميل
          // - تطبيق تأثير الفاتورة الجديدة على المخزون
          // - تطبيق تأثير الفاتورة الجديدة على الصندوق ودين العميل
          // - تحديث بيانات الفاتورة
          // - إنشاء سجل نشاط الفاتورة
          // لكن ما يلي لا يزال غير ذري:
          // 1. الإشعارات Push
          // 2. توليد وإرسال PDF
          // 3. إعادة تحميل الفواتير والإحصائيات
          // إذا فشل أي من هذه الخطوات بعد نجاح التحديث الأساسي،
          // تظل الفاتورة محدثة والبيانات الأساسية متسقة وسجل النشاط مُنشأ،
          // لكن هناك بيانات جانبية قد تكون مفقودة/قديمة.
          // لجعل العملية ذرية بالكامل، يجب دمج كل ما فوق
          // داخل UseCase/Repository داخل transaction/batch واحد.
          // ⚠️ ملاحظة: الإشعارات والـ PDF تتطلب عمليات خارج Firestore
          // (مثل HTTP requests أو Cloud Functions) ولا يمكن وضعها
          // داخل transaction Firestore. الحل الأمثل هو استخدام
          // Cloud Functions أو queues لضمان التنفيذ الموثوق.

          final updateActorEmail =
              event.invoice.updatedBy ?? event.invoice.createdBy;
          if (updateActorEmail.isNotEmpty) {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'invoices',
                  );
              final isTypeEnabled =
                  isSectionEnabled &&
                  await SettingsService.isNotificationTypeEnabled(
                    'invoice_notify_updated',
                  );
              if (isTypeEnabled && event.invoice.type != 'cash') {
                await PushNotificationService.sendOrganizationNotification(
                  organizationEmail: event.invoice.organizationEmail,
                  title: '✏️ تعديل فاتورة (${event.invoice.invoiceNumber})',
                  body:
                      'تم تحديث بيانات فاتورة العميل ${event.invoice.customerName}. المتبقي الحالي: ${event.invoice.remainingAmount.toStringAsFixed(0)} د.ع',
                  type: 'invoice_updated',
                  actorEmail: updateActorEmail,
                  data: {'invoiceId': event.invoice.id},
                );
              }

              if (isSectionEnabled && event.invoice.type == 'cash') {
                final invoiceCashEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'invoice_notify_cash',
                    );
                final customerCashEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'customer_notify_cash_invoice',
                    );
                if (invoiceCashEnabled || customerCashEnabled) {
                  await PushNotificationService.sendOrganizationNotification(
                    organizationEmail: event.invoice.organizationEmail,
                    title:
                        '💵 تعديل فاتورة نقدية (${event.invoice.invoiceNumber})',
                    body:
                        'تم تحديث الفاتورة النقدية للعميل ${event.invoice.customerName}.',
                    type: invoiceCashEnabled
                        ? 'invoice_cash'
                        : 'customer_cash_invoice',
                    actorEmail: updateActorEmail,
                    data: {'invoiceId': event.invoice.id},
                  );
                }
              }

              if (isSectionEnabled &&
                  event.invoice.type != 'cash' &&
                  event.invoice.remainingAmount <= 0 &&
                  (event.previousInvoice == null ||
                      event.previousInvoice!.remainingAmount > 0)) {
                final isPaidTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'invoice_notify_paid',
                    );
                if (isPaidTypeEnabled) {
                  await PushNotificationService.sendOrganizationNotification(
                    organizationEmail: event.invoice.organizationEmail,
                    title:
                        '✅ تم سداد الفاتورة بالكامل (${event.invoice.invoiceNumber})',
                    body:
                        'تم سداد فاتورة العميل ${event.invoice.customerName} بالكامل. المبلغ الإجمالي: ${event.invoice.totalAmount.toStringAsFixed(0)} د.ع',
                    type: 'invoice_paid',
                    actorEmail: updateActorEmail,
                    data: {
                      'invoiceId': event.invoice.id,
                      'invoiceNumber': event.invoice.invoiceNumber,
                    },
                  );
                }
              }
            } on Exception catch (e) {
              debugPrint(
                'Failed to send invoice_updated/invoice_paid notification: $e',
              );
            }
          }

          if (event.invoice.customerPhone.isNotEmpty) {
            try {
              final pdfAutomationService = InvoicePdfAutomationService();
              await pdfAutomationService.generateAndSendInvoicePdf(
                invoice: event.invoice,
                organizationEmail: event.invoice.organizationEmail,
              );
            } on Exception catch (_) {
              // تجاهل أخطاء توليد PDF
            }
          }

          // لا نعتمد على وجود stream؛ شاشة التعديل تستخدم Bloc مستقلًا.
          // إرسال حالة النجاح دائماً حتى تتمكن الصفحات السابقة من تحديث بياناتها.
          // إرسال رسالة النجاح
          emit(
            InvoiceOperationSuccess(
              'تم تحديث الفاتورة بنجاح',
              invoiceId: event.invoice.id,
              operationType: 'update',
            ),
          );
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) {
        emit(InvoiceError('حدث خطأ أثناء تحديث الفاتورة'));
      }
    } finally {
      _isOperating = false;
    }
  }

  Future<void> _onDeleteInvoice(
    DeleteInvoiceEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    if (_isOperating) return;
    _isOperating = true;
    // التحقق من الصلاحية باستخدام المحقون عبر المنشئ (الاختبار الأسهل)
    final hasPermission = await permissionChecker.hasPermission(
      'invoices_delete',
    );

    if (!hasPermission) {
      emit(const InvoiceError('ليس لديك صلاحية لحذف الفواتير'));
      return;
    }

    try {
      if (state is InvoiceLoaded) {
        emit(InvoiceLoading());

        final result = await deleteInvoice(event.id, event.organizationEmail);
        await result.fold((failure) async => emit(InvoiceError(failure.message)), (
          _,
        ) async {
          // ✅ ملاحظة للمبرمجين المستقبليين:
          // عملية الحذف أصبحت ذرية بالكامل في Repository داخل runTransaction:
          // - قراءة بيانات الفاتورة
          // - عكس تأثير المخزون
          // - عكس تأثير الصندوق
          // - عكس تأثير دين العميل
          // - إنشاء سجل نشاط الحذف
          // - حذف الفاتورة
          // لكن ما يلي لا يزال غير ذري:
          // 1. الإشعارات Push
          // 2. إعادة تحميل الفواتير والإحصائيات
          // إذا فشل أي من هذه الخطوات بعد نجاح الحذف الأساسي،
          // تظل الفاتورة محذوفة والبيانات الأساسية متسقة وسجل النشاط مُنشأ،
          // لكن هناك بيانات جانبية قد تكون مفقودة/قديمة.
          // لجعل العملية ذرية بالكامل، يجب دمج كل ما فوق
          // داخل UseCase/Repository داخل transaction/batch واحد.
          // ⚠️ ملاحظة: الإشعارات والـ PDF تتطلب عمليات خارج Firestore
          // (مثل HTTP requests أو Cloud Functions) ولا يمكن وضعها
          // داخل transaction Firestore. الحل الأمثل هو استخدام
          // Cloud Functions أو queues لضمان التنفيذ الموثوق.

          final deleteActorEmail = event.deletedInvoice?.createdBy;
          if (deleteActorEmail != null &&
              deleteActorEmail.isNotEmpty &&
              event.deletedInvoice != null) {
            try {
              final isSectionEnabled =
                  await SectionNotificationService.isSectionNotificationsEnabled(
                    'invoices',
                  );
              if (isSectionEnabled) {
                final isTypeEnabled =
                    await SettingsService.isNotificationTypeEnabled(
                      'invoice_notify_deleted',
                    );
                if (isTypeEnabled) {
                  await PushNotificationService.sendOrganizationNotification(
                    organizationEmail: event.organizationEmail,
                    title:
                        '🗑️ حذف فاتورة (${event.deletedInvoice!.invoiceNumber})',
                    body:
                        'تم حذف فاتورة العميل ${event.deletedInvoice!.customerName} بمبلغ ${event.deletedInvoice!.totalAmount.toStringAsFixed(0)} د.ع',
                    type: 'invoice_deleted',
                    actorEmail: deleteActorEmail,
                    data: {'invoiceId': event.id},
                  );
                }
              }
            } on Exception catch (e) {
              debugPrint('Failed to send invoice_deleted notification: $e');
            }
          }

          // ✅ ملاحظة للمبرمجين المستقبليين:
          // لا نعيد تحميل الفواتير والإحصائيات يدوياً بعد كل عملية حذف.
          // السبب: إذا كان هناك Stream نشط (StartInvoicesStreamEvent + StartInvoiceStatsStreamEvent)،
          // فإن Stream سيحدث تلقائياً عند أي تغيير في قاعدة البيانات.
          // إعادة التحميل اليدوية تسبب استعلامات إضافية غير ضرورية وتؤدي إلى بطء.
          // نكتفي بإرسال رسالة النجاح فقط، وStream سيقوم بتحديث الواجهة تلقائياً.

          emit(
            InvoiceOperationSuccess(
              'تم حذف الفاتورة بنجاح',
              invoiceId: event.id,
              operationType: 'delete',
            ),
          );
        });
      }
    } finally {
      _isOperating = false;
    }
  }

  Future<void> _onLoadInvoiceStats(
    LoadInvoiceStatsEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    // ✅ تم الإصلاح: التحقق من قفل _isOperating وضبطه مثل بقية المعالجات
    // لمنع التشغيل المزدوج وضمان الاتساق مع بقية عمليات البلوك.
    if (_isOperating) return;
    _isOperating = true;
    try {
      if (state is InvoiceLoaded) {
        final currentState = state as InvoiceLoaded;
        final result = await getInvoiceStats(
          GetInvoiceStatsParams(
            organizationEmail: event.organizationEmail,
            startDate: event.startDate,
            endDate: event.endDate,
          ),
        );
        result.fold(
          (failure) => emit(currentState.copyWith()),
          (stats) => emit(currentState.copyWith(stats: stats)),
        );
      }
    } finally {
      _isOperating = false;
    }
  }

  void _onFilterInvoices(
    FilterInvoicesEvent event,
    Emitter<InvoiceState> emit,
  ) {
    _selectedFilter = event.filter;

    if (state is InvoiceLoaded) {
      final currentState = state as InvoiceLoaded;
      final filtered = _applyFilters(_allInvoices);

      emit(
        currentState.copyWith(
          filteredInvoices: filtered,
          selectedFilter: event.filter,
        ),
      );
    } else if (state is InvoiceStreamActive) {
      final currentState = state as InvoiceStreamActive;
      final filtered = _applyFilters(_allInvoices);

      emit(
        currentState.copyWith(
          filteredInvoices: filtered,
          selectedFilter: event.filter,
        ),
      );
    }
  }

  void _onSearchInvoices(
    SearchInvoicesEvent event,
    Emitter<InvoiceState> emit,
  ) {
    _searchQuery = event.query;

    if (state is InvoiceLoaded) {
      final currentState = state as InvoiceLoaded;
      final filtered = _applyFilters(_allInvoices);

      emit(
        currentState.copyWith(
          filteredInvoices: filtered,
          searchQuery: event.query,
        ),
      );
    } else if (state is InvoiceStreamActive) {
      final currentState = state as InvoiceStreamActive;
      final filtered = _applyFilters(_allInvoices);

      emit(
        currentState.copyWith(
          filteredInvoices: filtered,
          searchQuery: event.query,
        ),
      );
    }
  }

  void _onToggleViewMode(
    ToggleViewModeEvent event,
    Emitter<InvoiceState> emit,
  ) {
    _isGridView = !_isGridView;

    if (state is InvoiceLoaded) {
      final currentState = state as InvoiceLoaded;
      emit(currentState.copyWith(isGridView: _isGridView));
    } else if (state is InvoiceStreamActive) {
      final currentState = state as InvoiceStreamActive;
      emit(currentState.copyWith(isGridView: _isGridView));
    }
  }

  /// معالج تحميل سجلات الفواتير
  Future<void> _onLoadInvoiceLogs(
    LoadInvoiceLogsEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    emit(InvoiceLoading());

    final params = GetInvoiceLogsParams(
      userId: event.userId,
      searchQuery: event.searchQuery,
      actionFilter: event.actionFilter,
      dateFilter: event.dateFilter,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: event.limit ?? 50,
    );

    final result = await getInvoiceLogs(params);

    result.fold(
      (failure) => emit(InvoiceError(failure.message)),
      (logs) => emit(InvoiceLogsLoaded(logs)),
    );
  }

  /// بدء الاستماع لسجل نشاطات الفواتير مع التحديث الفوري
  Future<void> _onStartInvoiceLogsStream(
    StartInvoiceLogsStreamEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد (تغيير الفلاتر يعيد الاشتراك)
    await _invoiceLogsStreamSubscription?.cancel();

    // ⚠️ ملاحظة للمبرمجين المستقبليين: لا نرسل حالة تحميل عند
    // إعادة بدء الستريم إذا كانت البيانات موجودة لأنها تمزق
    // الواجهة وتغلق الكيبورد — الستريم سيوصل البيانات المحدثة
    final hasExistingData =
        state is InvoiceLogsLoaded ||
        state is InvoiceStreamActive ||
        state is InvoiceLoaded;
    if (!hasExistingData) {
      emit(InvoiceLoading());
    }

    try {
      final stream = getInvoiceLogsStream(
        GetInvoiceLogsParams(
          userId: event.userId,
          searchQuery: event.searchQuery,
          actionFilter: event.actionFilter,
          dateFilter: event.dateFilter,
          startDate: event.startDate,
          endDate: event.endDate,
          limit: event.limit,
        ),
      );

      _invoiceLogsStreamSubscription = stream.listen(
        (result) {
          // إنشاء event جديد بدلاً من emit مباشر
          add(_InvoiceLogsStreamDataReceived(result));
        },
        onError: (error) {
          add(_InvoiceLogsStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(InvoiceError('حدث خطأ غير متوقع'));
    }
  }

  /// إيقاف الاستماع لسجل نشاطات الفواتير
  Future<void> _onStopInvoiceLogsStream(
    StopInvoiceLogsStreamEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    await _invoiceLogsStreamSubscription?.cancel();
    _invoiceLogsStreamSubscription = null;
  }

  /// معالج استلام البيانات من stream سجل النشاطات
  void _onInvoiceLogsStreamDataReceived(
    _InvoiceLogsStreamDataReceived event,
    Emitter<InvoiceState> emit,
  ) {
    event.result.fold(
      (failure) => emit(InvoiceError(failure.message)),
      (logs) => emit(InvoiceLogsLoaded(logs)),
    );
  }

  /// معالج استلام خطأ من stream سجل النشاطات
  void _onInvoiceLogsStreamErrorReceived(
    _InvoiceLogsStreamErrorReceived event,
    Emitter<InvoiceState> emit,
  ) {
    emit(InvoiceError(event.error));
  }

  /// بدء الاستماع للفواتير مع التحديث الفوري
  Future<void> _onStartInvoicesStream(
    StartInvoicesStreamEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _invoicesStreamSubscription?.cancel();

    // ✅ مسح الفواتير المخزنة لمنع ظهور جميع الفواتير لحظةً قبل وصول
    // البيانات المفلترة بالتاريخ من Firebase.
    _allInvoices = [];
    _selectedFilter = 'all';
    _searchQuery = '';
    _startDate = event.startDate;
    _endDate = event.endDate;

    // ⚠️ ملاحظة للمبرمجين المستقبليين: نرسل حالة تحميل دائمًا عند بدء
    // ستريم جديد لضمان عدم عرض بيانات الفواتير القديمة (من عملية تحميل
    // سابقة) قبل وصول البيانات المفلترة بالتاريخ من Firebase.
    emit(InvoiceLoading());

    final hasExistingData =
        state is InvoiceStreamActive || state is InvoiceLoaded;
    if (!hasExistingData) {
      emit(InvoiceLoading());
    }

    try {
      final stream = getInvoicesStream(
        event.organizationEmail,
        limit: event.limit,
        startDate: event.startDate,
        endDate: event.endDate,
        searchQuery: event.searchQuery,
      );

      _invoicesStreamSubscription = stream.listen(
        (result) {
          // إنشاء event جديد بدلاً من emit مباشر
          add(_InvoiceStreamDataReceived(result));
        },
        onError: (error) {
          add(_InvoiceStreamErrorReceived('حدث خطأ غير متوقع'));
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      if (!emit.isDone) emit(InvoiceError('حدث خطأ غير متوقع'));
    }
  }

  /// إيقاف الاستماع للفواتير
  Future<void> _onStopInvoicesStream(
    StopInvoicesStreamEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    await _invoicesStreamSubscription?.cancel();
    _invoicesStreamSubscription = null;
  }

  /// بدء الاستماع لإحصائيات الفواتير مع التحديث الفوري
  Future<void> _onStartInvoiceStatsStream(
    StartInvoiceStatsStreamEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    // إيقاف الاستماع السابق إن وجد
    await _statsStreamSubscription?.cancel();

    try {
      final stream = getInvoiceStatsStream(
        GetInvoiceStatsStreamParams(
          organizationEmail: event.organizationEmail,
          startDate: event.startDate,
          endDate: event.endDate,
          limit: event.limit,
        ),
      );

      _statsStreamSubscription = stream.listen(
        (result) {
          // إنشاء event جديد بدلاً من emit مباشر
          add(_InvoiceStatsStreamDataReceived(result));
        },
        onError: (error) {
          debugPrint('Failed to load invoice stats stream: $error');
        },
        onDone: () {
          // Stream completed
        },
      );
    } on Exception catch (_) {
      // تجاهل الأخطاء
    }
  }

  /// إيقاف الاستماع لإحصائيات الفواتير
  Future<void> _onStopInvoiceStatsStream(
    StopInvoiceStatsStreamEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    await _statsStreamSubscription?.cancel();
    _statsStreamSubscription = null;
  }

  /// تطبيق الفلاتر والبحث على الفواتير
  List<InvoiceEntity> _applyFilters(List<InvoiceEntity> invoices) {
    var filtered = invoices;

    // ✅ تطبيق فلتر التاريخ في الذاكرة كتجميع احتياطي لضمان عدم عرض
    // فواتير خارج النطاق المطلوب حتى لو أرسل Firebase جميع الفواتير.
    if (_startDate != null || _endDate != null) {
      final start = _startDate ?? DateTime(1900);
      final end = _endDate ?? DateTime(2100);
      filtered = filtered.where((invoice) {
        final createdAt = invoice.createdAt;
        return createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
            createdAt.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }

    // تطبيق فلتر الحالة
    if (_selectedFilter != 'all') {
      filtered = filtered.where((invoice) {
        switch (_selectedFilter) {
          case 'paid':
            return invoice.isPaid;
          case 'unpaid':
            return invoice.isUnpaid || invoice.isPartiallyPaid;
          case 'partial':
            return invoice.isPartiallyPaid;
          case 'overdue':
            return invoice.remainingAmount > 0 &&
                (invoice.isUnpaid || invoice.isPartiallyPaid);
          case 'cancelled':
            return invoice.isCancelled;
          default:
            return true;
        }
      }).toList();
    }

    // تطبيق البحث النصي
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final query = _searchQuery.toLowerCase();
        return invoice.customerName.toLowerCase().contains(query) ||
            invoice.invoiceNumber.toLowerCase().contains(query) ||
            invoice.customerPhone.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// معالج استلام البيانات من stream الفواتير
  void _onInvoiceStreamDataReceived(
    _InvoiceStreamDataReceived event,
    Emitter<InvoiceState> emit,
  ) {
    event.result.fold(
      (failure) {
        emit(InvoiceError(failure.message));
      },
      (invoices) {
        // ✅ حفظ كل الفواتير للفلترة الكاملة
        _allInvoices = invoices;

        // ✅ تطبيق الفلاتر مرة واحدة فقط
        final filteredInvoices = _applyFilters(_allInvoices);
        final hasPagination = state is InvoiceLoaded
            ? (state as InvoiceLoaded).lastDocument != null
            : state is InvoiceStreamActive
            ? (state as InvoiceStreamActive).lastDocument != null
            : false;

        if (hasPagination) {
          if (state is InvoiceLoaded) {
            final currentState = state as InvoiceLoaded;
            final currentFiltered = _applyFilters(currentState.invoices);
            final filteredChanged = !listEquals(
              currentFiltered,
              filteredInvoices,
            );

            if (filteredChanged) {
              emit(
                InvoiceStreamActive(
                  invoices: currentState.invoices,
                  filteredInvoices: filteredInvoices,
                  selectedFilter: _selectedFilter,
                  searchQuery: _searchQuery,
                  isGridView: _isGridView,
                  stats: currentState.stats,
                  hasMore: currentState.hasMore,
                  isLoadingMore: currentState.isLoadingMore,
                  lastDocument: currentState.lastDocument,
                ),
              );
            }
          } else if (state is InvoiceStreamActive) {
            final currentState = state as InvoiceStreamActive;
            final filteredChanged = !listEquals(
              currentState.filteredInvoices,
              filteredInvoices,
            );

            if (filteredChanged) {
              emit(currentState.copyWith(filteredInvoices: filteredInvoices));
            }
          }
        } else if (state is InvoiceLoaded) {
          final currentState = state as InvoiceLoaded;

          final invoicesChanged = !listEquals(currentState.invoices, invoices);
          final currentFiltered = _applyFilters(currentState.invoices);
          final filteredChanged = !listEquals(
            currentFiltered,
            filteredInvoices,
          );

          if (invoicesChanged || filteredChanged) {
            emit(
              InvoiceStreamActive(
                invoices: _allInvoices,
                filteredInvoices: filteredInvoices,
                selectedFilter: _selectedFilter,
                searchQuery: _searchQuery,
                isGridView: _isGridView,
                stats: currentState.stats,
              ),
            );
          }
        } else if (state is InvoiceStreamActive) {
          final currentState = state as InvoiceStreamActive;

          final invoicesChanged = !listEquals(currentState.invoices, invoices);
          final filteredChanged = !listEquals(
            currentState.filteredInvoices,
            filteredInvoices,
          );

          if (invoicesChanged || filteredChanged) {
            emit(
              InvoiceStreamActive(
                invoices: _allInvoices,
                filteredInvoices: filteredInvoices,
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
          // لأنه في صفحة الداشبورد، يبدأ stream الإحصائيات
          // وstream الفواتير في نفس الوقت. من المحتمل أن يصل
          // stream الإحصائيات قبل stream الفواتير.
          // إذا لم نستخدم _pendingStats، سنفقد الإحصائيات الواصلة
          // أثناء حالة InvoiceLoading، وسيتم عرض أصفار في النظرة العامة.
          // ==========================================
          emit(
            InvoiceStreamActive(
              invoices: _allInvoices,
              filteredInvoices: filteredInvoices,
              selectedFilter: _selectedFilter,
              searchQuery: _searchQuery,
              isGridView: _isGridView,
              stats: _pendingStats ?? const InvoiceStatsEntity(),
            ),
          );
          _pendingStats = null; // مسح بعد الاستخدام
        }
      },
    );
  }

  /// معالج استلام خطأ من stream الفواتير
  void _onInvoiceStreamErrorReceived(
    _InvoiceStreamErrorReceived event,
    Emitter<InvoiceState> emit,
  ) {
    emit(InvoiceError(event.error));
  }

  /// معالج استلام البيانات من stream الإحصائيات
  void _onInvoiceStatsStreamDataReceived(
    _InvoiceStatsStreamDataReceived event,
    Emitter<InvoiceState> emit,
  ) {
    event.result.fold(
      (failure) {
        // لا نوقف التطبيق بسبب خطأ في الإحصائيات
      },
      (stats) {
        // ===== ملاحظة للمبرمجين المستقبليين =====
        // لماذا نقوم بتخزين الإحصائيات في _pendingStats عندما تكون
        // الحالة InvoiceLoading أو InvoiceInitial؟
        // لأنه في صفحة الداشبورد، يبدأ stream الإحصائيات
        // وstream الفواتير في نفس الوقت. من المحتمل أن يصل
        // stream الإحصائيات قبل stream الفواتير.
        // إذا تجاهلنا الإحصائيات في هذه الحالة، سنفقدها إلى الأبد
        // لأن stream الإحصائيات لن يعيد إرسالها ما لم يتغير
        // أي مستند في المجموعة.
        // ==========================================

        if (state is InvoiceStreamActive) {
          final currentState = state as InvoiceStreamActive;

          // ✅ التحقق من تغير الإحصائيات قبل emit
          final statsChanged = currentState.stats != stats;

          if (statsChanged) {
            emit(currentState.copyWith(stats: stats));
          }
        } else if (state is InvoiceLoaded) {
          final currentState = state as InvoiceLoaded;

          // ✅ التحقق من تغير الإحصائيات قبل emit
          final statsChanged = currentState.stats != stats;

          if (statsChanged) {
            emit(currentState.copyWith(stats: stats));
          }
        } else if (state is InvoiceLoading || state is InvoiceInitial) {
          // ✅ تخزين الإحصائيات مؤقتاً لاستخدامها عند وصول بيانات الفواتير
          _pendingStats = stats;
        }
      },
    );
  }

  // ===== Invoice Template Handlers =====

  final PdfService _pdfService = PdfService();

  /// معالج توليد PDF للفاتورة
  Future<void> _onGenerateInvoicePdf(
    GenerateInvoicePdfEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    try {
      emit(InvoiceLoading());

      InvoiceTemplateEntity? template;

      // إذا تم تحديد قالب، نستخدمه مباشرة
      if (event.templateId != null && event.templateId!.isNotEmpty) {
        final templateResult = await repository.getTemplateById(
          event.organizationEmail,
          event.templateId!,
        );

        template = templateResult.fold((failure) => null, (t) => t);
        // 🔧 ملاحظة: في حال فشل جلب القالب المحدد، يُستخدم القالب الافتراضي
        // بدلاً من إيقاف عملية توليد PDF. يمكن تسجيل الخطأ هنا مستقبلاً.
      }

      // إذا لم يكن هناك قالب محدد، نستخدم القالب الافتراضي حسب النوع
      if (template == null) {
        final templateResult = await repository.getTemplateByType(
          event.organizationEmail,
          event.invoice.type,
        );

        template = templateResult.fold((failure) => null, (t) => t);
        // 🔧 ملاحظة: في حال فشل جلب القالب الافتراضي حسب النوع، سيُستخدم
        // القالب الكلاسيكي الافتراضي فيgenerateInvoicePdf.
      }

      if (template == null) {
        emit(InvoiceError('فشل في تحميل قالب الفاتورة'));
        return;
      }

      // تحميل الشعار
      Uint8List? logoBytes;
      if (template.showLogo) {
        try {
          final data = await rootBundle.load('assets/images/lamassu2.png');
          logoBytes = data.buffer.asUint8List();
        } on Exception catch (_) {
          // تجاهل إذا لم يتم العثور على الشعار
        }
      }

      // جلب اسم المؤسسة من الإعدادات
      String organizationName = 'المؤسسة';
      String organizationPhone = '';
      String organizationAddress = '';
      try {
        final pdfSettingsService = PdfSettingsService();
        final settings = await pdfSettingsService.getSettings(
          event.invoice.organizationEmail,
        );
        organizationName = settings.organizationName;
        organizationPhone = settings.organizationPhone;
        organizationAddress = settings.organizationAddress;
      } on Exception catch (_) {
        // فشل في جلب الإعدادات
      }

      // توليد PDF باستخدام القالب المحدد
      final pdfFile = await _pdfService.generateInvoicePdf(
        invoice: event.invoice,
        template: template,
        organizationName: organizationName,
        organizationPhone: organizationPhone,
        organizationAddress: organizationAddress,
        logoBytes: logoBytes,
      );

      emit(InvoicePdfGenerated(pdfFile));
    } on Exception catch (e) {
      emit(InvoiceError('فشل في توليد PDF: $e'));
    }
  }

  /// معالج تحميل قوالب الفواتير
  Future<void> _onLoadInvoiceTemplates(
    LoadInvoiceTemplatesEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    emit(InvoiceLoading());

    final result = await repository.getInvoiceTemplates(
      event.organizationEmail,
    );

    result.fold(
      (failure) => emit(InvoiceError(failure.message)),
      (templates) => emit(InvoiceTemplatesLoaded(templates)),
    );
  }

  /// معالج حفظ قالب فاتورة
  Future<void> _onSaveInvoiceTemplate(
    SaveInvoiceTemplateEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    emit(InvoiceLoading());

    final result = await repository.saveInvoiceTemplate(
      event.template,
      event.organizationEmail,
    );

    result.fold(
      (failure) => emit(InvoiceError(failure.message)),
      (_) => emit(const InvoiceTemplateSaved()),
    );
  }

  /// معالج حذف قالب فاتورة
  Future<void> _onDeleteInvoiceTemplate(
    DeleteInvoiceTemplateEvent event,
    Emitter<InvoiceState> emit,
  ) async {
    emit(InvoiceLoading());

    final result = await repository.deleteInvoiceTemplate(
      event.templateId,
      event.organizationEmail,
    );

    result.fold(
      (failure) => emit(InvoiceError(failure.message)),
      (_) => emit(const InvoiceTemplateDeleted()),
    );
  }

  @override
  Future<void> close() async {
    await _invoicesStreamSubscription?.cancel();
    await _statsStreamSubscription?.cancel();
    await _invoiceLogsStreamSubscription?.cancel();
    return super.close();
  }
}
