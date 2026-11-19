import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/credit_limit_warning_dialog.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../domain/entities/rental_entity.dart';
import '../../domain/entities/rental_unit_entity.dart';
import '../bloc/rental_bloc.dart';
import '../bloc/rental_unit_bloc.dart';
import '../bloc/rental_unit_event.dart';
import '../bloc/rental_unit_state.dart';
import '../widgets/rental_drawer.dart';

/// صفحة إنشاء عقد إيجار جديد
class CreateRentalPage extends StatefulWidget {
  const CreateRentalPage({super.key});

  @override
  State<CreateRentalPage> createState() => _CreateRentalPageState();
}

class _CreateRentalPageState extends State<CreateRentalPage>
    with SaveOperationMixin {
  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  final _formKey = GlobalKey<FormState>();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  // Controllers للحقول النصية
  final _itemNameController = TextEditingController();
  final _itemDescriptionController = TextEditingController();
  final _renterNameController = TextEditingController();
  final _renterPhoneController = TextEditingController();
  final _renterEmailController = TextEditingController();
  final _rentalPriceController = TextEditingController();
  final _depositController = TextEditingController();
  final _notesController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedPaymentFrequency;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  // ignore: prefer_final_fields — يتم تعديل هذه القيمة ديناميكياً عند اختيار يوم دفع مختلف من الواجهة
  int _selectedPaymentDay = 1; // يوم الدفع الافتراضي
  // ignore: prefer_final_fields — يتم تعديل هذه القيمة ديناميكياً عند اختيار حالة عقد مختلفة من الواجهة
  String _selectedStatus = 'active'; // حالة العقد الافتراضية
  CustomerEntity? _selectedCustomer;
  // ⚠️ ملاحظة ذرية للمبرمجين المستقبليين (تحقق 2026-10-11):
  // _selectedUnit يُحفظ في العقد (unitId) وتُؤجر الوحدة
  // في نفس runTransaction مع إنشاء العقد داخل المستودع
  // (createRental) — لا تحدث حالة الوحدة بكتابة منفصلة
  // بعد العقد أبداً.
  RentalUnitEntity? _selectedUnit;

  // متغيرات البحث عن العميل
  final _customerSearchController = TextEditingController();
  final _customerLayerLink = LayerLink();
  final _customerFieldKey = GlobalKey();
  List<CustomerEntity> _customers = [];
  List<CustomerEntity> _filteredCustomers = [];

  // متغيرات البحث عن الشيء المؤجر
  final _unitSearchController = TextEditingController();
  List<RentalUnitEntity> _units = [];
  List<RentalUnitEntity> _filteredUnits = [];
  bool _showUnitSuggestions = false;

  // قوائم البيانات
  final List<Map<String, String>> _paymentFrequencies = [
    {'id': 'daily', 'name': 'يومياً'},
    {'id': 'weekly', 'name': 'أسبوعياً'},
    {'id': 'monthly', 'name': 'شهرياً'},
    {'id': 'quarterly', 'name': 'ربع سنوي'},
    {'id': 'yearly', 'name': 'سنوياً'},
    {'id': 'custom', 'name': 'مخصص'},
  ];

  // للمدة المخصصة
  final _customDaysController = TextEditingController();
  bool _isCustomDuration = false;

  @override
  void initState() {
    super.initState();
    _loadRentalUnits();
    _loadCustomers();
    // تعيين القيم الافتراضية
    _selectedPaymentFrequency = 'monthly';
    _selectedStartDate = DateTime.now();
    _calculateDates(); // حساب تاريخ النهاية تلقائياً
    _depositController.text = '0';

    // إضافة listener للمدة المخصصة
    _customDaysController.addListener(() {
      if (_isCustomDuration && mounted) {
        setState(_calculateDates);
      }
    });
  }

  void _loadRentalUnits() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      context.read<RentalUnitBloc>().add(
        StartRentalUnitsStreamEvent(normalizedEmail),
      );
    }
  }

  void _loadCustomers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<CustomerBloc>().add(LoadCustomersEvent(user.email!));
    }
  }

  void _calculateDates() {
    // إذا لم يكن هناك تاريخ بداية، استخدم تاريخ اليوم
    _selectedStartDate ??= DateTime.now();

    // حساب تاريخ الانتهاء بناءً على تكرار الدفع وتاريخ البداية
    DateTime calculatedEndDate;

    switch (_selectedPaymentFrequency) {
      case 'daily':
        calculatedEndDate = _selectedStartDate!.add(const Duration(days: 1));
        break;
      case 'weekly':
        calculatedEndDate = _selectedStartDate!.add(const Duration(days: 7));
        break;
      case 'monthly':
        calculatedEndDate = _addMonths(_selectedStartDate!, 1);
        break;
      case 'quarterly':
        calculatedEndDate = _addMonths(_selectedStartDate!, 3);
        break;
      case 'yearly':
        calculatedEndDate = _addMonths(_selectedStartDate!, 12);
        break;
      case 'custom':
        // إضافة عدد أيام مخصص
        var customDays = 30; // القيمة الافتراضية
        if (_customDaysController.text.isNotEmpty) {
          customDays =
              int.tryParse(_customDaysController.text.replaceAll(',', '')) ??
              30;
        }
        calculatedEndDate = _selectedStartDate!.add(Duration(days: customDays));
        break;
      default:
        calculatedEndDate = _addMonths(_selectedStartDate!, 1);
    }

    _selectedEndDate = calculatedEndDate;
  }

  /// إضافة عدد من الأشهر مع معالجة تجاوز عدد أيام الشهر
  DateTime _addMonths(DateTime date, int months) {
    var newYear = date.year;
    var newMonth = date.month + months;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear -= 1;
    }

    var lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    var newDay = date.day > lastDayOfNewMonth ? lastDayOfNewMonth : date.day;

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

  String _formatDebtDisplay(double debt) {
    if (debt > 0) {
      return 'عليه ${_formattingService.formatCurrency(debt)}';
    } else if (debt < 0) {
      return 'له ${_formattingService.formatCurrency(debt.abs())}';
    } else {
      return 'متوازن';
    }
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

  @override
  void dispose() {
    _hideCustomerSuggestionsOverlay();
    _itemNameController.dispose();
    _itemDescriptionController.dispose();
    _renterNameController.dispose();
    _renterPhoneController.dispose();
    _renterEmailController.dispose();
    _rentalPriceController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    _customerSearchController.dispose();
    _unitSearchController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const RentalDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: MultiBlocListener(
        listeners: [
          BlocListener<RentalBloc, RentalState>(
            listenWhen: (previous, current) {
              return current is RentalError ||
                  current is RentalOperationSuccess;
            },
            listener: (context, state) {
              if (state is RentalOperationSuccess && !_operationCompleted) {
                _operationCompleted = true;

                final message = state.message;

                // استخدام النظام الجديد لإدارة النجاح
                if (isSaving) {
                  completeSaveOperation(
                    successMessage: message,
                    onSuccess: () => Navigator.of(context).pop(true),
                  );
                } else {
                  // الطريقة القديمة للحالات الأخرى
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              } else if (state is RentalLoaded &&
                  isSaving &&
                  !_operationCompleted) {
                _operationCompleted = true;

                const message = 'تم إنشاء عقد الإيجار بنجاح';

                completeSaveOperation(
                  successMessage: message,
                  onSuccess: () => Navigator.of(context).pop(true),
                );
              } else if (state is RentalError && !_operationCompleted) {
                _operationCompleted = true;
                // استخدام النظام الجديد لإدارة الأخطاء
                if (isSaving) {
                  failSaveOperation(errorMessage: state.message);
                } else {
                  // الطريقة القديمة للحالات الأخرى
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
          BlocListener<RentalUnitBloc, RentalUnitState>(
            // ملاحظة للمبرمجين المستقبليين: تحديث _units و _filteredUnits عبر مستمع
            // منفصل بدلاً من تعديل الحالة داخل BlocBuilder.builder، لتجنب حالات
            // غير متناسقة وإعادة بناء غير متوقعة.
            listenWhen: (previous, current) => current is RentalUnitLoaded,
            listener: (context, state) {
              if (state is RentalUnitLoaded) {
                setState(() {
                  _units = state.units.where((u) => u.isAvailable).toList();
                  if (_filteredUnits.isEmpty &&
                      _unitSearchController.text.isEmpty) {
                    _filteredUnits = List.from(_units);
                  }
                });
              }
            },
          ),
          BlocListener<CustomerBloc, CustomerState>(
            // ملاحظة للمبرمجين المستقبليين: تحديث _customers و _filteredCustomers عبر مستمع
            // منفصل بدلاً من تعديل الحالة داخل BlocBuilder.builder.
            listenWhen: (previous, current) => current is CustomerLoaded,
            listener: (context, state) {
              if (state is CustomerLoaded) {
                setState(() {
                  _customers = state.customers;
                  if (_filteredCustomers.isEmpty &&
                      _customerSearchController.text.isEmpty) {
                    _filteredCustomers = List.from(_customers);
                  }
                });
              }
            },
          ),
        ],
        child: BlocBuilder<RentalBloc, RentalState>(
          builder: (context, state) {
            final isLoading = state is RentalLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _buildWelcomeCard(context),
                  const SizedBox(height: 6),
                  _buildFormCard(context, isLoading),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
            child: Text(
              'إنشاء عقد إيجار جديد',
              style: AssyrianTheme.titleStyle.copyWith(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 18,
                ),
                color: AssyrianTheme.primaryGold,
              ),
              overflow: TextOverflow.ellipsis,
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
      title: 'إنشاء عقد إيجار جديد',
      subtitle: 'إنشاء عقد إيجار جديد وإضافته إلى قاعدة البيانات',
      icon: Icons.add_business,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUnitSelector(),
          const SizedBox(height: 16),
          _buildCustomerSelector(),
          const SizedBox(height: 16),

          InfoCard(
            title: 'تفاصيل الإيجار',
            icon: Icons.attach_money,
            children: [
              _buildrentalPriceField(),
              _builddepositField(),
              _buildPaymentFrequencyDropdown(),
              _buildStartDateField(),
              _buildEndDateField(),
              _buildNotesField(),
            ],
          ),
          const SizedBox(height: 24),

          _buildActionButtons(isLoading),
        ],
      ),
    );
  }

  Widget _buildUnitSelector() {
    return BlocBuilder<RentalUnitBloc, RentalUnitState>(
      builder: (context, state) {
        // ملاحظة للمبرمجين المستقبليين: تحديث _units يتم عبر BlocListener في MultiBlocListener
        // وليس هنا داخل builder، لتجنب تعديل الحالة أثناء عملية البناء.
        if (state is RentalUnitLoaded && _units.isEmpty) {
          // قراءة أولية فقط عند الحالات الأولى؛ التحديث المستمر يتم عبر المستمع.
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الشيء المؤجر',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AssyrianTheme.deepBlue,
              ),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _unitSearchController,
              decoration: InputDecoration(
                labelText: 'البحث عن شيء أو إدخال اسم جديد *',
                hintText: 'ابحث عن الشيء أو أدخل اسم جديد...',
                prefixIcon: Icon(
                  Icons.category,
                  size: 20.sp,
                  color: AssyrianTheme.primaryGold,
                ),
                suffixIcon: _unitSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20.sp),
                        onPressed: () {
                          setState(() {
                            _unitSearchController.clear();
                            _filteredUnits = List.from(_units);
                            _selectedUnit = null;
                            _showUnitSuggestions = false;
                            _itemNameController.clear();
                            _itemDescriptionController.clear();
                            _rentalPriceController.clear();
                          });
                        },
                      )
                    : null,
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
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
                labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
              ),
              onChanged: (value) {
                setState(() {
                  _itemNameController.text = value;

                  if (value.isEmpty) {
                    _filteredUnits = List.from(_units);
                    _showUnitSuggestions = false;
                    _selectedUnit = null;
                  } else {
                    _filteredUnits = _units
                        .where(
                          (unit) =>
                              unit.itemName.toLowerCase().contains(
                                value.toLowerCase(),
                              ) ||
                              (unit.itemDescription != null &&
                                  unit.itemDescription!.toLowerCase().contains(
                                    value.toLowerCase(),
                                  )) ||
                              (unit.brand != null &&
                                  unit.brand!.toLowerCase().contains(
                                    value.toLowerCase(),
                                  )) ||
                              (unit.model != null &&
                                  unit.model!.toLowerCase().contains(
                                    value.toLowerCase(),
                                  )),
                        )
                        .toList();
                    _showUnitSuggestions = _filteredUnits.isNotEmpty;

                    final exactMatch = _filteredUnits
                        .where(
                          (u) =>
                              u.itemName.toLowerCase() == value.toLowerCase(),
                        )
                        .firstOrNull;

                    if (exactMatch != null) {
                      _selectedUnit = exactMatch;
                      _itemNameController.text = exactMatch.itemName;
                      _itemDescriptionController.text =
                          exactMatch.itemDescription ?? '';
                      _rentalPriceController.text = _formattingService
                          .formatNumber(exactMatch.rentalPrice);
                      _showUnitSuggestions = false;
                    } else {
                      _selectedUnit = null;
                    }
                  }
                });
              },
              onTap: () {
                setState(() {
                  _showUnitSuggestions =
                      _unitSearchController.text.isNotEmpty &&
                      _filteredUnits.isNotEmpty;
                });
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يجب إدخال اسم الشيء المؤجر';
                }
                return null;
              },
            ),

            // قائمة المقترحات للأشياء المؤجرة
            if (_showUnitSuggestions && _filteredUnits.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                constraints: BoxConstraints(maxHeight: 200.h),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8.r),
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
                  itemCount: _filteredUnits.length > 5
                      ? 5
                      : _filteredUnits.length,
                  itemBuilder: (context, index) {
                    final unit = _filteredUnits[index];
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border:
                            index <
                                (_filteredUnits.length > 5
                                    ? 4
                                    : _filteredUnits.length - 1)
                            ? Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              )
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        leading: Icon(
                          _getUnitTypeIcon(unit.itemType),
                          color: AssyrianTheme.primaryGold,
                          size: 24.sp,
                        ),
                        title: Text(
                          unit.itemName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AssyrianTheme.deepBlue,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (unit.itemDescription != null &&
                                unit.itemDescription!.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Text(
                                unit.itemDescription!,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            SizedBox(height: 4.h),
                            Text(
                              _formattingService.formatRentalAmount(
                                unit.rentalPrice,
                              ),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AssyrianTheme.deepBlue,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedUnit = unit;
                            _unitSearchController.text = unit.itemName;
                            _itemNameController.text = unit.itemName;
                            _itemDescriptionController.text =
                                unit.itemDescription ?? '';
                            _rentalPriceController.text = _formattingService
                                .formatNumber(unit.rentalPrice);
                            _showUnitSuggestions = false;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],

            // إظهار معلومات الشيء المحدد
            if (_selectedUnit != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'تم اختيار الشيء',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'الاسم: ${_selectedUnit!.itemName}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (_selectedUnit!.itemDescription != null &&
                        _selectedUnit!.itemDescription!.isNotEmpty)
                      Text(
                        'الوصف: ${_selectedUnit!.itemDescription}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    Text(
                      'السعر: ${_formattingService.formatRentalAmount(_selectedUnit!.rentalPrice)}',
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

            // حقل الوصف إذا لم يتم اختيار شيء من القائمة
            if (_unitSearchController.text.isNotEmpty &&
                _selectedUnit == null) ...[
              SizedBox(height: 12.h),
              TextFormField(
                controller: _itemDescriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'وصف الشيء (اختياري)',
                  hintText: 'أدخل وصف الشيء',
                  prefixIcon: Icon(
                    Icons.description,
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
                    borderSide: const BorderSide(
                      color: AssyrianTheme.primaryGold,
                    ),
                  ),
                  labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  IconData _getUnitTypeIcon(String type) {
    switch (type) {
      case 'car':
        return Icons.directions_car;
      case 'property':
        return Icons.home;
      case 'equipment':
        return Icons.construction;
      case 'furniture':
        return Icons.chair;
      case 'electronics':
        return Icons.devices;
      default:
        return Icons.category;
    }
  }

  Widget _buildCustomerSelector() {
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        // ملاحظة للمبرمجين المستقبليين: تحديث _customers يتم عبر BlocListener في MultiBlocListener
        // وليس هنا داخل builder، لتجنب تعديل الحالة أثناء عملية البناء.

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
                    labelText: 'البحث عن عميل أو إدخال اسم جديد *',
                    hintText: 'ابحث عن العميل أو أدخل اسم جديد...',
                    prefixIcon: Icon(
                      Icons.person,
                      size: 20.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                    suffixIcon: _customerSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20.sp),
                            onPressed: () {
                              setState(() {
                                _customerSearchController.clear();
                                _filteredCustomers = List.from(_customers);
                                _selectedCustomer = null;
                                _renterNameController.clear();
                                _renterPhoneController.clear();
                                _renterEmailController.clear();
                              });
                              _hideCustomerSuggestionsOverlay();
                            },
                          )
                        : null,
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
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _renterNameController.text = value;

                      if (value.isEmpty) {
                        _filteredCustomers = List.from(_customers);
                        _selectedCustomer = null;
                        _hideCustomerSuggestionsOverlay();
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
                          _renterNameController.text = exactMatch.name;
                          _renterPhoneController.text = exactMatch.phone;
                          _renterEmailController.text = exactMatch.email;
                          _hideCustomerSuggestionsOverlay();
                        } else {
                          _selectedCustomer = null;
                          _showCustomerSuggestionsOverlay();
                        }
                      }
                    });
                  },
                  onTap: () {
                    _showCustomerSuggestionsOverlay();
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يجب إدخال اسم المستأجر';
                    }
                    return null;
                  },
                ),
              ),
            ),

            // إظهار معلومات العميل المحدد
            if (_selectedCustomer != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _isCustomerExceedingLimit(_selectedCustomer!)
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
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

            // حقول إضافية للهاتف والبريد إذا لم يتم اختيار عميل من القائمة
            if (_customerSearchController.text.isNotEmpty &&
                _selectedCustomer == null) ...[
              SizedBox(height: 12.h),
              TextFormField(
                controller: _renterPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'هاتف المستأجر',
                  hintText: 'أدخل رقم هاتف المستأجر',
                  prefixIcon: Icon(
                    Icons.phone,
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
                    borderSide: const BorderSide(
                      color: AssyrianTheme.primaryGold,
                    ),
                  ),
                  labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                ),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _renterEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'بريد المستأجر الإلكتروني',
                  hintText: 'أدخل البريد الإلكتروني للمستأجر',
                  prefixIcon: Icon(
                    Icons.email,
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
                    borderSide: const BorderSide(
                      color: AssyrianTheme.primaryGold,
                    ),
                  ),
                  labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'يجب إدخال بريد إلكتروني صحيح';
                    }
                  }
                  return null;
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildrentalPriceField() {
    return TextFormField(
      controller: _rentalPriceController,
      keyboardType: TextInputType.number,
      inputFormatters: [_formattingService.getPriceInputFormatter()],
      decoration: InputDecoration(
        labelText: 'سعر الإيجار *',
        hintText: 'أدخل مبلغ سعر الإيجار',
        prefixIcon: Icon(
          Icons.attach_money,
          size: 20.sp,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'د.ع',
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
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يجب إدخال مبلغ الإيجار';
        }
        final amount = double.tryParse(value.replaceAll(',', ''));
        if (amount == null) {
          return 'يجب إدخال رقم صحيح';
        }
        if (amount <= 0) {
          return 'يجب أن يكون المبلغ أكبر من صفر';
        }
        return null;
      },
    );
  }

  Widget _builddepositField() {
    return TextFormField(
      controller: _depositController,
      keyboardType: TextInputType.number,
      inputFormatters: [_formattingService.getPriceInputFormatter()],
      decoration: InputDecoration(
        labelText: 'التأمين/العربون',
        hintText: 'أدخل مبلغ التأمين/العربون (اختياري)',
        prefixIcon: Icon(
          Icons.security,
          size: 20.sp,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'د.ع',
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
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          final amount = double.tryParse(value.replaceAll(',', ''));
          if (amount == null) {
            return 'يجب إدخال رقم صحيح';
          }
          if (amount < 0) {
            return 'يجب أن يكون المبلغ أكبر من أو يساوي صفر';
          }
        }
        return null;
      },
    );
  }

  Widget _buildPaymentFrequencyDropdown() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue:
              _paymentFrequencies.any(
                (freq) => freq['id'] == _selectedPaymentFrequency,
              )
              ? _selectedPaymentFrequency
              : null,
          decoration: InputDecoration(
            labelText: 'تكرار الدفع *',
            hintText: 'اختر تكرار الدفع',
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
          items: _paymentFrequencies
              .map(
                (freq) => DropdownMenuItem<String>(
                  value: freq['id'],
                  child: Text(freq['name']!),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPaymentFrequency = value;
              _isCustomDuration = value == 'custom';
              _calculateDates(); // إعادة حساب تاريخ الانتهاء
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يجب اختيار تكرار الدفع';
            }
            return null;
          },
        ),

        // حقل عدد الأيام المخصص
        if (_isCustomDuration) ...[
          SizedBox(height: 12.h),
          TextFormField(
            controller: _customDaysController,
            keyboardType: TextInputType.number,
            inputFormatters: [_formattingService.getPriceInputFormatter()],
            decoration: InputDecoration(
              labelText: 'عدد الأيام *',
              hintText: 'أدخل عدد الأيام',
              prefixIcon: Icon(
                Icons.calendar_today,
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
            validator: (value) {
              if (_isCustomDuration) {
                if (value == null || value.trim().isEmpty) {
                  return 'يجب إدخال عدد الأيام';
                }
                final days = int.tryParse(value.replaceAll(',', ''));
                if (days == null || days <= 0) {
                  return 'يجب إدخال عدد أيام صحيح';
                }
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStartDateField() {
    return InkWell(
      onTap: () async {
        var picked = await showDatePicker(
          context: context,
          initialDate: _selectedStartDate ?? DateTime.now(),
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
        if (picked != null) {
          setState(() {
            _selectedStartDate = picked;
            _calculateDates(); // إعادة حساب تاريخ الانتهاء
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'تاريخ بداية العقد *',
          prefixIcon: Icon(
            Icons.calendar_today,
            size: 20.sp,
            color: AssyrianTheme.primaryGold,
          ),
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
          _selectedStartDate != null
              ? DateFormat('dd/MM/yyyy').format(_selectedStartDate!)
              : 'اضغط لاختيار التاريخ',
          style: TextStyle(
            color: _selectedStartDate != null
                ? Colors.black87
                : Colors.grey[600],
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildEndDateField() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'تاريخ نهاية العقد (محسوب تلقائياً)',
        prefixIcon: Icon(
          Icons.event,
          size: 20.sp,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: Icon(Icons.lock_outline, size: 16.sp, color: Colors.grey),
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
        filled: true,
        fillColor: Colors.grey[100],
      ),
      child: Text(
        _selectedEndDate != null
            ? DateFormat('dd/MM/yyyy').format(_selectedEndDate!)
            : 'سيتم الحساب تلقائياً',
        style: TextStyle(
          color: _selectedEndDate != null ? Colors.black87 : Colors.grey[600],
          fontSize: 14.sp,
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'ملاحظات',
        hintText: 'أدخل ملاحظات إضافية (اختياري)',
        prefixIcon: Icon(
          Icons.note,
          size: 20.sp,
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
    );
  }

  Widget _buildActionButtons(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: LoadingButton(
            text: 'إنشاء عقد الإيجار',
            onPressed: isSaving ? null : _createRental,
            isLoading: isSaving,
            icon: Icons.add_business,
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
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createRental() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
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

    // الحصول على UID الخاص بالمستخدم
    String createdBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdBy = switchedUser['id'] as String;
      } else {
        createdBy = user.uid;
      }
    } on Exception catch (_) {
      createdBy = user.uid;
    }

    final rental = RentalEntity(
      id: '',
      itemName: _itemNameController.text.trim(),
      itemDescription: _itemDescriptionController.text.trim().isEmpty
          ? null
          : _itemDescriptionController.text.trim(),
      renterName: _renterNameController.text.trim(),
      renterPhone: _renterPhoneController.text.trim().isEmpty
          ? null
          : _renterPhoneController.text.trim(),
      renterEmail: _renterEmailController.text.trim().isEmpty
          ? null
          : _renterEmailController.text.trim(),
      rentalPrice:
          double.tryParse(_rentalPriceController.text.replaceAll(',', '')) ??
          0.0,
      deposit:
          double.tryParse(
            _depositController.text.replaceAll(',', '').isEmpty
                ? '0'
                : _depositController.text.replaceAll(',', ''),
          ) ??
          0.0,
      paymentFrequency: _selectedPaymentFrequency!,
      paymentDay: _selectedPaymentDay,
      startDate: _selectedStartDate!,
      endDate: _selectedEndDate!,
      status: _selectedStatus,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      organizationEmail: user.email!,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name,
      unitId: _selectedUnit?.id,
    );

    // نسجل الموافقة حتى لا يعيد InvoiceBloc رفض الفاتورة الآلية.
    var skipInvoiceCreditCheck = false;

    // التحقق من حد الائتمان قبل الحفظ
    if (_selectedCustomer != null) {
      final currentDebt = _selectedCustomer!.totalDebt;
      final creditLimit = _selectedCustomer!.creditLimit ?? 0;
      final rentalPrice = rental.rentalPrice;
      final newDebt = currentDebt + rentalPrice;

      // إذا تجاوز حد الائتمان، عرض تحذير
      if (creditLimit > 0 && newDebt > creditLimit) {
        if (mounted) {
          final shouldContinue = await CreditLimitWarningDialog.show(
            context,
            customerName: _selectedCustomer!.name,
            currentDebt: currentDebt,
            creditLimit: creditLimit,
            invoiceAmount: rentalPrice,
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
                          'تم إلغاء العملية - لم يتم إنشاء عقد الإيجار',
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
          skipInvoiceCreditCheck = true;
        }
      }
    }

    if (!mounted) return;

    // الحصول على مرجع لـ RentalBloc قبل العملية غير المتزامنة
    final rentalBloc = context.read<RentalBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        rentalBloc.add(
          CreateRentalEvent(
            rental,
            skipInvoiceCreditCheck: skipInvoiceCreditCheck,
          ),
        );
      },
      successMessage: 'تم إنشاء عقد الإيجار بنجاح',
      loadingMessage: 'جاري إنشاء عقد الإيجار...',
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
