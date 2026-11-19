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
import '../../../../core/widgets/credit_limit_warning_dialog.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة إضافة اشتراك جديد
class CreateSubscriptionPage extends StatefulWidget {
  const CreateSubscriptionPage({super.key});

  @override
  State<CreateSubscriptionPage> createState() => _CreateSubscriptionPageState();
}

class _CreateSubscriptionPageState extends State<CreateSubscriptionPage>
    with SaveOperationMixin {
  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedDuration = 'monthly';
  final DateTime _createdAt = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isStartDateManual = false;
  bool _isEndDateManual = false;

  // للمدة المخصصة
  final _customDaysController = TextEditingController();
  bool _isCustomDuration = false;
  bool _isPaid = false;
  int _defaultSubscriptionHour = 0;
  int _defaultSubscriptionMinute = 0;

  // أنواع الاشتراكات
  List<SubscriptionTypeEntity> _subscriptionTypes = [];
  String? _selectedSubscriptionTypeId; // تغيير من الكائن إلى ID
  bool _isLoadingTypes = false;

  // متغيرات مربع العميل
  final _customerSearchController = TextEditingController();
  CustomerEntity? _selectedCustomer;
  List<CustomerEntity> _customers = [];
  List<CustomerEntity> _filteredCustomers = [];

  // LayerLink و GlobalKey لعرض Overlay مقترحات العميل
  final LayerLink _customerLayerLink = LayerLink();
  final GlobalKey _customerFieldKey = GlobalKey();

  // متغيرات الخصم والضريبة
  double _discountAmount = 0.0;
  double _totalTaxAmount = 0.0; // إجمالي الضرائب
  final List<Map<String, dynamic>> _taxes =
      []; // قائمة الضرائب: [{name, rate, amount, isPercentage}]

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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // حقل اسم الضريبة
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
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[400],
                  ),
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
              // حقل النسبة والمبلغ
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
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
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
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
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
        ),
        actionsPadding: EdgeInsets.all(16.w),
        actions: [
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
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
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
        ],
      ),
    );
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

  // LayerLink و GlobalKey لعرض Overlay مقترحات
  final LayerLink _nameLayerLink = LayerLink();
  final GlobalKey _nameFieldKey = GlobalKey();

  // متغيرات البحث والمقترحات
  List<String> _suggestedNames = [];
  List<String> _allSuggestedNames = [];
  bool _isSearchingNames = false;
  bool _hasSearchedNames = false;
  final FocusNode _nameFocusNode = FocusNode();
  Timer? _nameDebounceTimer;

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

  @override
  void initState() {
    super.initState();
    _startDate = _createdAt;
    _calculateDates();
    _nameController.addListener(_onNameChanged);
    _customDaysController.addListener(() {
      if (_isCustomDuration && mounted) {
        setState(_calculateDates);
      }
    });
    _priceController.addListener(() {
      // إعادة حساب الضرائب عند تغيير السعر
      if (_taxes.isNotEmpty) {
        final basePrice =
            double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
        setState(() {
          // إعادة حساب كل ضريبة نسبة
          for (var tax in _taxes) {
            if (tax['isPercentage'] as bool && tax['rate'] as double > 0) {
              final rate = tax['rate'] as double;
              tax['amount'] = basePrice * (rate / 100);
            }
          }
          _calculateTotalTax();
        });
      }
    });
    _loadSubscriptionTypes();
    _loadDefaultSubscriptionTime();

    // تأجيل تحميل العملاء حتى بعد بناء الـ widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomers();
    });

    // إخفاء المقترحات عند فقدان التركيز
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && mounted) {
        _hideNameSuggestionsOverlay();
      }
    });
  }

  Future<void> _loadSubscriptionTypes() async {
    setState(() {
      _isLoadingTypes = true;
    });

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
              setState(() {
                _isLoadingTypes = false;
              });
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
                    .map(
                      (type) => SubscriptionTypeEntity(
                        id: type.id,
                        name: type.name,
                        description: type.description,
                        price: type.price,
                        duration: type.duration,
                        customDays: type.customDays,
                        features: type.features,
                        isActive: type.isActive,
                        activationQuantity: type.activationQuantity,
                        createdBy: type.createdBy,
                        createdAt: type.createdAt,
                        updatedBy: type.updatedBy,
                        updatedAt: type.updatedAt,
                      ),
                    )
                    .toList();
                _isLoadingTypes = false;
              });
            },
          );
        }
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTypes = false;
        });
      }
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

  String _formatDebtDisplay(double debt) {
    if (debt > 0) {
      return 'عليه ${_formattingService.formatCurrency(debt)}';
    } else if (debt < 0) {
      return 'له ${_formattingService.formatCurrency(debt.abs())}';
    } else {
      return 'متوازن';
    }
  }

  void _onSubscriptionTypeSelected(SubscriptionTypeEntity type) {
    setState(() {
      _selectedSubscriptionTypeId = type.id; // حفظ ID بدلاً من الكائن
      _typeController.text = type.name;
      _priceController.text = _formattingService.formatNumber(type.price);
      _selectedDuration = type.duration;
      _isCustomDuration = type.duration == 'custom';

      if (_isCustomDuration && type.customDays != null) {
        _customDaysController.text = type.customDays.toString();
      } else {
        _customDaysController.clear();
      }

      // حساب تاريخ البداية والانتهاء تلقائياً
      _calculateDates();
    });
  }

  void _calculateDates() {
    _startDate ??= _createdAt;

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
    _hideCustomerSuggestionsOverlay();
    _hideNameSuggestionsOverlay();
    _nameDebounceTimer?.cancel();
    _nameController.dispose();
    _typeController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _taxAmountController.dispose();
    _descriptionController.dispose();
    _customDaysController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  // دوال عرض وإخفاء الاقتراحات باستخدام SuggestionsOverlay
  void _showNameSuggestionsOverlay() {
    if (_suggestedNames.isEmpty || !_nameFocusNode.hasFocus) return;

    SuggestionsOverlay.hide();

    final suggestions = _suggestedNames.map((name) {
      final isExact = name == _nameController.text.trim();
      return SuggestionItem(
        value: name,
        isExactMatch: isExact,
        type: SuggestionType.custom,
      );
    }).toList();

    SuggestionsOverlay.show(
      context: context,
      layerLink: _nameLayerLink,
      anchorKey: _nameFieldKey,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        _nameController.text = value;
        SuggestionsOverlay.hide();
      },
      maxHeight: 100.h,
    );
  }

  void _hideNameSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  void _showCustomerSuggestionsOverlay() {
    if (_filteredCustomers.isEmpty) return;

    final suggestions = _filteredCustomers
        .take(5)
        .map(
          (customer) => customer.toSuggestionItem(
            formatCurrency: _formattingService.formatCurrency,
          ),
        )
        .toList();

    SuggestionsOverlay.show(
      context: context,
      anchorKey: _customerFieldKey,
      layerLink: _customerLayerLink,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        final customer = _filteredCustomers.firstWhere(
          (c) => c.name == value,
          orElse: () => _filteredCustomers.first,
        );
        setState(() {
          _selectedCustomer = customer;
          _customerSearchController.text = customer.name;
        });
      },
      maxHeight: 200.h,
    );
  }

  void _hideCustomerSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  void _onNameChanged() {
    _nameDebounceTimer?.cancel();
    _nameDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      _searchSubscriptionNames,
    );
  }

  Future<void> _searchSubscriptionNames() async {
    final query = _nameController.text.trim();

    // البحث بعد كتابة 3 أحرف على الأقل
    if (query.isEmpty || query.length < 3) {
      if (mounted) {
        setState(() {
          _suggestedNames = [];
          _isSearchingNames = false;
        });
      }
      _hideNameSuggestionsOverlay();
      return;
    }

    // إذا لم يتم البحث من قبل، نحصل على جميع الأسماء
    if (!_hasSearchedNames) {
      if (mounted) {
        setState(() {
          _isSearchingNames = true;
        });
      }

      try {
        final bloc = context.read<SubscriptionBloc>();
        final repository = bloc.repository;

        final result = await repository.searchSubscriptionNames(query: '');

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _allSuggestedNames = [];
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
            }
          },
          (names) {
            if (mounted) {
              setState(() {
                _allSuggestedNames = names;
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
              // تصفية النتائج بناءً على النص المكتوب
              _filterNames(query);
            }
          },
        );
      } on Exception catch (_) {
        if (mounted) {
          setState(() {
            _allSuggestedNames = [];
            _hasSearchedNames = true;
            _isSearchingNames = false;
          });
        }
      }
    } else {
      // تصفية النتائج محلياً
      _filterNames(query);
    }
  }

  void _filterNames(String query) {
    final filtered = _allSuggestedNames
        .where((name) => name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (mounted) {
      setState(() {
        _suggestedNames = filtered;
        _isSearchingNames = false;
      });
      if (filtered.isNotEmpty && _nameFocusNode.hasFocus) {
        _showNameSuggestionsOverlay();
      } else {
        _hideNameSuggestionsOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      drawer: const SubscriptionDrawer(currentRoute: 'add_subscription'),
      body: MultiBlocListener(
        listeners: [
          BlocListener<SubscriptionBloc, SubscriptionState>(
            listenWhen: (previous, current) {
              return current is SubscriptionOperationSuccess ||
                  current is SubscriptionLoaded ||
                  current is SubscriptionError;
            },
            listener: (context, state) {
              if (state is SubscriptionOperationSuccess &&
                  !_operationCompleted) {
                _operationCompleted = true;

                // تحديد الرسالة بناءً على وجود عميل
                var message = state.message;
                if (_selectedCustomer != null) {
                  message = 'تم إنشاء الاشتراك وفاتورة الاشتراك بنجاح';
                }

                // استخدام النظام الجديد لإدارة النجاح
                if (isSaving) {
                  // ✅ شاشة إنشاء كاملة: بعد نجاح
                  // الحفظ تعود للشاشة السابقة
                  completeSaveOperation(
                    successMessage: message,
                    navigateBackOnSuccess: true,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              } else if (state is SubscriptionLoaded &&
                  isSaving &&
                  !_operationCompleted) {
                _operationCompleted = true;

                // تحديد الرسالة بناءً على وجود عميل
                var message = 'تم إنشاء الاشتراك بنجاح';
                if (_selectedCustomer != null) {
                  message = 'تم إنشاء الاشتراك وفاتورة الاشتراك بنجاح';
                }

                // ✅ شاشة إنشاء كاملة: بعد نجاح
                // الحفظ تعود للشاشة السابقة
                completeSaveOperation(
                  successMessage: message,
                  navigateBackOnSuccess: true,
                );
              } else if (state is SubscriptionError && !_operationCompleted) {
                _operationCompleted = true;
                if (isSaving) {
                  failSaveOperation(errorMessage: state.message);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          BlocListener<CustomerBloc, CustomerState>(
            listenWhen: (previous, current) {
              return current is CustomerLoaded;
            },
            listener: (context, state) {
              if (state is CustomerLoaded) {
                _customers = state.customers;
                _filteredCustomers = List.from(_customers);
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
                  'إضافة اشتراك جديد',
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
                  'نظام إدارة الاشتراكات الآشوري',
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
      title: 'إضافة اشتراك جديد',
      subtitle: 'إنشاء اشتراك جديد وإضافته إلى قاعدة البيانات',
      icon: Icons.card_membership,
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
              _buildNameFieldWithSuggestions(),
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
                  // إزالة الفواصل قبل التحقق من صحة الرقم
                  final cleanValue = value.replaceAll(',', '');
                  if (double.tryParse(cleanValue) == null) {
                    return 'أدخل رقم صحيح';
                  }
                  return null;
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
                    color: AssyrianTheme.primaryGold,
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
                          color: Colors.orange,
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
              Builder(
                builder: (context) {
                  final basePrice =
                      double.tryParse(
                        _priceController.text.replaceAll(',', ''),
                      ) ??
                      0;
                  final priceWithTax = basePrice + _totalTaxAmount;
                  final finalPrice = priceWithTax - _discountAmount;
                  return Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          'السعر الأصلي:',
                          _formattingService.formatCurrency(basePrice),
                        ),
                        if (_totalTaxAmount > 0) ...[
                          _buildSummaryRow(
                            'إجمالي الضرائب:',
                            _formattingService.formatCurrency(_totalTaxAmount),
                            color: Colors.orange,
                          ),
                          // عرض تفاصيل كل ضريبة
                          ..._taxes.map((tax) {
                            final taxName = tax['name'] as String;
                            final taxRate = tax['rate'] as double;
                            final taxAmount = tax['amount'] as double;
                            final isPercentage = tax['isPercentage'] as bool;
                            return _buildSummaryRow(
                              '  • $taxName',
                              isPercentage
                                  ? '${_formattingService.formatCurrency(taxAmount)} (${taxRate.toStringAsFixed(1)}%)'
                                  : _formattingService.formatCurrency(
                                      taxAmount,
                                    ),
                              color: Colors.orange.withValues(alpha: 0.8),
                            );
                          }),
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
                          _formattingService.formatCurrency(finalPrice),
                          isBold: true,
                          color: AssyrianTheme.deepBlue,
                        ),
                      ],
                    ),
                  );
                },
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
              _isStartDateManual
                  ? _buildEditableDateField(
                      label: 'تاريخ البداية *',
                      icon: Icons.calendar_today,
                      selectedDate: _startDate,
                      onDateSelected: (date) {
                        setState(() {
                          _startDate = date;
                          _calculateDates();
                        });
                      },
                    )
                  : _buildDateField(
                      label: 'تاريخ البداية (تلقائي)',
                      icon: Icons.calendar_today,
                      selectedDate: _startDate,
                      readOnly: true,
                      onTap: () {
                        setState(() => _isStartDateManual = true);
                        _selectDateTime(
                          selectedDate: _startDate,
                          onDateSelected: (date) {
                            setState(() {
                              _startDate = date;
                              _calculateDates();
                            });
                          },
                        );
                      },
                      tooltip: 'تحديد تاريخ البداية يدوياً',
                    ),
              _isEndDateManual
                  ? _buildEditableDateField(
                      label: 'تاريخ النهاية *',
                      icon: Icons.event,
                      selectedDate: _endDate,
                      onDateSelected: (date) {
                        setState(() {
                          _endDate = date;
                        });
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
                      tooltip: 'تحديد تاريخ النهاية يدوياً',
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
          BlocBuilder<SubscriptionBloc, SubscriptionState>(
            builder: (context, state) {
              final isLoading = state is SubscriptionLoading;
              return Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      text: 'إنشاء الاشتراك',
                      onPressed: isSaving ? null : _createSubscription,
                      isLoading: isSaving,
                      icon: Icons.card_membership,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
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
          ),
        ],
      ),
    );
  }

  Widget _buildNameFieldWithSuggestions() {
    final hasExactMatch =
        _nameController.text.isNotEmpty &&
        _suggestedNames.contains(_nameController.text.trim());

    final hasSuggestions =
        !_isSearchingNames &&
        _nameController.text.isNotEmpty &&
        _suggestedNames.isNotEmpty &&
        _nameFocusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _nameLayerLink,
          child: Container(
            key: _nameFieldKey,
            child: TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: 'اسم الاشتراك *',
                prefixIcon: Icon(
                  Icons.card_membership,
                  size: 20.sp,
                  color: AssyrianTheme.primaryGold,
                ),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20.sp),
                        onPressed: () {
                          _nameController.clear();
                          _hideNameSuggestionsOverlay();
                          setState(() {
                            _suggestedNames = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: hasSuggestions
                      ? BorderRadius.only(
                          topLeft: Radius.circular(8.r),
                          topRight: Radius.circular(8.r),
                        )
                      : BorderRadius.circular(8.r),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: hasSuggestions
                      ? BorderRadius.only(
                          topLeft: Radius.circular(8.r),
                          topRight: Radius.circular(8.r),
                        )
                      : BorderRadius.circular(8.r),
                  borderSide: BorderSide(
                    color: hasExactMatch
                        ? Colors.orange.shade400
                        : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                    width: hasExactMatch ? 1.5 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: hasSuggestions
                      ? BorderRadius.only(
                          topLeft: Radius.circular(8.r),
                          topRight: Radius.circular(8.r),
                        )
                      : BorderRadius.circular(8.r),
                  borderSide: BorderSide(
                    color: hasExactMatch
                        ? Colors.orange.shade400
                        : AssyrianTheme.primaryGold,
                    width: hasExactMatch ? 1.5 : 1,
                  ),
                ),
                labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'اسم الاشتراك مطلوب';
                }
                return null;
              },
            ),
          ),
        ),

        // مؤشر التحميل
        if (_isSearchingNames && _nameController.text.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              children: [
                SizedBox(width: 16.w, height: 16.h, child: LoadingWidget()),
                SizedBox(width: 8.w),
                Text(
                  'جاري البحث...',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

        // تحذير المطابقة التامة
        if (hasExactMatch)
          Container(
            margin: EdgeInsets.only(top: 8.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.orange.shade400, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.orange.shade800,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'تحذير: لا يمكن استخدام هذا الاسم!',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  'يوجد اشتراك بنفس الاسم:',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.orange.shade900,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.orange.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block,
                        size: 14.sp,
                        color: Colors.orange.shade800,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _nameController.text.trim(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
        // رسالة خطأ يدوية إذا لم يتم اختيار نوع
        if (_selectedSubscriptionTypeId == null)
          Padding(
            padding: EdgeInsets.only(top: 8.h, right: 12.w),
            child: Text(
              '',
              style: TextStyle(fontSize: 12.sp, color: Colors.red),
            ),
          ),
        if (_isLoadingTypes)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              children: [
                SizedBox(width: 16.w, height: 16.h, child: LoadingWidget()),
                SizedBox(width: 8.w),
                Text(
                  'جاري تحميل أنواع الاشتراكات...',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        if (_subscriptionTypes.isEmpty && !_isLoadingTypes)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16.sp, color: Colors.orange),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'لا توجد أنواع اشتراكات نشطة. يرجى إضافة نوع اشتراك أولاً.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
                // إعادة حساب تاريخ الانتهاء عند تغيير المدة
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
            ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AssyrianTheme.primaryGold,
              onSurface: AssyrianTheme.deepBlue,
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AssyrianTheme.primaryGold,
              onSurface: AssyrianTheme.deepBlue,
            ),
          ),
          child: child!,
        );
      },
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
            size: 16.sp,
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
    String? tooltip,
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
      ),
      child: Text(
        selectedDate != null
            ? _formattingService.formatDateTime(selectedDate)
            : 'سيتم الحساب تلقائياً',
        style: TextStyle(
          color: selectedDate != null
              ? AssyrianTheme.deepBlue
              : Colors.grey[600],
          fontSize: 14.sp,
        ),
      ),
    );
    if (onTap == null) return field;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: field,
      ),
    );
  }

  Future<void> _createSubscription() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    // التحقق من اختيار نوع الاشتراك
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

    // التحقق من اختيار العميل (اختياري - يمكن إنشاء اشتراك بدون عميل)
    if (_selectedCustomer == null) {
      // عرض تأكيد للمستخدم
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد إنشاء الاشتراك'),
          content: const Text(
            'لم يتم اختيار عميل لهذا الاشتراك.\n'
            'هل تريد المتابعة بدون ربط الاشتراك بعميل محدد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        return;
      }
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

    // التحقق من حساب التفعيلات لنوع الاشتراك
    if (_selectedSubscriptionTypeId != null &&
        _selectedSubscriptionTypeId!.isNotEmpty) {
      final selectedType = _subscriptionTypes.firstWhere(
        (type) => type.id == _selectedSubscriptionTypeId,
        orElse: () => throw Exception('نوع الاشتراك غير موجود'),
      );

      if (selectedType.activationQuantity <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا يوجد تفعيلات متاحة لهذا النوع (${selectedType.name}). يرجى شحن التفعيلات أولاً.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'شحن الآن',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/subscriptions/recharge-activations',
                    arguments: selectedType,
                  );
                },
              ),
            ),
          );
        }
        return;
      }
    }

    // حساب التواريخ إذا لم تكن محسوبة
    if (_startDate == null || _endDate == null) {
      _calculateDates();
    }

    // التحقق من أن التواريخ محسوبة بشكل صحيح
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

    // تحديد عدد الأيام المخصصة إذا كانت المدة مخصصة
    int? customDays;
    if (_isCustomDuration && _customDaysController.text.isNotEmpty) {
      customDays = int.tryParse(
        _customDaysController.text.trim().replaceAll(',', ''),
      );
    }

    // الحصول على UID الخاص بالمستخدم
    String createdBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdBy = switchedUser['id'] as String;
      } else {
        createdBy = currentUser.uid;
      }
    } on Exception catch (_) {
      createdBy = currentUser.uid;
    }

    // حساب الخصم والضرائب
    final basePrice = double.parse(
      _priceController.text.trim().replaceAll(',', ''),
    );
    // الضريبة الإجمالية
    final priceWithTax = basePrice + _totalTaxAmount;
    // الخصم يُطبق بعد الضريبة
    final finalPrice = priceWithTax - _discountAmount;

    // الحصول على نوع الاشتراك المختار لنسخ الميزات
    Map<String, dynamic>? subscriptionFeatures;
    if (_selectedSubscriptionTypeId != null &&
        _selectedSubscriptionTypeId!.isNotEmpty) {
      final selectedType = _subscriptionTypes.firstWhere(
        (type) => type.id == _selectedSubscriptionTypeId,
        orElse: () => SubscriptionTypeEntity(
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
    }

    final subscription = SubscriptionEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      type: _typeController.text.trim(),
      price: finalPrice, // السعر النهائي بعد الضريبة والخصم
      duration: _selectedDuration,
      customDays: customDays,
      status: 'active',
      startDate: _startDate!,
      endDate: _endDate!,
      organizationEmail: currentUser.email!,
      customerId: _selectedCustomer?.id, // ربط العميل
      customerName: _selectedCustomer?.name, // اسم العميل
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      features: subscriptionFeatures, // إضافة الميزات
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
      discountAmount: _discountAmount, // حفظ مبلغ الخصم
      taxAmount: _totalTaxAmount, // حفظ إجمالي الضرائب
      taxes: _taxes, // حفظ قائمة الضرائب التفصيلية
      remainingAmount: finalPrice,
      isPaid: _isPaid,
      subscriptionTypeId: _selectedSubscriptionTypeId, // ربط نوع الاشتراك
    );

    // التحقق من حد الائتمان قبل الحفظ
    if (_selectedCustomer != null) {
      final currentDebt = _selectedCustomer!.totalDebt;
      final creditLimit = _selectedCustomer!.creditLimit ?? 0;
      final subscriptionPrice = subscription.price;
      final newDebt = currentDebt + subscriptionPrice;

      // إذا تجاوز حد الائتمان، عرض تحذير
      if (creditLimit > 0 && newDebt > creditLimit) {
        if (mounted) {
          final shouldContinue = await CreditLimitWarningDialog.show(
            context,
            customerName: _selectedCustomer!.name,
            currentDebt: currentDebt,
            creditLimit: creditLimit,
            invoiceAmount: subscriptionPrice,
            newDebt: newDebt,
          );

          if (!shouldContinue) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تم إلغاء العملية - لم يتم إنشاء الاشتراك',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }
      }
    }

    if (!mounted) return;

    // الحصول على مرجع لـ SubscriptionBloc قبل العملية غير المتزامنة
    final subscriptionBloc = context.read<SubscriptionBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        subscriptionBloc.add(
          CreateSubscriptionEvent(subscription, type: subscription.type),
        );
      },
      successMessage: 'تم إنشاء الاشتراك بنجاح',
      loadingMessage: 'جاري إنشاء الاشتراك...',
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
        CompositedTransformTarget(
          link: _customerLayerLink,
          child: Container(
            key: _customerFieldKey,
            child: TextFormField(
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
                            _hideCustomerSuggestionsOverlay();
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
              ),
              onChanged: (value) {
                setState(() {
                  if (value.isEmpty) {
                    _filteredCustomers = List.from(_customers);
                    _hideCustomerSuggestionsOverlay();
                    _selectedCustomer = null;
                  } else {
                    _filteredCustomers = _customers
                        .where(
                          (customer) =>
                              customer.name.toLowerCase().contains(
                                value.toLowerCase(),
                              ) ||
                              customer.phone.contains(value),
                        )
                        .toList();
                    if (_filteredCustomers.isNotEmpty) {
                      _showCustomerSuggestionsOverlay();
                    } else {
                      _hideCustomerSuggestionsOverlay();
                    }

                    final exactMatch = _filteredCustomers
                        .where(
                          (c) =>
                              c.name.toLowerCase() == value.toLowerCase() ||
                              c.phone.contains(value),
                        )
                        .firstOrNull;

                    if (exactMatch != null) {
                      _selectedCustomer = exactMatch;
                      _hideCustomerSuggestionsOverlay();
                    } else {
                      _selectedCustomer = null;
                    }
                  }
                });
              },
              onTap: () {
                if (_customerSearchController.text.isNotEmpty &&
                    _filteredCustomers.isNotEmpty) {
                  _showCustomerSuggestionsOverlay();
                }
              },
            ),
          ),
        ),

        // إظهار معلومات العميل المحدد
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: _isCustomerExceedingLimit(_selectedCustomer!)
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isCustomerExceedingLimit(_selectedCustomer!)
                    ? Colors.red
                    : Colors.blue,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCustomerExceedingLimit(_selectedCustomer!)
                          ? Icons.warning_amber_rounded
                          : Icons.person,
                      color: _isCustomerExceedingLimit(_selectedCustomer!)
                          ? Colors.red
                          : Colors.blue,
                      size: 16.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'معلومات العميل',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: _isCustomerExceedingLimit(_selectedCustomer!)
                            ? Colors.red
                            : Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  'الاسم: ${_selectedCustomer!.name}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: _isCustomerExceedingLimit(_selectedCustomer!)
                        ? Colors.red[700]
                        : Colors.grey[700],
                  ),
                ),
                Text(
                  'الهاتف: ${_selectedCustomer!.phone}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: _isCustomerExceedingLimit(_selectedCustomer!)
                        ? Colors.red[700]
                        : Colors.grey[700],
                  ),
                ),
                if (_selectedCustomer!.email.isNotEmpty)
                  Text(
                    'البريد: ${_selectedCustomer!.email}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: _isCustomerExceedingLimit(_selectedCustomer!)
                          ? Colors.red[700]
                          : Colors.grey[700],
                    ),
                  ),
                Text(
                  'الحساب: ${_formatDebtDisplay(_selectedCustomer!.totalDebt)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: _isCustomerExceedingLimit(_selectedCustomer!)
                        ? Colors.red[700]
                        : Colors.grey[700],
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

  /// التحقق من تجاوز العميل لحد الدين أو كونه محظوراً
  bool _isCustomerExceedingLimit(CustomerEntity customer) {
    // إذا كان محظوراً
    if (customer.status == 'blocked') {
      return true;
    }

    // إذا كان لديه حد دين وتجاوزه
    if (customer.creditLimit != null && customer.creditLimit! > 0) {
      if (customer.totalDebt > customer.creditLimit!) {
        return true;
      }
    }

    return false;
  }
}
