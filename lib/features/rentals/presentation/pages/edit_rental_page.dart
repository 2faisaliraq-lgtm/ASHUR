import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../domain/entities/rental_entity.dart';
import '../bloc/rental_bloc.dart';
import '../widgets/delete_rental_dialog.dart';
import '../widgets/rental_drawer.dart';

/// صفحة تعديل عقد الإيجار
class EditRentalPage extends StatefulWidget {
  const EditRentalPage({required this.rental, super.key});
  final RentalEntity rental;

  @override
  State<EditRentalPage> createState() => _EditRentalPageState();
}

class _EditRentalPageState extends State<EditRentalPage>
    with SaveOperationMixin<EditRentalPage> {
  final _formKey = GlobalKey<FormState>();
  RentalEntity? _savedRental;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  String? _createdByName;
  String? _updatedByName;

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
  // ⚠️ ملاحظة ذرية للمبرمجين المستقبليين (تحقق 2026-10-11):
  // تغيير حالة العقد (active ↔ غيرها) يُحرر الوحدة أو يُعيد
  // تأجيرها في نفس runTransaction مع تحديث العقد داخل
  // المستودع (updateRental) — لا تُحدّث حالة الوحدة بكتابة
  // منفصلة هنا أبداً (انظر خريطة الذرية في
  // rental_repository_impl.dart).
  String? _selectedRentalStatus;
  String? _selectedPaymentFrequency;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // قوائم البيانات
  final List<Map<String, dynamic>> _rentalStatuses = [
    {'id': 'active', 'name': 'نشط', 'color': Colors.green},
    {'id': 'pending', 'name': 'في الانتظار', 'color': Colors.orange},
    {'id': 'expired', 'name': 'منتهي الصلاحية', 'color': Colors.red},
    {'id': 'terminated', 'name': 'منتهي', 'color': Colors.grey},
  ];

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

  // متغير لتتبع التغييرات
  bool _hasChanges = false;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // متغيرات العميل - للسماح بتغيير العميل المرتبط
  CustomerEntity? _selectedCustomer;
  List<CustomerEntity> _customers = [];
  List<CustomerEntity> _filteredCustomers = [];
  final _customerSearchController = TextEditingController();
  final LayerLink _customerLayerLink = LayerLink();
  final GlobalKey _customerFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _setupChangeListeners();
    _loadCustomers();
    _loadUserNames();

    // إضافة listener للمدة المخصصة
    _customDaysController.addListener(() {
      if (_isCustomDuration && mounted) {
        setState(_calculateDates);
      }
    });
  }

  void _loadCustomers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<CustomerBloc>().add(LoadCustomersEvent(user.email!));
    }
  }

  void _initializeFields() {
    _itemNameController.text = widget.rental.itemName;
    _itemDescriptionController.text = widget.rental.itemDescription ?? '';
    _renterNameController.text = widget.rental.renterName;
    _renterPhoneController.text = widget.rental.renterPhone ?? '';
    _renterEmailController.text = widget.rental.renterEmail ?? '';
    _rentalPriceController.text = _formattingService.formatNumber(
      widget.rental.rentalPrice,
    );
    _depositController.text = _formattingService.formatNumber(
      widget.rental.deposit,
    );
    _notesController.text = widget.rental.notes ?? '';

    _selectedRentalStatus = widget.rental.status;
    _selectedPaymentFrequency = widget.rental.paymentFrequency;
    _selectedStartDate = widget.rental.startDate;
    _selectedEndDate = widget.rental.endDate;
  }

  void _setupChangeListeners() {
    _itemNameController.addListener(_onFieldChanged);
    _itemDescriptionController.addListener(_onFieldChanged);
    _renterNameController.addListener(_onFieldChanged);
    _renterPhoneController.addListener(_onFieldChanged);
    _renterEmailController.addListener(_onFieldChanged);
    _rentalPriceController.addListener(_onFieldChanged);
    _depositController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ العنصر
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null &&
          switchedUser['id'] == widget.rental.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await _getUserNameFromFirebase(widget.rental.createdBy);
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(widget.rental.createdBy);
    }

    // تحميل اسم المستخدم الذي حدّث العنصر
    String? updatedByName;
    if (widget.rental.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null &&
            switchedUser['id'] == widget.rental.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await _getUserNameFromFirebase(
          widget.rental.updatedBy!,
        );
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(
          widget.rental.updatedBy!,
        );
      }
    }

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
        _updatedByName = updatedByName;
      });
    }
  }

  /// تحميل اسم المستخدم من Firebase
  Future<String?> _getUserNameFromFirebase(String userId) async {
    if (userId.isEmpty) return null;

    // إذا كان البريد الإلكتروني، نستخرج اسم المستخدم
    if (userId.contains('@')) {
      final username = userId.split('@')[0];
      return username
          .replaceAll('.', ' ')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .split(' ')
          .map(
            (word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : '',
          )
          .join(' ');
    }

    // تحميل من Firebase
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final emailService = EmailNormalizationService();
        final normalizedEmail = emailService.normalize(currentUser.email!);

        // ملاحظة للمبرمجين المستقبليين: يُستخدم المثيل المحقون عبر GetIt بدلاً من
        // FirebaseFirestore.instance للحفاظ على اتساق نمط الحقن المستخدم في القسم.
        final userDoc = await GetIt.instance<FirebaseFirestore>()
            .collection(normalizedEmail)
            .doc('users')
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            final name = userData['name'] as String?;
            if (name != null && name.isNotEmpty) {
              return name;
            }

            final email = userData['email'] as String?;
            if (email != null && email.isNotEmpty) {
              final username = email.split('@')[0];
              return username
                  .replaceAll('.', ' ')
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ')
                  .split(' ')
                  .map(
                    (word) => word.isNotEmpty
                        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                        : '',
                  )
                  .join(' ');
            }
          }
        }
      }
    } on Exception catch (_) {
      // في حالة الخطأ، نعود للقيمة الافتراضية
    }

    return userId;
  }

  /// عرض اقتراحات العملاء
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
          // تحديث بيانات المستأجر من العميل
          _renterNameController.text = customer.name;
          _renterPhoneController.text = customer.phone;
          _renterEmailController.text = customer.email;
        });
      },
      maxHeight: 200.h,
    );
  }

  /// إخفاء اقتراحات العملاء
  void _hideCustomerSuggestionsOverlay() {
    SuggestionsOverlay.hide();
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
    _onFieldChanged();
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

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemDescriptionController.dispose();
    _renterNameController.dispose();
    _renterPhoneController.dispose();
    _renterEmailController.dispose();
    _rentalPriceController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    _customDaysController.dispose();
    _customerSearchController.dispose();
    SuggestionsOverlay.hide();
    super.dispose();
  }

  Future<bool> _handleBackPress() async {
    if (!_hasChanges) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text(
          'لديك تغييرات غير محفوظة. هل تريد الخروج بدون حفظ؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('خروج بدون حفظ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              _updateRental();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: const Text('حفظ والخروج'),
          ),
        ],
      ),
    );

    if (shouldDiscard ?? false) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const RentalDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: BlocConsumer<RentalBloc, RentalState>(
          listenWhen: (previous, current) {
            return current is RentalError ||
                (current is RentalOperationSuccess && isSaving);
          },
          listener: (context, state) {
            if (state is RentalOperationSuccess &&
                isSaving &&
                !_operationCompleted) {
              _operationCompleted = true;
              completeSaveOperation(successMessage: state.message);
              Navigator.of(context).pop(_savedRental);
            } else if (state is RentalError && !_operationCompleted) {
              _operationCompleted = true;
              failSaveOperation(errorMessage: state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is RentalLoading;

            return BlocListener<CustomerBloc, CustomerState>(
              listener: (context, state) {
                if (state is CustomerLoaded) {
                  setState(() {
                    _customers = state.customers;
                    _filteredCustomers = List.from(_customers);
                  });
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildWelcomeCard(context),
                    const SizedBox(height: 6),
                    _buildFormCard(context, isLoading),
                  ],
                ),
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
              'تعديل عقد الإيجار',
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
        if (_hasChanges)
          IconButton(
            onPressed: _updateRental,
            icon: Icon(
              Icons.save,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'حفظ التغييرات',
          ),
        IconButton(
          onPressed: _handleBackPress,
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
    return DetailScreenHeader(
      title: 'تعديل ${widget.rental.itemName}',
      subtitle: 'قم بتعديل معلومات عقد الإيجار',
      icon: Icons.edit,
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
          InfoCard(
            title: 'معلومات الشيء المؤجر',
            icon: Icons.home,
            children: [_builditemNameField(), _builditemDescriptionField()],
          ),
          const SizedBox(height: 16),

          InfoCard(
            title: 'معلومات المستأجر',
            icon: Icons.person,
            children: [
              // عرض معلومات العميل المرتبط إذا كان موجود
              if (widget.rental.customerId != null &&
                  widget.rental.customerName != null) ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        color: AssyrianTheme.primaryGold,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مرتبط بعميل: ${widget.rental.customerName}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AssyrianTheme.deepBlue,
                              ),
                            ),
                            Text(
                              'معرف العميل: ${widget.rental.customerId}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // حقل البحث عن العميل
              _buildCustomerSearchField(),
              _buildrenterNameField(),
              _buildrenterPhoneField(),
              _buildrenterEmailField(),
            ],
          ),
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
              _buildStatusDropdown(),
              _buildNotesField(),
            ],
          ),
          const SizedBox(height: 16),

          InfoCard(
            title: 'معلومات النظام',
            icon: Icons.info_outline,
            children: [_buildSystemInfo()],
          ),
          const SizedBox(height: 24),

          _buildActionButtons(isLoading),
        ],
      ),
    );
  }

  Widget _builditemNameField() {
    return TextFormField(
      controller: _itemNameController,
      decoration: InputDecoration(
        labelText: 'اسم الشيء المؤجر *',
        hintText: 'أدخل اسم الشيء المؤجر',
        prefixIcon: const Icon(Icons.home, color: AssyrianTheme.primaryGold),
        suffixIcon: _itemNameController.text != widget.rental.itemName
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يجب إدخال اسم الشيء المؤجر';
        }
        return null;
      },
    );
  }

  Widget _builditemDescriptionField() {
    return TextFormField(
      controller: _itemDescriptionController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'وصف الشيء',
        hintText: 'أدخل وصف الشيء',
        prefixIcon: const Icon(
          Icons.location_on,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon:
            _itemDescriptionController.text !=
                (widget.rental.itemDescription ?? '')
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
    );
  }

  Widget _buildCustomerSearchField() {
    return CompositedTransformTarget(
      link: _customerLayerLink,
      child: Container(
        key: _customerFieldKey,
        child: TextFormField(
          controller: _customerSearchController,
          decoration: InputDecoration(
            labelText: 'البحث عن عميل (اختياري)',
            hintText: 'ابحث عن عميل لربطه بهذا الإيجار...',
            prefixIcon: Icon(
              Icons.search,
              size: 20.sp,
              color: AssyrianTheme.primaryGold,
            ),
            suffixIcon: _customerSearchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20.sp),
                    onPressed: () {
                      _customerSearchController.clear();
                      _filteredCustomers = List.from(_customers);
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
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: AssyrianTheme.primaryGold,
                width: 1.5,
              ),
            ),
            labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
          ),
          onChanged: (value) {
            if (value.isEmpty) {
              _filteredCustomers = List.from(_customers);
              _hideCustomerSuggestionsOverlay();
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
            }
          },
          onTap: () {
            if (_customerSearchController.text.isNotEmpty &&
                _filteredCustomers.isNotEmpty) {
              _showCustomerSuggestionsOverlay();
            }
          },
        ),
      ),
    );
  }

  Widget _buildrenterNameField() {
    return TextFormField(
      controller: _renterNameController,
      decoration: InputDecoration(
        labelText: 'اسم المستأجر *',
        hintText: 'أدخل اسم المستأجر',
        prefixIcon: const Icon(Icons.person, color: AssyrianTheme.primaryGold),
        suffixIcon: _renterNameController.text != widget.rental.renterName
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يجب إدخال اسم المستأجر';
        }
        return null;
      },
    );
  }

  Widget _buildrenterPhoneField() {
    return TextFormField(
      controller: _renterPhoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'هاتف المستأجر',
        hintText: 'أدخل رقم هاتف المستأجر',
        prefixIcon: const Icon(Icons.phone, color: AssyrianTheme.primaryGold),
        suffixIcon:
            _renterPhoneController.text != (widget.rental.renterPhone ?? '')
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
    );
  }

  Widget _buildrenterEmailField() {
    return TextFormField(
      controller: _renterEmailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'بريد المستأجر الإلكتروني',
        hintText: 'أدخل البريد الإلكتروني للمستأجر',
        prefixIcon: const Icon(Icons.email, color: AssyrianTheme.primaryGold),
        suffixIcon:
            _renterEmailController.text != (widget.rental.renterEmail ?? '')
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'يجب إدخال بريد إلكتروني صحيح';
          }
        }
        return null;
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
        prefixIcon: const Icon(
          Icons.attach_money,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'د.ع',
        suffixIcon:
            _rentalPriceController.text !=
                _formattingService.formatNumber(widget.rental.rentalPrice)
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
        prefixIcon: const Icon(
          Icons.security,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'د.ع',
        suffixIcon: _depositController.text != widget.rental.deposit.toString()
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
            suffixIcon:
                _selectedPaymentFrequency != widget.rental.paymentFrequency
                ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
              _onFieldChanged();
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
            _onFieldChanged();
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
          suffixIcon: _selectedStartDate != widget.rental.startDate
              ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
              : Icon(
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
        suffixIcon: _selectedEndDate != widget.rental.endDate
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
            : Icon(Icons.lock_outline, size: 16.sp, color: Colors.grey),
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

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue:
          _rentalStatuses.any((status) => status['id'] == _selectedRentalStatus)
          ? _selectedRentalStatus
          : null,
      decoration: InputDecoration(
        labelText: 'حالة العقد *',
        hintText: 'اختر حالة العقد',
        prefixIcon: const Icon(Icons.info, color: AssyrianTheme.primaryGold),
        suffixIcon: _selectedRentalStatus != widget.rental.status
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
      items: _rentalStatuses
          .map(
            (status) => DropdownMenuItem<String>(
              value: status['id'],
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: status['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(status['name']),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedRentalStatus = value;
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار حالة العقد';
        }
        return null;
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'ملاحظات',
        hintText: 'أدخل أي ملاحظات إضافية (اختياري)',
        prefixIcon: const Icon(Icons.note, color: AssyrianTheme.primaryGold),
        suffixIcon: _notesController.text != (widget.rental.notes ?? '')
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
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
    );
  }

  Widget _buildSystemInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildReadOnlyRow(
            'تاريخ الإنشاء',
            DateFormat('dd/MM/yyyy HH:mm').format(widget.rental.createdAt),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow('تم الإنشاء بواسطة', _createdByName ?? 'غير محدد'),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            'آخر تحديث',
            DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(widget.rental.updatedAt ?? DateTime.now()),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            'تم التحديث بواسطة',
            _updatedByName ?? widget.rental.updatedBy ?? 'غير محدد',
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isLoading) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: LoadingButton(
                text: 'حفظ التغييرات',
                onPressed: _hasChanges ? _updateRental : null,
                isLoading: isLoading,
                icon: Icons.save,
                backgroundColor: _hasChanges
                    ? AssyrianTheme.primaryGold
                    : Colors.grey[300]!,
                foregroundColor: _hasChanges
                    ? AssyrianTheme.deepBlue
                    : Colors.grey[600]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة تعيين'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete),
                label: const Text('حذف العقد'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.rentalDetails,
                    arguments: widget.rental,
                  );
                },
                icon: const Icon(Icons.visibility),
                label: const Text('عرض التفاصيل'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AssyrianTheme.primaryGold,
                  side: const BorderSide(color: AssyrianTheme.primaryGold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updateRental() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

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

    final updatedRental = widget.rental.copyWith(
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
      customerId: _selectedCustomer?.id ?? widget.rental.customerId,
      customerName: _selectedCustomer?.name ?? widget.rental.customerName,
      rentalPrice:
          double.tryParse(
            _rentalPriceController.text.trim().replaceAll(',', ''),
          ) ??
          0.0,
      deposit:
          double.tryParse(_depositController.text.trim().replaceAll(',', '')) ??
          0,
      paymentFrequency: _selectedPaymentFrequency,
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      status: _selectedRentalStatus,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ RentalBloc قبل العملية غير المتزامنة
    final rentalBloc = context.read<RentalBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      // إضافة await لضمان انتظار انتهاء عملية الحفظ قبل المتابعة
      triggerSave: () {
        _savedRental = updatedRental;
        rentalBloc.add(UpdateRentalEvent(updatedRental));
      },
      successMessage: 'تم تحديث عقد الإيجار بنجاح',
      loadingMessage: 'جاري تحديث عقد الإيجار...',
    );
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين النموذج'),
        content: const Text(
          'هل تريد إعادة تعيين جميع الحقول إلى القيم الأصلية؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeFields();
              setState(() {
                _hasChanges = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إعادة تعيين النموذج'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    DeleteRentalDialog.show(
      context,
      widget.rental,
      context.read<RentalBloc>(),
      onDeleted: () {
        Navigator.of(context).pop();
      },
    );
  }
}
