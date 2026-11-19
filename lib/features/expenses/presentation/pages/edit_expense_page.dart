import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/user_name_helper.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/delete_expense_dialog.dart';
import '../widgets/expense_drawer.dart';

/// صفحة تعديل المصروف
class EditExpensePage extends StatefulWidget {
  const EditExpensePage({required this.expense, super.key});
  final ExpenseEntity expense;

  @override
  State<EditExpensePage> createState() => _EditExpensePageState();
}

class _EditExpensePageState extends State<EditExpensePage>
    with SaveOperationMixin<EditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  ExpenseEntity? _savedExpense;
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  String? _createdByName;
  String? _updatedByName;

  // Controllers للحقول النصية
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime? _selectedDate;

  // قوائم البيانات
  final List<Map<String, String>> _categories = [
    {'id': 'office_supplies', 'name': 'مستلزمات مكتبية'},
    {'id': 'utilities', 'name': 'فواتير الخدمات'},
    {'id': 'maintenance', 'name': 'صيانة وإصلاح'},
    {'id': 'transportation', 'name': 'مواصلات'},
    {'id': 'marketing', 'name': 'تسويق وإعلان'},
    {'id': 'training', 'name': 'تدريب وتطوير'},
    {'id': 'legal', 'name': 'خدمات قانونية'},
    {'id': 'other', 'name': 'أخرى'},
  ];

  final List<Map<String, String>> _paymentMethods = [
    {'id': 'cash', 'name': 'نقداً'},
    {'id': 'bank_transfer', 'name': 'تحويل بنكي'},
    {'id': 'credit_card', 'name': 'بطاقة ائتمان'},
    {'id': 'debit_card', 'name': 'بطاقة خصم'},
    {'id': 'check', 'name': 'شيك'},
    {'id': 'other', 'name': 'أخرى'},
  ];

  // متغير لتتبع التغييرات
  bool _hasChanges = false;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _setupChangeListeners();
    _loadUserNames();
  }

  void _initializeFields() {
    _titleController.text = widget.expense.title;
    _descriptionController.text = widget.expense.description;
    _amountController.text = _formattingService.formatNumber(
      widget.expense.amount,
    );
    _selectedCategory = widget.expense.category;
    _selectedPaymentMethod = widget.expense.paymentMethod;
    _selectedDate = widget.expense.date;
    _dateController.text = DateFormat('dd/MM/yyyy').format(widget.expense.date);
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _amountController.addListener(_onFieldChanged);
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
          switchedUser['id'] == widget.expense.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await UserNameHelper.getUserNameFromFirebase(
        widget.expense.createdBy,
      );
    } on Exception catch (_) {
      createdByName = await UserNameHelper.getUserNameFromFirebase(
        widget.expense.createdBy,
      );
    }

    // تحميل اسم المستخدم الذي حدّث العنصر
    String? updatedByName;
    if (widget.expense.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null &&
            switchedUser['id'] == widget.expense.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await UserNameHelper.getUserNameFromFirebase(
          widget.expense.updatedBy!,
        );
      } on Exception catch (_) {
        updatedByName = await UserNameHelper.getUserNameFromFirebase(
          widget.expense.updatedBy!,
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
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
              _updateExpense();
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
        drawer: const ExpenseDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: BlocConsumer<ExpenseBloc, ExpenseState>(
          listenWhen: (previous, current) {
            return current is ExpenseError ||
                (current is ExpenseOperationSuccess && isSaving);
          },
          listener: (context, state) {
            if (state is ExpenseOperationSuccess &&
                isSaving &&
                !_operationCompleted) {
              _operationCompleted = true;
              completeSaveOperation(successMessage: state.message);
              Navigator.of(context).pop(_savedExpense);
            } else if (state is ExpenseError && !_operationCompleted) {
              _operationCompleted = true;
              failSaveOperation(errorMessage: state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is ExpenseLoading;

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
              'تعديل المصروف',
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
            onPressed: _updateExpense,
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
      title: 'تعديل ${widget.expense.title}',
      subtitle: 'قم بتعديل المعلومات المطلوبة',
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
            title: 'المعلومات الأساسية',
            icon: Icons.info_outline,
            children: [
              _buildTitleField(),
              _buildAmountField(),
              _buildDateField(),
              _buildCategoryDropdown(),
              _buildPaymentMethodDropdown(),
              _buildDescriptionField(),
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

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'عنوان المصروف *',
        hintText: 'أدخل عنوان المصروف',
        prefixIcon: const Icon(Icons.title, color: AssyrianTheme.primaryGold),
        suffixIcon: _titleController.text != widget.expense.title
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
          return 'يجب إدخال عنوان المصروف';
        }
        if (value.trim().length < 2) {
          return 'يجب أن يكون العنوان أكثر من حرف واحد';
        }
        return null;
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [_formattingService.getPriceInputFormatter()],
      decoration: InputDecoration(
        labelText: 'المبلغ *',
        hintText: 'أدخل مبلغ المصروف',
        prefixIcon: const Icon(
          Icons.attach_money,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'د.ع',
        suffixIcon:
            _amountController.text !=
                _formattingService.formatNumber(widget.expense.amount)
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
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'تاريخ المصروف *',
        hintText: 'اختر التاريخ',
        prefixIcon: const Icon(
          Icons.calendar_today,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _selectedDate != widget.expense.date
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
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
            _dateController.text = DateFormat('dd/MM/yyyy').format(date);
            _onFieldChanged();
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار التاريخ';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _categories.any((cat) => cat['id'] == _selectedCategory)
          ? _selectedCategory
          : null,
      decoration: InputDecoration(
        labelText: 'فئة المصروف *',
        hintText: 'اختر الفئة',
        prefixIcon: const Icon(
          Icons.category,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _selectedCategory != widget.expense.category
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
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار الفئة';
        }
        return null;
      },
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return DropdownButtonFormField<String>(
      initialValue:
          _paymentMethods.any(
            (method) => method['id'] == _selectedPaymentMethod,
          )
          ? _selectedPaymentMethod
          : null,
      decoration: InputDecoration(
        labelText: 'طريقة الدفع *',
        hintText: 'اختر طريقة الدفع',
        prefixIcon: const Icon(Icons.payment, color: AssyrianTheme.primaryGold),
        suffixIcon: _selectedPaymentMethod != widget.expense.paymentMethod
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
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار طريقة الدفع';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'الوصف',
        hintText: 'أدخل وصف المصروف (اختياري)',
        prefixIcon: const Icon(
          Icons.description,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _descriptionController.text != widget.expense.description
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
            DateFormat('dd/MM/yyyy HH:mm').format(widget.expense.createdAt),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow('تم الإنشاء بواسطة', _createdByName ?? 'غير محدد'),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            'آخر تحديث',
            DateFormat('dd/MM/yyyy HH:mm').format(widget.expense.updatedAt),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            'تم التحديث بواسطة',
            _updatedByName ?? widget.expense.updatedBy ?? 'غير محدد',
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
                onPressed: _hasChanges ? _updateExpense : null,
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
                label: const Text('حذف المصروف'),
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
                    AppRoutes.expenseDetails,
                    arguments: widget.expense,
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

  Future<void> _updateExpense() async {
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

    final updatedExpense = widget.expense.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      amount: double.parse(_amountController.text.trim().replaceAll(',', '')),
      date: _selectedDate,
      category: _selectedCategory,
      paymentMethod: _selectedPaymentMethod,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ ExpenseBloc قبل العملية غير المتزامنة
    final expenseBloc = context.read<ExpenseBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        _savedExpense = updatedExpense;
        expenseBloc.add(UpdateExpenseEvent(updatedExpense));
      },
      successMessage: 'تم تحديث المصروف بنجاح',
      loadingMessage: 'جاري تحديث المصروف...',
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
    DeleteExpenseDialog.show(
      context,
      widget.expense,
      context.read<ExpenseBloc>(),
      onDeleted: () {
        Navigator.of(context).pop();
      },
    );
  }
}
