import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cashbox_transaction_entity.dart';
import '../../domain/repositories/report_repository.dart';
import 'cashbox_event.dart';
import 'cashbox_state.dart';

/// Bloc إدارة الصندوق
/// ⚠️ يعمل بستريمات المستودع (getCashboxBalanceStream و
/// getCashboxTransactionsStream) — البيانات تُحدَّث فورياً
/// عند تغير الرصيد أو أي حركة من أي جهاز، ولا حاجة
/// لإعادة الجلب بعد كل عملية (التسجيل/التحديث يُحدَّث
/// تلقائياً عبر الستريم).
class CashboxBloc extends Bloc<CashboxEvent, CashboxState> {
  CashboxBloc({required ReportRepository repository})
    : _repository = repository,
      super(const CashboxInitial()) {
    on<LoadCashboxBalance>(_onLoadBalance);
    on<UpdateCashboxBalance>(_onUpdateBalance);
    on<LoadCashboxTransactions>(_onLoadTransactions);
    on<RecordManualTransaction>(_onRecordManualTransaction);
    on<UpdateCashboxReportPeriod>(_onUpdatePeriod);
  }

  final ReportRepository _repository;

  /// ⚠️ مُعرَّض للحوارات التي تنفذ عمليات ذرية مباشرة
  /// وتنتظر نتيجتها قبل عرض النجاح (نفس نمط
  /// ReportBloc.repository المستخدم في DeleteReportDialog
  /// — انظر حوار الصندوق في cashbox_page.dart)
  ReportRepository get repository => _repository;

  // اشتراكات الستريمات — تُلغى في close()
  StreamSubscription<double>? _balanceSubscription;
  StreamSubscription<List<CashboxTransactionEntity>>?
  _transactionsSubscription;

  // البيانات المُجمَّعة من الستريمات (المصدر الوحيد للحالة)
  String? _organizationEmail;
  double _balance = 0.0;
  List<CashboxTransactionEntity> _allTransactions = [];
  DateTime? _startDate;
  DateTime? _endDate;

  // تقسيم الصفحات — يُطبَّق على البيانات الكاملة
  // من الذاكرة، فتحميل المزيد لا يحتاج جلباً شبكياً
  int _displayPage = 0;
  int _pageSize = 20;

  // بوابات اللقطة الأولى — تمنع إصدار حالة ببيانات
  // ناقصة (رصيد بدون حركات أو العكس) عند التحميل
  // الأولي، خاصة أن صفحة التقرير ترسل حدث الحركات
  // فقط فيُضمن اشتراك الرصيد من _onLoadTransactions
  bool _balanceReady = false;
  bool _transactionsReady = false;

  Future<void> _onLoadBalance(
    LoadCashboxBalance event,
    Emitter<CashboxState> emit,
  ) async {
    await _balanceSubscription?.cancel();

    _balanceReady = false;
    _organizationEmail = event.organizationEmail;

    _balanceSubscription = _repository
        .getCashboxBalanceStream(event.organizationEmail)
        .listen(
      (balance) {
        _balance = balance;
        _balanceReady = true;
        _emitLoaded(emit);
      },
      onError: (Object e) {
        // لا نُعلّق الحركات انتظاراً للرصيد عند الخطأ
        _balanceReady = true;
        if (!isClosed) {
          emit(CashboxError(message: 'فشل في تحميل الحساب'));
        }
      },
    );
  }

  Future<void> _onUpdateBalance(
    UpdateCashboxBalance event,
    Emitter<CashboxState> emit,
  ) async {
    try {
      await _repository.updateCashboxBalance(
        organizationEmail: event.organizationEmail,
        amount: event.amount,
        type: event.type,
        updatedBy: event.updatedBy,
      );

      // ⚠️ لا حاجة لإعادة الجلب — ستريم الرصيد
      // يُحدَّث تلقائياً عند تغير المستند
      // (انظر _onLoadBalance)
      if (!isClosed) {
        emit(const CashboxSuccess(message: 'تم تحديث الحساب بنجاح'));
      }
    } on Exception catch (_) {
      if (!isClosed) {
        emit(CashboxError(message: 'فشل في تحديث الحساب'));
      }
    }
  }

