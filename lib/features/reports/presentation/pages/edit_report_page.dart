import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/report_entity.dart';
import '../bloc/report_bloc.dart';
import '../widgets/delete_report_dialog.dart';
import '../widgets/report_drawer.dart';

/// صفحة تعديل التقرير
class EditReportPage extends StatefulWidget {
  const EditReportPage({required this.report, super.key});
  final ReportEntity report;

  @override
  State<EditReportPage> createState() => _EditReportPageState();
}

class _EditReportPageState extends State<EditReportPage>
    with SaveOperationMixin<EditReportPage> {
  final _formKey = GlobalKey<FormState>();
  ReportEntity? _savedReport;

  // Controllers للحقول النصية
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedType;
  String? _selectedStatus;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // قوائم البيانات
  final List<Map<String, String>> _reportTypes = [
    {'id': 'financial', 'name': 'تقرير مالي'},
    {'id': 'inventory', 'name': 'تقرير مخزون'},
    {'id': 'sales', 'name': 'تقرير مبيعات'},
    {'id': 'expenses', 'name': 'تقرير مصروفات'},
    {'id': 'custom', 'name': 'تقرير مخصص'},
  ];

  final List<Map<String, String>> _statusOptions = [
    {'id': 'pending', 'name': 'قيد الانتظار'},
    {'id': 'completed', 'name': 'مكتمل'},
    {'id': 'failed', 'name': 'فشل'},
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
  }

  void _initializeFields() {
    _titleController.text = widget.report.title;
    _descriptionController.text = widget.report.description;
    _selectedType = widget.report.type;
    _selectedStatus = widget.report.status;
    _selectedStartDate = widget.report.startDate;
    _selectedEndDate = widget.report.endDate;
    _startDateController.text = DateFormat(
      'dd/MM/yyyy',
    ).format(widget.report.startDate);
    _endDateController.text = DateFormat(
      'dd/MM/yyyy',
    ).format(widget.report.endDate);
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    // ⚠️ تم إضافة مستمعي التغيير لجميع الحقول القابلة للتعديل
    // (النوع، الحالة، تاريخ البداية، تاريخ النهاية) لضمان تفعيل
    // زر الحفظ عند تعديل أي منها. بدون هذه المستمعين، كانت التغييرات
    // في هذه الحقول لا تضبط _hasChanges = true وتبقى زر الحفظ معطلاً.
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
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
              _updateReport();
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
        drawer: const ReportDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: BlocConsumer<ReportBloc, ReportState>(
          listenWhen: (previous, current) {
            return current is ReportError ||
                (current is ReportOperationSuccess && isSaving);
          },
          listener: (context, state) {
            if (state is ReportOperationSuccess &&
                isSaving &&
                !_operationCompleted) {
              _operationCompleted = true;
              completeSaveOperation(successMessage: state.message);
              Navigator.of(context).pop(_savedReport);
            } else if (state is ReportError && !_operationCompleted) {
              _operationCompleted = true;
              failSaveOperation(errorMessage: state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is ReportLoading;

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
              'تعديل التقرير',
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
            onPressed: _updateReport,
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
      title: 'تعديل ${widget.report.title}',
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
              _buildDescriptionField(),
              _buildTypeDropdown(),
              _buildStatusDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'الفترة الزمنية',
            icon: Icons.date_range,
            children: [
              Row(
                children: [
                  Expanded(child: _buildStartDateField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildEndDateField()),
                ],
              ),
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
        labelText: 'عنوان التقرير *',
        hintText: 'أدخل عنوان التقرير',
        prefixIcon: const Icon(Icons.title, color: AssyrianTheme.primaryGold),
        suffixIcon: _titleController.text != widget.report.title
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
          return 'يجب إدخال عنوان التقرير';
        }
        if (value.trim().length < 2) {
          return 'يجب أن يكون العنوان أكثر من حرف واحد';
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
        labelText: 'وصف التقرير *',
        hintText: 'أدخل وصف التقرير',
        prefixIcon: const Icon(
          Icons.description,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _descriptionController.text != widget.report.description
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
          return 'يجب إدخال وصف التقرير';
        }
        return null;
      },
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _reportTypes.any((type) => type['id'] == _selectedType)
          ? _selectedType
          : null,
      decoration: InputDecoration(
        labelText: 'نوع التقرير *',
        hintText: 'اختر نوع التقرير',
        prefixIcon: const Icon(
          Icons.assessment,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _selectedType != widget.report.type
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
      items: _reportTypes
          .map(
            (type) => DropdownMenuItem<String>(
              value: type['id'],
              child: Text(type['name']!),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedType = value;
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار نوع التقرير';
        }
        return null;
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue:
          _statusOptions.any((status) => status['id'] == _selectedStatus)
          ? _selectedStatus
          : null,
      decoration: InputDecoration(
        labelText: 'حالة التقرير *',
        hintText: 'اختر حالة التقرير',
        prefixIcon: const Icon(Icons.flag, color: AssyrianTheme.primaryGold),
        suffixIcon: _selectedStatus != widget.report.status
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
      items: _statusOptions
          .map(
            (status) => DropdownMenuItem<String>(
              value: status['id'],
              child: Text(status['name']!),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedStatus = value;
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار حالة التقرير';
        }
        return null;
      },
    );
  }

  Widget _buildStartDateField() {
    return TextFormField(
      controller: _startDateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'تاريخ البداية *',
        hintText: 'اختر تاريخ البداية',
        prefixIcon: const Icon(
          Icons.calendar_today,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _selectedStartDate != widget.report.startDate
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
          initialDate: _selectedStartDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() {
            _selectedStartDate = date;
            _startDateController.text = DateFormat('dd/MM/yyyy').format(date);
            _onFieldChanged();
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار تاريخ البداية';
        }
        return null;
      },
    );
  }

  Widget _buildEndDateField() {
    return TextFormField(
      controller: _endDateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'تاريخ النهاية *',
        hintText: 'اختر تاريخ النهاية',
        prefixIcon: const Icon(
          Icons.calendar_today,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _selectedEndDate != widget.report.endDate
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
          initialDate: _selectedEndDate ?? DateTime.now(),
          firstDate: _selectedStartDate ?? DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() {
            _selectedEndDate = date;
            _endDateController.text = DateFormat('dd/MM/yyyy').format(date);
            _onFieldChanged();
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار تاريخ النهاية';
        }
        if (_selectedStartDate != null && _selectedEndDate != null) {
          if (_selectedEndDate!.isBefore(_selectedStartDate!)) {
            return 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
          }
        }
        return null;
      },
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
            DateFormat('dd/MM/yyyy HH:mm').format(widget.report.createdAt),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            'تم الإنشاء بواسطة',
            widget.report.createdBy ?? 'غير محدد',
          ),
          if (widget.report.completedAt != null) ...[
            const SizedBox(height: 8),
            _buildReadOnlyRow(
              'تاريخ الإكمال',
              DateFormat('dd/MM/yyyy HH:mm').format(widget.report.completedAt!),
            ),
          ],
          if (widget.report.generatedBy != null) ...[
            const SizedBox(height: 8),
            _buildReadOnlyRow('تم التوليد بواسطة', widget.report.generatedBy!),
          ],
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
                onPressed: _hasChanges ? _updateReport : null,
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
                label: const Text('حذف التقرير'),
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
                    AppRoutes.reportDetails,
                    arguments: widget.report,
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

  Future<void> _updateReport() async {
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

    final updatedReport = widget.report.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      status: _selectedStatus,
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      updatedBy: updatedBy,
      // ⚠️ لا يتم تحديث generatedBy أو completedAt هنا — هذه الحقول تُضبط فقط عند الإنشاء الأولي
      // أو عند إكمال التقرير. updatedBy يُسجل من قام بالتعديل الأخير فقط.
    );

    if (!mounted) return;

    // الحصول على مرجع لـ ReportBloc قبل العملية غير المتزامنة
    final reportBloc = context.read<ReportBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        _savedReport = updatedReport;
        reportBloc.add(UpdateReportEvent(updatedReport));
      },
      successMessage: 'تم تحديث التقرير بنجاح',
      loadingMessage: 'جاري تحديث التقرير...',
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
    DeleteReportDialog.show(
      context,
      widget.report,
      context.read<ReportBloc>(),
      onDeleted: () {
        Navigator.of(context).pop();
      },
    );
  }
}
