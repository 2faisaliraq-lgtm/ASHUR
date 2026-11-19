import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/expense_drawer.dart';

/// صفحة إضافة مصروف جديد
class CreateExpensePage extends StatefulWidget {
  const CreateExpensePage({super.key});

  @override
  State<CreateExpensePage> createState() => _CreateExpensePageState();
}

class _CreateExpensePageState extends State<CreateExpensePage>
    with SaveOperationMixin<CreateExpensePage> {
  final FormattingService _formattingService = FormattingService();
  final _formKey = GlobalKey<FormState>();

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // Controllers للحقول النصية
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime? _selectedDate;

  // إعدادات المصروفات المحملة
  bool _requireApprovalForExpenses = true;
  double _maxExpenseWithoutApproval = 1000.0;
  bool _blockOverBudgetExpenses = false;
  bool _settingsLoaded = false;

  // قوائم الخيارات
  final List<Map<String, String>> _categories = [
    {'id': 'operational', 'name': 'مصاريف تشغيلية'},
    {'id': 'maintenance', 'name': 'مصاريف صيانة'},
    {'id': 'employee', 'name': 'مصاريف موظفين'},
    {'id': 'marketing', 'name': 'مصاريف تسويق'},
    {'id': 'utilities', 'name': 'فواتير ومرافق'},
    {'id': 'office', 'name': 'مصاريف مكتبية'},
    {'id': 'travel', 'name': 'مصاريف سفر'},
    {'id': 'other', 'name': 'مصاريف أخرى'},
  ];

  final List<Map<String, String>> _paymentMethods = [
    {'id': 'cash', 'name': 'نقداً'},
    {'id': 'bank_transfer', 'name': 'تحويل بنكي'},
    {'id': 'credit_card', 'name': 'بطاقة ائتمان'},
    {'id': 'debit_card', 'name': 'بطاقة خصم'},
    {'id': 'check', 'name': 'شيك'},
    {'id': 'online_payment', 'name': 'دفع إلكتروني'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text =
        '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getExpensesSettings();
      if (mounted) {
        setState(() {
          _requireApprovalForExpenses =
              settings['requireApprovalForExpenses'] ?? true;
          _maxExpenseWithoutApproval =
              settings['maxExpenseWithoutApproval'] ?? 1000.0;
          _blockOverBudgetExpenses =
              settings['blockOverBudgetExpenses'] ?? false;
          _settingsLoaded = true;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() => _settingsLoaded = true);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const ExpenseDrawer(),
      body: BlocListener<ExpenseBloc, ExpenseState>(
        listenWhen: (previous, current) {
          return current is ExpenseError ||
              (current is ExpenseOperationSuccess && isSaving);
        },
        listener: (context, state) {
          if (state is ExpenseError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          } else if (state is ExpenseOperationSuccess &&
              isSaving &&
              !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: state.message,
              navigateBackOnSuccess: true,
            );
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [_buildWelcomeCard(context), _buildFormCard(context)],
          ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة مصروف جديد',
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
                  'نظام إدارة المصروفات الآشوري',
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
      title: 'إضافة مصروف جديد',
      subtitle: 'إنشاء مصروف جديد وإضافته إلى قاعدة البيانات',
      icon: Icons.money_off,
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
            title: 'معلومات المصروف',
            icon: Icons.info_outline,
            children: [
              _buildTitleField(),
              _buildDescriptionField(),
              _buildAmountField(),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'تفاصيل المصروف',
            icon: Icons.settings,
            children: [
              _buildCategoryDropdown(),
              _buildPaymentMethodDropdown(),
              _buildDateField(),
            ],
          ),
          SizedBox(height: 24.h),
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              final isLoading = state is ExpenseLoading;
              return Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      text: 'إنشاء المصروف',
                      onPressed: isSaving ? null : _createExpense,
                      isLoading: isSaving,
                      icon: Icons.add,
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

  Widget _buildTitleField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          labelText: 'عنوان المصروف',
          hintText: 'أدخل عنوان المصروف',
          prefixIcon: const Icon(Icons.title, color: AssyrianTheme.primaryGold),
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
            return 'يجب إدخال عنوان المصروف';
          }
          if (value.trim().length < 3) {
            return 'يجب أن يكون العنوان أكثر من حرفين';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'وصف المصروف',
          hintText: 'أدخل وصف تفصيلي للمصروف',
          prefixIcon: const Icon(
            Icons.description,
            color: AssyrianTheme.primaryGold,
          ),
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
            return 'يجب إدخال وصف المصروف';
          }
          if (value.trim().length < 5) {
            return 'يجب أن يكون الوصف أكثر من 4 أحرف';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildAmountField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_formattingService.getPriceInputFormatter()],
        decoration: InputDecoration(
          labelText: 'المبلغ',
          hintText: 'أدخل مبلغ المصروف',
          prefixIcon: const Icon(
            Icons.attach_money,
            color: AssyrianTheme.primaryGold,
          ),
          suffixText: 'د.ع',
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
            return 'يجب إدخال المبلغ';
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
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        decoration: InputDecoration(
          labelText: 'فئة المصروف',
          hintText: 'اختر فئة المصروف',
          prefixIcon: const Icon(
            Icons.category,
            color: AssyrianTheme.primaryGold,
          ),
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
        items: _categories
            .map(
              (category) => DropdownMenuItem<String>(
                value: category['id'],
                child: Text(category['name']!),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedCategory = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'يجب اختيار فئة المصروف';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedPaymentMethod,
        decoration: InputDecoration(
          labelText: 'طريقة الدفع',
          hintText: 'اختر طريقة الدفع',
          prefixIcon: const Icon(
            Icons.payment,
            color: AssyrianTheme.primaryGold,
          ),
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
        items: _paymentMethods
            .map(
              (method) => DropdownMenuItem<String>(
                value: method['id'],
                child: Text(method['name']!),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedPaymentMethod = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'يجب اختيار طريقة الدفع';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: _dateController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'تاريخ المصروف',
          hintText: 'اختر تاريخ المصروف',
          prefixIcon: const Icon(
            Icons.calendar_today,
            color: AssyrianTheme.primaryGold,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
                _dateController.text =
                    '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
              });
            },
          ),
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
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 30)),
          );
          if (date != null) {
            setState(() {
              _selectedDate = date;
              _dateController.text = '${date.day}/${date.month}/${date.year}';
            });
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'يجب اختيار تاريخ المصروف';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _createExpense() async {
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

    // انتظار تحميل الإعدادات قبل المتابعة
    if (!_settingsLoaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري تحميل الإعدادات، يرجى الانتظار...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    // التحقق من الحد الأقصى للمبلغ دون موافقة
    if (_requireApprovalForExpenses && amount > _maxExpenseWithoutApproval) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'المبلغ يتجاوز الحد المسموح بدون موافقة ($_maxExpenseWithoutApproval د.ع). سيتم إرسال المصروف للموافقة.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    // التحقق من منع المصروفات الزائدة عن الميزانية (إذا كان التفعيل مفعلاً)
    if (_blockOverBudgetExpenses) {
      // ملاحظة: فحص الميزانية الفعلي يتطلب بيانات الميزانية من الخدمة المختصة.
      // هنا يتم فقط تسجيل التنبيه للمبرمجين المستقبليين لإضافة المنطق عند توفر خدمة الميزانية.
    }

    // تحديد الحالة بناءً على إعداد الموافقة
    final status = _requireApprovalForExpenses ? 'pending' : 'approved';

    final expense = ExpenseEntity(
      id: '', // سيتم إنشاؤه تلقائياً
      organizationEmail: currentUser.email!,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      amount: amount,
      category: _selectedCategory!,
      date: _selectedDate!,
      paymentMethod: _selectedPaymentMethod!,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ ExpenseBloc قبل العملية غير المتزامنة
    final expenseBloc = context.read<ExpenseBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        expenseBloc.add(AddExpenseEvent(expense));
      },
      successMessage: 'تم إنشاء المصروف بنجاح',
      loadingMessage: 'جاري إنشاء المصروف...',
    );
  }
}