  Future<void> _onLoadTransactions(
    LoadCashboxTransactions event,
    Emitter<CashboxState> emit,
  ) async {
    // تحديث الصفحة المعروضة — التقسيم من الذاكرة
    _displayPage = event.page;
    _pageSize = event.limit;

    // ⚠️ صفحة التقرير ترسل حدث الحركات فقط —
    // نضمن اشتراك الرصيد هنا ليظهر الحساب
    // التراكمي في التقرير (كان يُجلب داخل
    // معالج الحركات سابقاً)
    if (_balanceSubscription == null ||
        _organizationEmail != event.organizationEmail) {
      add(LoadCashboxBalance(organizationEmail: event.organizationEmail));
    }

    // إعادة الاشتراك فقط عند تغير الفترة أو عند
    // أول تحميل — تحميل المزيد (page > 0 بنفس
    // الفترة) يستخدم البيانات الحالية من الذاكرة
    final periodChanged =
        event.startDate != _startDate || event.endDate != _endDate;

    if (_transactionsSubscription == null || periodChanged) {
      await _transactionsSubscription?.cancel();

      _transactionsReady = false;
      _startDate = event.startDate;
      _endDate = event.endDate;

      // الفترة الافتراضية: اليوم (نفس افتراضات
      // getCashboxTransactions)
      final startDate =
          event.startDate ?? DateTime.now().subtract(const Duration(days: 1));
      final endDate = event.endDate ?? DateTime.now();

      _transactionsSubscription = _repository
          .getCashboxTransactionsStream(
            organizationEmail: event.organizationEmail,
            startDate: startDate,
            endDate: endDate,
          )
          .listen(
        (transactions) {
          _allTransactions = transactions;
          _transactionsReady = true;
          _emitLoaded(emit);
        },
        onError: (Object e) {
          // لا نُعلّق الواجهة انتظاراً للحركات عند
          // الخطأ — تصلح البيانات تلقائياً مع
          // اللقطة التالية من الستريم
          _transactionsReady = true;
          if (!isClosed) {
            emit(
              CashboxError(message: 'فشل في تحميل الحركات'),
            );
          }
        },
      );
    } else {
      // تحميل المزيد: إعادة تقسيم الصفحة
      // من البيانات الحالية (فوري بدون شبكة)
      _emitLoaded(emit);
    }
  }

  Future<void> _onRecordManualTransaction(
    RecordManualTransaction event,
    Emitter<CashboxState> emit,
  ) async {
    try {
      await _repository.recordManualTransaction(
        organizationEmail: event.organizationEmail,
        type: event.type,
        amount: event.amount,
        description: event.description,
        createdBy: event.createdBy,
      );

      // ⚠️ لا حاجة لإعادة الجلب — ستريمات الحركات
      // والرصيد تُحدَّث تلقائياً عند تغير
      // المستندات (انظر _onLoadBalance و
      // _onLoadTransactions)
      if (!isClosed) {
        emit(const CashboxSuccess(message: 'تم تسجيل الحركة بنجاح'));
      }
    } on Exception catch (_) {
      if (!isClosed) {
        emit(CashboxError(message: 'فشل في تسجيل الحركة'));
      }
    }
  }

  void _onUpdatePeriod(
    UpdateCashboxReportPeriod event,
    Emitter<CashboxState> emit,
  ) {
    // ⚠️ لا يعمل شيء هنا — تحديث الفترة يتم
    // بإعادة إرسال LoadCashboxTransactions بالفترة
    // الجديدة من الصفحة (يُعيد الاشتراك بالستريم
    // تلقائياً — انظر _onLoadTransactions)
  }

  /// دمج البيانات الحالية في حالة واحدة وإصدارها
  /// ⚠️ تُستدعى عند كل تحديث من أي ستريم — لا
  /// تُصدر حالة تحميل بعد التحميل الأولي لتجنب
  /// وميض شاشة التحميل الكاملة عند كل تحديث
  void _emitLoaded(Emitter<CashboxState> emit) {
    // انتظار اللقطة الأولى من الستريمين قبل
    // أول إصدار (انظر البوابات أعلاه)
    if (!_balanceReady || !_transactionsReady) return;

    // حساب المجاميع من كل الحركات في الفترة
    // ⚠️ كانت تُحسب سابقاً من الصفحات المحملة
    // فقط — الآن من الفترة كاملة لأن الستريم
    // يجلبها كلها (أدق وأكثر صحة)
    double totalIn = 0;
    double totalOut = 0;
    for (final transaction in _allTransactions) {
      if (transaction.type == 'in') {
        totalIn += transaction.amount;
      } else {
        totalOut += transaction.amount;
      }
    }

    // تقسيم الصفحة الحالية من البيانات الكاملة
    // (من الذاكرة — بدون جلب شبكي)
    // ⚠️ خطأ منطقي: يتم أخذ sublist من الفهرس 0 دائمًا، بغض النظر عن _displayPage.
    // هذا يعني أن تحميل المزيد (page > 0) سيعرض نفس الصفحة الأولى repeatedly.
    // يجب أن يكون: final start = offset; final pageTransactions = _allTransactions.sublist(start, clampedEnd);
    final end = (_displayPage + 1) * _pageSize;
    final clampedEnd = end > _allTransactions.length
        ? _allTransactions.length
        : end;
    final pageTransactions = _allTransactions.sublist(0, clampedEnd);

    if (!isClosed) {
      emit(
        CashboxLoaded(
          balance: _balance,
          transactions: pageTransactions,
          totalIn: totalIn,
          totalOut: totalOut,
          totalCount: _allTransactions.length,
          startDate: _startDate,
          endDate: _endDate,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _balanceSubscription?.cancel();
    await _transactionsSubscription?.cancel();
    return super.close();
  }
}
