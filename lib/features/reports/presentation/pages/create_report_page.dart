import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/report_entity.dart';
import '../bloc/report_bloc.dart';
import '../widgets/report_drawer.dart';

/// صفحة إضافة تقرير جديد
class CreateReportPage extends StatefulWidget {
  const CreateReportPage({super.key});

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage>
    with SaveOperationMixin {
  final _formKey = GlobalKey<FormState>();

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // Controllers للحقول النصية
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedType;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // قوائم الخيارات
  final List<Map<String, dynamic>> _reportTypes = [
    {
      'id': 'financial',
      'name': 'تقرير مالي',
      'description': 'تقرير شامل عن الوضع المالي والإيرادات والمصاريف',
      'icon': Icons.account_balance,
      'color': Colors.green,
    },
    {
      'id': 'inventory',
      'name': 'تقرير مخزون',
      'description': 'تقرير عن حالة المخزون والمنتجات المتاحة',
      'icon': Icons.inventory,
      'color': Colors.blue,
    },
    {
      'id': 'sales',
      'name': 'تقرير مبيعات',
      'description': 'تقرير عن المبيعات والفواتير والعملاء',
      'icon': Icons.trending_up,
      'color': Colors.orange,
    },
    {
      'id': 'expenses',
      'name': 'تقرير مصاريف',
      'description': 'تقرير عن المصاريف والنفقات التشغيلية',
      'icon': Icons.money_off,
      'color': Colors.red,
    },
    {
      'id': 'custom',
      'name': 'تقرير مخصص',
      'description': 'تقرير مخصص حسب المتطلبات المحددة',
      'icon': Icons.analytics,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    // تعيين التواريخ الافتراضية (الشهر الحالي)
    final now = DateTime.now();
    _selectedStartDate = DateTime(now.year, now.month);
    // ⚠️ إذا كان الشهر ديسمبر (month=12)، فإن month+1 = 13 يُنشئ تاريخًا في يناير من العام التالي.
    // هذا يعمل بشكل صحيح في Dart، لكنه قد يسبب ارتباكًا عند عرض الواجهة. يُنصح باستخدام
    // DateTime(now.year, now.month + 1, 0) مع توثيق هذا السلوك أو استخدام طريقة أكثر وضوحًا.
    _selectedEndDate = DateTime(now.year, now.month + 1, 0);
    _startDateController.text =
        '${_selectedStartDate!.day}/${_selectedStartDate!.month}/${_selectedStartDate!.year}';
    _endDateController.text =
        '${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const ReportDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<ReportBloc, ReportState>(
        listenWhen: (previous, current) {
          return current is ReportError || current is ReportOperationSuccess;
        },
        listener: (context, state) {
          if (state is ReportError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          } else if (state is ReportOperationSuccess && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: 'تم إنشاء التقرير بنجاح',
              navigateBackOnSuccess: true,
            );
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
                  'إضافة تقرير جديد',
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
                  'نظام إدارة التقارير الآشوري',
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
      title: 'إضافة تقرير جديد',
      subtitle: 'إنشاء تقرير جديد وإضافته إلى قاعدة البيانات',
      icon: Icons.analytics,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context, bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('المعلومات الأساسية'),
            const SizedBox(height: 12),
            _buildTitleField(),
            const SizedBox(height: 12),
            _buildDescriptionField(),
            const SizedBox(height: 20),

            _buildSectionTitle('نوع التقرير'),
            const SizedBox(height: 12),
            _buildReportTypeSelection(),
            const SizedBox(height: 20),

            _buildSectionTitle('فترة التقرير'),
            const SizedBox(height: 12),
            _buildStartDateField(),
            const SizedBox(height: 12),
            _buildEndDateField(),
            const SizedBox(height: 24),

            _buildSubmitButton(isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AssyrianTheme.deepBlue,
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
        if (value.trim().length < 3) {
          return 'يجب أن يكون العنوان أكثر من حرفين';
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
        hintText: 'أدخل وصف تفصيلي للتقرير والغرض منه',
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
          return 'يجب إدخال وصف التقرير';
        }
        if (value.trim().length < 10) {
          return 'يجب أن يكون الوصف أكثر من 9 أحرف';
        }
        return null;
      },
    );
  }

  Widget _buildReportTypeSelection() {
    return Column(
      children: _reportTypes.map((type) {
        final isSelected = _selectedType == type['id'];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedType = type['id'];
                // تحديث العنوان تلقائياً إذا كان فارغاً
                if (_titleController.text.isEmpty) {
                  _titleController.text = type['name'];
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (type['color'] as Color).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? (type['color'] as Color)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (type['color'] as Color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      type['icon'],
                      color: type['color'],
                      size: 24.sp,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type['name'],
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (type['color'] as Color)
                                : AssyrianTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type['description'],
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: type['color'], size: 20.sp),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStartDateField() {
    return TextFormField(
      controller: _startDateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'تاريخ البداية *',
        hintText: 'اختر تاريخ بداية فترة التقرير',
        prefixIcon: const Icon(
          Icons.calendar_today,
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
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate:
              _selectedStartDate ??
              DateTime.now().subtract(const Duration(days: 30)),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() {
            _selectedStartDate = date;
            _startDateController.text =
                '${date.day}/${date.month}/${date.year}';

            // تحديث تاريخ النهاية إذا كان قبل تاريخ البداية
            if (_selectedEndDate != null && _selectedEndDate!.isBefore(date)) {
              _selectedEndDate = date.add(const Duration(days: 30));
              _endDateController.text =
                  '${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}';
            }
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
        hintText: 'اختر تاريخ نهاية فترة التقرير',
        prefixIcon: const Icon(Icons.event, color: AssyrianTheme.primaryGold),
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
        final minDate = _selectedStartDate ?? DateTime(2000);
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedEndDate ?? DateTime.now(),
          firstDate: minDate,
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() {
            _selectedEndDate = date;
            _endDateController.text = '${date.day}/${date.month}/${date.year}';
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار تاريخ النهاية';
        }
        if (_selectedStartDate != null && _selectedEndDate != null) {
          if (_selectedEndDate!.isBefore(_selectedStartDate!)) {
            return 'يجب أن يكون تاريخ النهاية بعد تاريخ البداية';
          }
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: LoadingButton(
        text: 'إنشاء التقرير',
        onPressed: _createReport,
        isLoading: isLoading,
        icon: Icons.add,
        backgroundColor: AssyrianTheme.primaryGold,
        foregroundColor: AssyrianTheme.deepBlue,
      ),
    );
  }

  Future<void> _createReport() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار نوع التقرير'),
          backgroundColor: Colors.red,
        ),
      );
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

    final report = ReportEntity(
      id: '', // سيتم إنشاؤه تلقائيًا داخل المعاملة الذرية في المستودع (انظر addReport في report_repository_impl.dart)
      // ⚠️ المعرف يصل فارغًا من صفحة الإنشاء، ويُعاد من addReport ليستخدمه BLoC في سجل التدقيق (targetId).
      // إذا تم إرسال معرف غير فارغ، سيستخدمه المستودع مباشرة دون توليد جديد.
      organizationEmail: currentUser.email!,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType!,
      startDate: _selectedStartDate!,
      endDate: _selectedEndDate!,
      data: const {}, // سيتم ملؤه عند إنتاج التقرير
      status: 'pending', // الحالة الافتراضية
      generatedBy: createdBy,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    if (mounted) {
      // الحصول على مرجع لـ ReportBloc قبل العملية غير المتزامنة
      final reportBloc = context.read<ReportBloc>();

      // تنفيذ الحفظ عبر النظام الموحد — ينتظر نتيجة المعاملة
      // الذرية ولا يعرض النجاح إلا بعد تأكيدها (نفس نمط
      // صفحات الإنشاء الأخرى). ⚠️ كان يُغلق الصفحة ويعرض
      // نجاحاً فورياً قبل اكتمال المعاملة — فإذا فشلت المعاملة
      // الذرية ظهر النجاح كاذباً ولم يُحفظ التقرير (وكان الحدث
      // يُتجاهل أصلاً لأن الـ BLoC يبدأ بحالة ReportInitial —
      // انظر _onAddReport).
      await performBlocSaveOperation(
        triggerSave: () {
          reportBloc.add(AddReportEvent(report));
        },
        successMessage: 'تم إنشاء التقرير بنجاح',
        loadingMessage: 'جاري إنشاء التقرير...',
      );
    }
  }
}
