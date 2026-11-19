import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/user_name_helper.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../widgets/expense_drawer.dart';

/// صفحة تفاصيل المصروف
class ExpenseDetailsPage extends StatefulWidget {
  const ExpenseDetailsPage({required this.expense, super.key});
  final ExpenseEntity expense;

  @override
  State<ExpenseDetailsPage> createState() => _ExpenseDetailsPageState();
}

class _ExpenseDetailsPageState extends State<ExpenseDetailsPage> {
  late ExpenseEntity _expense;

  void _applyUpdatedExpense(ExpenseEntity expense) {
    if (!mounted || expense.id != _expense.id || expense == _expense) return;
    setState(() => _expense = expense);
    _loadUserNames();
  }

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  String? _createdByName;
  String? _updatedByName;
  String? _approvedByName;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
    _loadRelatedData();
    _loadPermissions();
    _loadUserNames();
  }

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission('expenses_edit');

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
      });
    }
  }

  void _loadRelatedData() {
    // تحميل البيانات المرتبطة إذا كانت متاحة
    final state = context.read<ExpenseBloc>().state;
    if (state is ExpenseLoaded) {
      // يمكن إضافة منطق لتحميل بيانات مرتبطة هنا
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpenseBloc, ExpenseState>(
      listener: (context, state) {
        if (state is ExpenseLoaded || state is ExpenseStreamActive) {
          final expenses = state is ExpenseLoaded
              ? state.expenses
              : (state as ExpenseStreamActive).expenses;
          for (final expense in expenses) {
            if (expense.id == _expense.id) {
              _applyUpdatedExpense(expense);
              break;
            }
          }
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const ExpenseDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildExpenseHeader(),
              const SizedBox(height: 6),
              _buildBasicInfoCard(),
              const SizedBox(height: 6),
              _buildAmountCard(),
              const SizedBox(height: 6),
              _buildCategoryCard(),
              const SizedBox(height: 6),
              _buildStatusCard(),
              const SizedBox(height: 6),
              _buildActionsCard(),
            ],
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
            child: Text(
              'تفاصيل المصروف',
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
        if (_canEdit)
          IconButton(
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                AppRoutes.editExpense,
                arguments: _expense,
              );
              if (!mounted) return;
              if (result is ExpenseEntity) _applyUpdatedExpense(result);
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل المصروف',
          ),
      ],
    );
  }

  Widget _buildExpenseHeader() {
    return DetailScreenHeader(
      title: _expense.title,
      subtitle: _formattingService.formatExpenseAmount(_expense.amount),
      icon: Icons.money_off,
      iconBackgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      iconForegroundColor: AssyrianTheme.primaryGold,
    );
  }

  Widget _buildBasicInfoCard() {
    return InfoCard(
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline,
      children: [
        DetailRow(label: 'عنوان المصروف', value: _expense.title),
        DetailRow(label: 'تاريخ المصروف', value: _formatDate(_expense.date)),
        DetailRow(label: 'الوصف', value: _expense.description),
      ],
    );
  }

  Widget _buildAmountCard() {
    return InfoCard(
      title: 'المبلغ والتفاصيل المالية',
      icon: Icons.attach_money,
      children: [
        AmountRow(
          label: 'المبلغ الأساسي',
          amount: _expense.amount,
          color: Colors.red,
        ),
        const Divider(),
        DetailRow(label: 'طريقة الدفع', value: _expense.paymentMethod),
        if (_expense.receiptUrl != null && _expense.receiptUrl!.isNotEmpty)
          DetailRow(label: 'رابط الإيصال', value: _expense.receiptUrl!),
      ],
    );
  }

  Widget _buildCategoryCard() {
    return InfoCard(
      title: 'التصنيف والنوع',
      icon: Icons.category,
      children: [
        DetailRow(label: 'الفئة', value: _expense.category),
        StatusRow(
          label: 'حالة المصروف',
          value: _getStatusText(_expense.status),
          color: _getStatusColor(_expense.status),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return InfoCard(
      title: 'معلومات النظام',
      icon: Icons.system_update,
      children: [
        DetailRow(
          label: 'تاريخ الإنشاء',
          value: _formatDateTime(_expense.createdAt),
        ),
        DetailRow(label: 'أنشئ بواسطة', value: _createdByName ?? 'غير محدد'),
        DetailRow(
          label: 'آخر تحديث',
          value: _formatDateTime(_expense.updatedAt),
        ),
        if (_expense.updatedBy != null)
          DetailRow(
            label: 'آخر تحديث بواسطة',
            value: _updatedByName ?? _expense.updatedBy!,
          ),
        if (_expense.approvedBy != null)
          DetailRow(
            label: 'تمت الموافقة بواسطة',
            value: _approvedByName ?? _expense.approvedBy!,
          ),
        if (_expense.approvedAt != null)
          DetailRow(
            label: 'تاريخ الموافقة',
            value: _formatDateTime(_expense.approvedAt!),
          ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return ActionButtons(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.editExpense,
                    arguments: _expense,
                  );
                  if (!mounted) return;
                  if (result is ExpenseEntity) _applyUpdatedExpense(result);
                },
                icon: const Icon(Icons.edit),
                label: const Text('تعديل المصروف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: AssyrianTheme.deepBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('وظيفة الطباعة قيد التطوير'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('طباعة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AssyrianTheme.primaryGold,
                  side: const BorderSide(color: AssyrianTheme.primaryGold),
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('وظيفة المشاركة قيد التطوير'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('مشاركة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('وظيفة الحذف قيد التطوير'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.delete),
                label: const Text('حذف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// تحميل أسماء المستخدمين من Firebase
  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ العنصر
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == _expense.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await UserNameHelper.getUserNameFromFirebase(
        _expense.createdBy,
      );
    } on Exception catch (_) {
      createdByName = await UserNameHelper.getUserNameFromFirebase(
        _expense.createdBy,
      );
    }

    // تحميل اسم المستخدم الذي حدّث العنصر
    String? updatedByName;
    if (_expense.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] == _expense.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await UserNameHelper.getUserNameFromFirebase(
          _expense.updatedBy!,
        );
      } on Exception catch (_) {
        updatedByName = await UserNameHelper.getUserNameFromFirebase(
          _expense.updatedBy!,
        );
      }
    }

    // تحميل اسم المستخدم الذي وافق على العنصر
    String? approvedByName;
    if (_expense.approvedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] == _expense.approvedBy) {
          approvedByName = switchedUser['name'] as String?;
        }

        approvedByName ??= await UserNameHelper.getUserNameFromFirebase(
          _expense.approvedBy!,
        );
      } on Exception catch (_) {
        approvedByName = await UserNameHelper.getUserNameFromFirebase(
          _expense.approvedBy!,
        );
      }
    }

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
        _updatedByName = updatedByName;
        _approvedByName = approvedByName;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'موافق عليه';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
}
