import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/smart_number_formatter.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../data/models/subscription_type_model.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة تعديل الاشتراك
class EditSubscriptionPage extends StatefulWidget {
  const EditSubscriptionPage({required this.subscription, super.key});

  final SubscriptionEntity subscription;

  @override
  State<EditSubscriptionPage> createState() => _EditSubscriptionPageState();
}

class _EditSubscriptionPageState extends State<EditSubscriptionPage>
    with SaveOperationMixin<EditSubscriptionPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedDuration = 'monthly';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isEndDateManual = false;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // للمدة المخصصة
  final _customDaysController = TextEditingController();
  bool _isCustomDuration = false;
  bool _isPaid = false;
  int _defaultSubscriptionHour = 0;
  int _defaultSubscriptionMinute = 0;
  // أنواع الاشتراكات
  List<SubscriptionTypeEntity> _subscriptionTypes = [];
  String? _selectedSubscriptionTypeId;

  // متغيرات مربع العميل
  final _customerSearchController = TextEditingController();
  CustomerEntity? _selectedCustomer;
  List<CustomerEntity> _customers = [];
  List<CustomerEntity> _filteredCustomers = [];

  // متغيرات الخصم والضرائب
  double _discountAmount = 0.0;
  double _totalTaxAmount = 0.0;
  final List<Map<String, dynamic>> _taxes = [];

  final List<String> _durations = [
    'daily',
    'weekly',
    'monthly',
    'quarterly',
    'yearly',
    'custom',
  ];

  final Map<String, String> _durationLabels = {
    'daily': 'يومي',
    'weekly': 'أسبوعي',
    'monthly': 'شهري',
    'quarterly': 'ربع سنوي',
    'yearly': 'سنوي',
    'custom': 'مخصص',
  };

  // إضافة ضريبة جديدة
  void _addTax() {
    final taxNameController = TextEditingController();
    final taxRateController = TextEditingController();
    final taxAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.add_circle, color: Colors.red, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'إضافة ضريبة جديدة',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: _buildTaxDialogContent(
          taxNameController,
          taxRateController,
          taxAmountController,
        ),
        actionsPadding: EdgeInsets.all(16.w),
        actions: _buildTaxDialogActions(
          dialogContext,
          taxNameController,
          taxRateController,
          taxAmountController,
        ),
      ),
    );
  }

  Widget _buildTaxDialogContent(
    TextEditingController taxNameController,
    TextEditingController taxRateController,
    TextEditingController taxAmountController,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اسم الضريبة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8.h),
          TextFormField(
            controller: taxNameController,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'مثلاً: ضريبة قيمة مضافة',
              hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
              prefixIcon: Icon(Icons.tag, color: Colors.red, size: 22.sp),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'قيمة الضريبة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'النسبة %',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextFormField(
                      controller: taxRateController,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.percent,
                          color: Colors.red,
                          size: 20.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        suffixText: '%',
                        suffixStyle: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getNumberInputFormatter(),
                      ],
                      onChanged: (value) {
                        final rate =
                            double.tryParse(value.replaceAll(',', '')) ?? 0;
                        final basePrice =
                            double.tryParse(
                              _priceController.text.replaceAll(',', ''),
                            ) ??
                            0;
                        final amount = basePrice * (rate / 100);
                        taxAmountController.text = _formattingService
                            .formatNumber(amount);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المبلغ',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextFormField(
                      controller: taxAmountController,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.account_balance,
                          color: Colors.red,
                          size: 20.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _formattingService.getNumberInputFormatter(),
                      ],
                      onChanged: (value) {
                        final amount =
                            double.tryParse(value.replaceAll(',', '')) ?? 0;
                        final basePrice =
                            double.tryParse(
                              _priceController.text.replaceAll(',', ''),
                            ) ??
                            0;
                        if (basePrice > 0) {
                          final rate = (amount / basePrice) * 100;
                          taxRateController.text = rate.toStringAsFixed(1);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTaxDialogActions(
    BuildContext dialogContext,
    TextEditingController taxNameController,
    TextEditingController taxRateController,
    TextEditingController taxAmountController,
  ) {
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                final name = taxNameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الضريبة')),
                  );
                  return;
                }

                final rate =
                    double.tryParse(
                      taxRateController.text.replaceAll(',', ''),
                    ) ??
                    0;
                final amount =
                    double.tryParse(
                      taxAmountController.text.replaceAll(',', ''),
                    ) ??
                    0;

                Navigator.of(dialogContext).pop();

                setState(() {
                  _taxes.add({
                    'name': name,
                    'rate': rate,
                    'amount': amount,
                    'isPercentage': rate > 0,
                  });
                  _calculateTotalTax();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                elevation: 2,
                shadowColor: Colors.red.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, size: 18.sp, color: Colors.white),
                  SizedBox(width: 6.w),
                  Text(
                    'إضافة الضريبة',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // حساب إجمالي الضرائب (تراكمي - ضريبة تلو الأخرى)
  void _calculateTotalTax() {
    if (_taxes.isEmpty) {
      _totalTaxAmount = 0.0;
      return;
    }

    final basePrice =
        double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;

    // حساب تراكمي: كل ضريبة تُطبق على المبلغ بعد الضريبة السابقة
    double currentAmount = basePrice;
    double totalTax = 0.0;

    for (var tax in _taxes) {
      final taxAmount = tax['amount'] as double;
      final isPercentage = tax['isPercentage'] as bool;

      if (isPercentage && tax['rate'] as double > 0) {
        // ضريبة نسبة: تُحسب على المبلغ الحالي
        final rate = tax['rate'] as double;
        final calculatedTax = currentAmount * (rate / 100);
        totalTax += calculatedTax;
        currentAmount += calculatedTax;
      } else {
        // ضريبة مبلغ ثابت: تُضاف مباشرة
        totalTax += taxAmount;
        currentAmount += taxAmount;
      }
    }

    _totalTaxAmount = totalTax;
  }

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadSubscriptionTypes();
    _loadCustomers();
    _loadDefaultSubscriptionTime();
  }

  void _initializeFields() {
    // تعبئة الحقول بالبيانات الحالية
    _nameController.text = widget.subscription.name;
    _typeController.text = widget.subscription.type;
    _priceController.text = _formattingService.formatNumber(
      widget.subscription.price,
    );
    _descriptionController.text = widget.subscription.description ?? '';
    _selectedDuration = widget.subscription.duration;
    _startDate = widget.subscription.startDate;
    _endDate = widget.subscription.endDate;
    _isCustomDuration = widget.subscription.duration == 'custom';
    _isPaid = widget.subscription.isPaid;

    if (_isCustomDuration && widget.subscription.customDays != null) {
      _customDaysController.text = widget.subscription.customDays.toString();
    }

    // تعبئة معلومات الخصم والضرائب
    _discountAmount = widget.subscription.discountAmount;
    if (_discountAmount > 0) {
      _discountController.text = _formattingService.formatNumber(
        _discountAmount,
      );
    }

    _totalTaxAmount = widget.subscription.taxAmount;
    if (widget.subscription.taxes != null &&
        widget.subscription.taxes!.isNotEmpty) {
      _taxes.addAll(widget.subscription.taxes!);
    }

    // تعبئة معلومات العميل إذا كان موجوداً
    if (widget.subscription.customerId != null) {
      _customerSearchController.text = widget.subscription.customerName ?? '';
      // سيتم تحديث _selectedCustomer عند تحميل العملاء
    }
  }

  Future<void> _loadSubscriptionTypes() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final bloc = context.read<SubscriptionBloc>();
        final typesResult = await bloc.repository.getSubscriptionTypes(
          currentUser.email!,
        );

        if (mounted) {
          typesResult.fold(
            (failure) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(failure.message)));
              }
            },
            (types) {
              setState(() {
                _subscriptionTypes = types
                    .where((type) => type.isActive)
                    .toList();

                // البحث عن نوع الاشتراك الحالي
                SubscriptionTypeEntity? currentType;
                try {
                  currentType = _subscriptionTypes.firstWhere(
                    (type) => type.name == widget.subscription.type,
                  );
                } on StateError {
                  currentType = _subscriptionTypes.isNotEmpty
                      ? _subscriptionTypes.first
                      : null;
                }
                _selectedSubscriptionTypeId = currentType?.id;
              });
            },
          );
        }
      }
    } on Exception catch (_) {
      // Handle error silently
    }
  }

  void _loadCustomers() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<CustomerBloc>().add(LoadCustomersEvent(user.email!));
      }
    } on Exception catch (_) {
      // CustomerBloc غير متوفر، يمكن تجاهل هذا الخطأ
    }
  }

  Future<void> _loadDefaultSubscriptionTime() async {
    try {
      final settings = await SettingsService.getSubscriptionSettings();
      if (mounted) {
        setState(() {
          _defaultSubscriptionHour = settings['subscriptionDefaultHour'] ?? 0;
          _defaultSubscriptionMinute =
              settings['subscriptionDefaultMinute'] ?? 0;
        });
      }
    } on Exception {
      // تجاهل الخطأ والاستمرار بالقيم الافتراضية
    }
  }

  void _onSubscriptionTypeSelected(SubscriptionTypeEntity type) {
    setState(() {
      _selectedSubscriptionTypeId = type.id;
      _typeController.text = type.name;
      _priceController.text = _formattingService.formatNumber(type.price);
      _selectedDuration = type.duration;
      _isCustomDuration = type.duration == 'custom';

      if (_isCustomDuration && type.customDays != null) {
        _customDaysController.text = type.customDays.toString();
      } else {
        _customDaysController.clear();
      }

      _calculateDates();
    });
  }

  void _calculateDates() {
    if (_startDate == null) return;

    // حساب تاريخ الانتهاء بناءً على المدة وتاريخ البداية
    DateTime calculatedEndDate;

    switch (_selectedDuration) {
      case 'daily':
        // إضافة يوم واحد
        calculatedEndDate = _startDate!.add(const Duration(days: 1));
        break;
      case 'weekly':
        // إضافة أسبوع (7 أيام)
        calculatedEndDate = _startDate!.add(const Duration(days: 7));
        break;
      case 'monthly':
        // إضافة شهر واحد (حساب دقيق مع معالجة تجاوز الأيام)
        calculatedEndDate = _addMonths(_startDate!, 1);
        break;
      case 'quarterly':
        // إضافة 3 أشهر (حساب دقيق مع معالجة تجاوز الأيام)
        calculatedEndDate = _addMonths(_startDate!, 3);
        break;
      case 'yearly':
        // إضافة سنة واحدة (حساب دقيق مع معالجة تجاوز الأيام)
        calculatedEndDate = _addMonths(_startDate!, 12);
        break;
      case 'custom':
        // إضافة عدد أيام مخصص
        var customDays = 30; // القيمة الافتراضية
        if (_customDaysController.text.isNotEmpty) {
          customDays =
              int.tryParse(_customDaysController.text.replaceAll(',', '')) ??
              30;
        }
        calculatedEndDate = _startDate!.add(Duration(days: customDays));
        break;
      default:
        // افتراضياً: شهر واحد
        calculatedEndDate = _addMonths(_startDate!, 1);
    }

    if (!_isEndDateManual) {
      _endDate = calculatedEndDate;
    }
  }

  /// إضافة عدد من الأشهر مع معالجة تجاوز عدد أيام الشهر
  DateTime _addMonths(DateTime date, int months) {
    // حساب السنة والشهر الجديد
    var newYear = date.year;
    var newMonth = date.month + months;

    // معالجة تجاوز الأشهر (أكثر من 12)
    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear -= 1;
    }

    // الحصول على آخر يوم في الشهر الجديد
    var lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;

    // استخدام اليوم الأصلي أو آخر يوم في الشهر (أيهما أقل)
    var newDay = date.day > lastDayOfNewMonth ? lastDayOfNewMonth : date.day;

    // إنشاء التاريخ الجديد
    return DateTime(
      newYear,
      newMonth,
      newDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _descriptionController.dispose();
    _customDaysController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const SubscriptionDrawer(currentRoute: 'edit_subscription'),
      body: MultiBlocListener(
        listeners: [
          BlocListener<SubscriptionBloc, SubscriptionState>(
            listenWhen: (previous, current) {
              return current is SubscriptionError ||
                  current is SubscriptionOperationSuccess;
            },
            listener: (context, state) {
              if (state is SubscriptionOperationSuccess &&
                  !_operationCompleted) {
                _operationCompleted = true;
                // ✅ شاشة تعديل كاملة: بعد نجاح
                // الحفظ تعود للشاشة السابقة
                completeSaveOperation(
                  successMessage: state.message,
                  navigateBackOnSuccess: true,
                );
              } else if (state is SubscriptionError && !_operationCompleted) {
                _operationCompleted = true;
                failSaveOperation(errorMessage: state.message);
              }
            },
          ),
          BlocListener<CustomerBloc, CustomerState>(
            listener: (context, state) {
              if (state is CustomerLoaded) {
                setState(() {
                  _customers = state.customers;
                  _filteredCustomers = List.from(_customers);

                  // البحث عن العميل الحالي
                  if (widget.subscription.customerId != null) {
                    _selectedCustomer = _customers.firstWhere(
                      (customer) =>
                          customer.id == widget.subscription.customerId,
                      orElse: () => _customers.first,
                    );
                  }
                });
              }
            },
          ),
        ],
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [_buildWelcomeCard(context), _buildFormCard(context)],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
          boxShadow: [
            BoxShadow(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          AssyrianTheme.getLamassuForBackground(
            isDarkBackground: true,
            hasCircularBackground: false,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعديل الاشتراك',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  widget.subscription.name,
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 10,
                    ),
                    color: AssyrianTheme.ivoryWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return const DetailScreenHeader(
      title: 'تعديل الاشتراك',
      subtitle: 'تحديث معلومات الاشتراك',
      icon: Icons.edit,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'معلومات العميل',
            icon: Icons.person,
            children: [_buildCustomerSearchField()],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'معلومات الاشتراك',
            icon: Icons.card_membership,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'اسم الاشتراك *',
                icon: Icons.card_membership,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'اسم الاشتراك مطلوب';
                  }
                  return null;
                },
              ),
              _buildSubscriptionTypeDropdown(),
              _buildTextField(
                controller: _priceController,
                label: 'السعر *',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_formattingService.getPriceInputFormatter()],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'السعر مطلوب';
                  }
                  final cleanValue = value.replaceAll(',', '');
                  if (double.tryParse(cleanValue) == null) {
                    return 'أدخل رقم صحيح';
                  }
                  return null;
                },
                onChanged: (value) {
                  // إعادة حساب الضرائب عند تغيير السعر
                  _calculateTotalTax();
                },
              ),
              // حقل الخصم
              _buildTextField(
                controller: _discountController,
                label: 'الخصم',
                icon: Icons.discount,
                keyboardType: TextInputType.number,
                inputFormatters: [_formattingService.getNumberInputFormatter()],
                onChanged: (value) {
                  final cleanValue =
                      SmartNumberFormatter.convertToEnglishNumbers(
                        value.replaceAll(
                          _formattingService.thousandsSeparator,
                          '',
                        ),
                      );
                  setState(() {
                    _discountAmount = double.tryParse(cleanValue) ?? 0;
                  });
                },
              ),
              SizedBox(height: 16.h),
              // قسم الضرائب المتعددة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الضرائب',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  IconButton(
                    onPressed: _addTax,
                    icon: const Icon(Icons.add_circle),
                    color: Colors.red,
                    tooltip: 'إضافة ضريبة',
                  ),
                ],
              ),
              // عرض قائمة الضرائب
              if (_taxes.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: _taxes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tax = entry.value;
                      final taxName = tax['name'] as String;
                      final taxRate = tax['rate'] as double;
                      final taxAmount = tax['amount'] as double;
                      final isPercentage = tax['isPercentage'] as bool;

                      return ListTile(
                        title: Text(
                          taxName,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isPercentage
                              ? '${_formattingService.formatCurrency(taxAmount)} (${taxRate.toStringAsFixed(1)}%)'
                              : _formattingService.formatCurrency(taxAmount),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _taxes.removeAt(index);
                              _calculateTotalTax();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // عرض إجمالي الضرائب
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الضرائب:',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AssyrianTheme.deepBlue,
                        ),
                      ),
                      Text(
                        _formattingService.formatCurrency(_totalTaxAmount),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    'لا توجد ضرائب مضافة',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                  ),
                ),
              // عرض الملخص
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'السعر الأصلي:',
                      _formattingService.formatCurrency(
                        double.tryParse(
                              _priceController.text.replaceAll(',', ''),
                            ) ??
                            0,
                      ),
                    ),
                    if (_totalTaxAmount > 0) ...[
                      _buildSummaryRow(
                        'إجمالي الضرائب:',
                        _formattingService.formatCurrency(_totalTaxAmount),
                        color: Colors.red,
                      ),
                    ],
                    if (_discountAmount > 0) ...[
                      _buildSummaryRow(
                        'الخصم:',
                        '-${_formattingService.formatCurrency(_discountAmount)}',
                        color: Colors.red,
                      ),
                    ],
                    Divider(color: Colors.grey[400]),
                    _buildSummaryRow(
                      'الإجمالي النهائي:',
                      _formattingService.formatCurrency(
                        (double.tryParse(
                                  _priceController.text.replaceAll(',', ''),
                                ) ??
                                0) +
                            _totalTaxAmount -
                            _discountAmount,
                      ),
                      isBold: true,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: _isPaid,
                onChanged: (value) {
                  setState(() {
                    _isPaid = value ?? false;
                  });
                },
                title: Text(
                  'تم الدفع',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'تفاصيل الاشتراك',
            icon: Icons.date_range,
            children: [
              _buildDurationDropdown(),
              _buildEditableDateField(
                label: 'تاريخ البداية *',
                icon: Icons.calendar_today,
                selectedDate: _startDate,
                onDateSelected: (date) {
                  setState(() {
                    _startDate = date;
                    _calculateDates();
                  });
                },
              ),
              _isEndDateManual
                  ? _buildEditableDateField(
                      label: 'تاريخ النهاية *',
                      icon: Icons.event,
                      selectedDate: _endDate,
                      onDateSelected: (date) {
                        setState(() => _endDate = date);
                      },
                    )
                  : _buildDateField(
                      label: 'تاريخ النهاية (تلقائي)',
                      icon: Icons.event,
                      selectedDate: _endDate,
                      readOnly: true,
                      onTap: () {
                        setState(() => _isEndDateManual = true);
                        _selectDateTime(
                          selectedDate: _endDate,
                          onDateSelected: (date) {
                            setState(() => _endDate = date);
                          },
                        );
                      },
                    ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'وصف إضافي',
            icon: Icons.description,
            children: [
              _buildTextField(
                controller: _descriptionController,
                label: 'الوصف (اختياري)',
                icon: Icons.description,
                maxLines: 3,
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        final isLoading = state is SubscriptionLoading;
        return Row(
          children: [
            Expanded(
              child: LoadingButton(
                text: 'حفظ التعديلات',
                onPressed: _updateSubscription,
                isLoading: isLoading,
                icon: Icons.save,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AssyrianTheme.deepBlue,
                  side: const BorderSide(color: AssyrianTheme.deepBlue),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    bool? enabled,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      validator: validator,
      inputFormatters: inputFormatters,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
        suffixText: suffixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
        ),
        labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      ),
    );
  }

  /// بناء صف الملخص
  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AssyrianTheme.deepBlue,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AssyrianTheme.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'العميل',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _customerSearchController,
          decoration: InputDecoration(
            labelText: 'البحث عن العميل',
            hintText: 'ابحث عن العميل بالاسم أو رقم الهاتف...',
            prefixIcon: const Icon(
              Icons.person,
              color: AssyrianTheme.primaryGold,
            ),
            suffixIcon: _customerSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _customerSearchController.clear();
                        _filteredCustomers = List.from(_customers);
                        _selectedCustomer = null;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AssyrianTheme.primaryGold,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 8.h,
            ),
          ),
          onChanged: (value) {
            setState(() {
              if (value.isEmpty) {
                _filteredCustomers = List.from(_customers);
                _selectedCustomer = null;
              } else {
                _filteredCustomers = _customers
                    .where(
                      (customer) =>
                          customer.name.toLowerCase().contains(
                            value.toLowerCase(),
                          ) ||
                          customer.phone.toLowerCase().contains(
                            value.toLowerCase(),
                          ),
                    )
                    .toList();

                final exactMatch = _filteredCustomers
                    .where(
                      (c) =>
                          c.name.toLowerCase() == value.toLowerCase() ||
                          c.phone.toLowerCase() == value.toLowerCase(),
                    )
                    .firstOrNull;

                if (exactMatch != null) {
                  _selectedCustomer = exactMatch;
                } else {
                  _selectedCustomer = null;
                }
              }
            });
          },
          onTap: () {
            // Handle tap if needed
          },
        ),

        // قائمة المقترحات للعملاء
        if (_filteredCustomers.isNotEmpty &&
            _customerSearchController.text.isNotEmpty &&
            _selectedCustomer == null) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredCustomers.length > 5
                  ? 5
                  : _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    border:
                        index <
                            (_filteredCustomers.length > 5
                                ? 4
                                : _filteredCustomers.length - 1)
                        ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                    title: Text(
                      customer.name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14.sp,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              customer.phone,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 14.sp,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              _formatDebtDisplay(customer.totalDebt),
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: customer.totalDebt > 0
                                    ? Colors.red[700]
                                    : customer.totalDebt < 0
                                    ? Colors.green[700]
                                    : Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCustomer = customer;
                        _customerSearchController.text = customer.name;
                      });
                    },
                  ),
                  ),
                 );
               },
            ),
          ),
        ],

        // إظهار معلومات العميل المحدد
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'معلومات العميل',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  'الاسم: ${_selectedCustomer!.name}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                ),
                Text(
                  'الهاتف: ${_selectedCustomer!.phone}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                ),
                if (_selectedCustomer!.email.isNotEmpty)
                  Text(
                    'البريد: ${_selectedCustomer!.email}',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                  ),
                Text(
                  'الحساب: ${_formatDebtDisplay(_selectedCustomer!.totalDebt)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'نوع الاشتراك *',
            prefixIcon: Icon(
              Icons.category,
              size: 20.sp,
              color: AssyrianTheme.primaryGold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
            ),
            labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 8.h,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSubscriptionTypeId,
              isExpanded: true,
              hint: const Text('اختر نوع الاشتراك'),
              items: _subscriptionTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(type.name, overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${_formattingService.formatCurrency(type.price)} - ${_durationLabels[type.duration] ?? type.duration}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final type = _subscriptionTypes.firstWhere(
                    (t) => t.id == value,
                  );
                  _onSubscriptionTypeSelected(type);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedDuration,
          decoration: InputDecoration(
            labelText: 'المدة *',
            prefixIcon: Icon(
              Icons.schedule,
              size: 20.sp,
              color: AssyrianTheme.primaryGold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
            ),
            labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 8.h,
            ),
          ),
          items: _durations.map((duration) {
            return DropdownMenuItem<String>(
              value: duration,
              child: Text(_durationLabels[duration] ?? duration),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedDuration = value;
                _isCustomDuration = value == 'custom';
                if (!_isCustomDuration) {
                  _customDaysController.clear();
                }
                _calculateDates();
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'المدة مطلوبة';
            }
            return null;
          },
        ),
        if (_isCustomDuration) ...[
          SizedBox(height: 16.h),
          TextFormField(
            controller: _customDaysController,
            keyboardType: TextInputType.number,
            inputFormatters: [_formattingService.getQuantityInputFormatter()],
            decoration: InputDecoration(
              labelText: 'عدد الأيام *',
              prefixIcon: Icon(
                Icons.calendar_today,
                size: 20.sp,
                color: AssyrianTheme.primaryGold,
              ),
              suffixText: 'يوم',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
              ),
              labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
            ),
            onChanged: (value) {
              _calculateDates();
            },
            validator: (value) {
              if (_isCustomDuration) {
                if (value == null || value.isEmpty) {
                  return 'عدد الأيام مطلوب';
                }
                final days = int.tryParse(value.replaceAll(',', ''));
                if (days == null || days <= 0) {
                  return 'أدخل عدد أيام صحيح';
                }
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Future<void> _selectDateTime({
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AssyrianTheme.primaryGold,
            onSurface: AssyrianTheme.deepBlue,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    final currentTime = selectedDate != null
        ? TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute)
        : TimeOfDay(
            hour: _defaultSubscriptionHour,
            minute: _defaultSubscriptionMinute,
          );
    final timePicked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AssyrianTheme.primaryGold,
            onSurface: AssyrianTheme.deepBlue,
          ),
        ),
        child: child!,
      ),
    );
    if (timePicked != null && mounted) {
      onDateSelected(
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          timePicked.hour,
          timePicked.minute,
                    ),
                  
                );
    }
  }

  Widget _buildEditableDateField({
    required String label,
    required IconData icon,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
  }) {
    return InkWell(
      onTap: () => _selectDateTime(
        selectedDate: selectedDate,
        onDateSelected: onDateSelected,
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
          suffixIcon: Icon(
            Icons.edit_calendar,
            size: 18.sp,
            color: AssyrianTheme.primaryGold,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
          ),
          labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        ),
        child: Text(
          selectedDate != null
              ? _formattingService.formatDateTime(selectedDate)
              : 'اضغط لاختيار التاريخ',
          style: TextStyle(
            color: selectedDate != null ? Colors.black87 : Colors.grey[600],
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime? selectedDate,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final field = InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
        suffixIcon: onTap != null
            ? Icon(
                Icons.edit_calendar,
                size: 18.sp,
                color: AssyrianTheme.primaryGold,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
        ),
        labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
        filled: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      ),
      child: Text(
        selectedDate != null
            ? _formattingService.formatDateTime(selectedDate)
            : 'سيتم الحساب تلقائياً',
        style: TextStyle(
          color: selectedDate != null ? Colors.black87 : Colors.grey[600],
          fontSize: 14.sp,
        ),
      ),
    );
    if (onTap == null) return field;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: field,
    );
  }

  Future<void> _updateSubscription() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    if (_selectedSubscriptionTypeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب اختيار نوع الاشتراك'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_startDate == null || _endDate == null) {
      _calculateDates();
    }

    if (_startDate == null || _endDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في حساب التواريخ. يرجى اختيار نوع اشتراك صحيح.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    int? customDays;
    if (_isCustomDuration && _customDaysController.text.isNotEmpty) {
      customDays = int.tryParse(
        _customDaysController.text.trim().replaceAll(',', ''),
      );
    }

    String updatedBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        updatedBy = switchedUser['id'] as String;
      } else {
        updatedBy = currentUser.uid;
      }
    } on Exception catch (_) {
      updatedBy = currentUser.uid;
    }

    // الحصول على نوع الاشتراك المختار لنسخ الميزات
    Map<String, dynamic>? subscriptionFeatures;
    if (widget.subscription.subscriptionTypeId != null &&
        widget.subscription.subscriptionTypeId!.isNotEmpty) {
      try {
        final repository = GetIt.instance<SubscriptionRepository>();
        final typesResult = await repository.getSubscriptionTypes(
          currentUser.email ?? '',
        );

        if (!mounted) return;

        typesResult.fold(
          (failure) {
            // في حالة الخطأ، نحتفظ بالميزات الحالية فقط
          },
          (types) {
            final selectedType = types.firstWhere(
              (type) => type.id == widget.subscription.subscriptionTypeId,
              orElse: () => SubscriptionTypeModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: '',
                description: '',
                price: 0,
                duration: 'monthly',
                features: [],
                isActive: true,
                  ),
                  
                 );

            // تحويل الميزات من List<String> إلى Map<String, dynamic>
            if (selectedType.features.isNotEmpty) {
              subscriptionFeatures = {'items': selectedType.features};
            }
          },
        );
      } on Exception catch (_) {
        // في حالة الخطأ، نحتفظ بالميزات الحالية
      }
    }

    final updatedSubscription = widget.subscription.copyWith(
      name: _nameController.text.trim(),
      type: _typeController.text.trim(),
      price:
          (double.tryParse(_priceController.text.trim().replaceAll(',', '')) ??
              0) +
          _totalTaxAmount -
          _discountAmount,
      duration: _selectedDuration,
      customDays: customDays,
      startDate: _startDate,
      endDate: _endDate,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      features:
          subscriptionFeatures ?? widget.subscription.features, // تحديث الميزات
      // ⚠️ ملاحظة للمبرمجين المستقبليين حول الذرية (Atomicity):
      // ⚠️ لا تستخدم DateTime.now() هنا أبداً — updatedAt
      // الأصلي (من widget.subscription الذي قُرئ من
      // Firestore) هو خط الأساس للقفل التفاؤلي
      // (expectedUpdatedAt) في _onUpdateSubscription.
      // لو استخدمت DateTime.now() لتعذر تطابق القفل
      // مع القيمة المخزنة ففُقدت الحماية. updatedAt
      // الجديد يُكتب من الخادم (FieldValue.serverTimestamp)
      // داخل المعاملة في المستودع.
      updatedAt: widget.subscription.updatedAt,
      updatedBy: updatedBy,
      discountAmount: _discountAmount,
      taxAmount: _totalTaxAmount,
      taxes: _taxes.isNotEmpty ? _taxes : null,
      isPaid: _isPaid,
      subscriptionTypeId:
          widget.subscription.subscriptionTypeId, // الحفاظ على نوع الاشتراك
    );

    if (!mounted) return;

    // الحصول على مرجع لـ SubscriptionBloc قبل العملية غير المتزامنة
    final subscriptionBloc = context.read<SubscriptionBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        subscriptionBloc.add(UpdateSubscriptionEvent(updatedSubscription));
      },
      successMessage: 'تم تحديث الاشتراك بنجاح',
      loadingMessage: 'جاري تحديث الاشتراك...',
    );
  }

  String _formatDebtDisplay(double debt) {
    if (debt > 0) {
      return 'عليه ${_formattingService.formatCurrency(debt)}';
    } else if (debt < 0) {
      return 'له ${_formattingService.formatCurrency(debt.abs())}';
    } else {
      return 'متوازن';
    }
  }
}
