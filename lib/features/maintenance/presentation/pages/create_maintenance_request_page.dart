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
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/credit_limit_warning_dialog.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../domain/entities/maintenance_request_entity.dart';
import '../bloc/maintenance_bloc.dart';
import '../widgets/maintenance_drawer.dart';

/// صفحة إضافة طلب صيانة جديد
class CreateMaintenanceRequestPage extends StatefulWidget {
  const CreateMaintenanceRequestPage({super.key});

  @override
  State<CreateMaintenanceRequestPage> createState() =>
      _CreateMaintenanceRequestPageState();
}

class _CreateMaintenanceRequestPageState
    extends State<CreateMaintenanceRequestPage>
    with SaveOperationMixin {
  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final _formKey = GlobalKey<FormState>();

  // Controllers للحقول النصية
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _equipmentNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _notesController = TextEditingController();
  final _requestDateController = TextEditingController();
  final _scheduledDateController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedPriority;
  DateTime? _selectedRequestDate;
  DateTime? _selectedScheduledDate;

  // متغيرات مربع العميل
  final _customerSearchController = TextEditingController();
  final _customerLayerLink = LayerLink();
  final _customerFieldKey = GlobalKey();
  CustomerEntity? _selectedCustomer;
  List<CustomerEntity> _customers = [];
  List<CustomerEntity> _filteredCustomers = [];

  // قوائم الخيارات
  final List<Map<String, dynamic>> _priorities = [
    {'id': 'low', 'name': 'منخفضة', 'color': Colors.green},
    {'id': 'medium', 'name': 'متوسطة', 'color': Colors.orange},
    {'id': 'high', 'name': 'عالية', 'color': Colors.red},
    {'id': 'urgent', 'name': 'عاجلة', 'color': Colors.red[900]},
  ];

  @override
  void initState() {
    super.initState();
    _selectedRequestDate = DateTime.now();
    _requestDateController.text =
        '${_selectedRequestDate!.day}/${_selectedRequestDate!.month}/${_selectedRequestDate!.year}';

    // تأجيل تحميل العملاء حتى بعد بناء الـ widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomers();
    });
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _equipmentNameController.dispose();
    _locationController.dispose();
    _estimatedCostController.dispose();
    _notesController.dispose();
    _requestDateController.dispose();
    _scheduledDateController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const MaintenanceDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: MultiBlocListener(
        listeners: [
          BlocListener<MaintenanceBloc, MaintenanceState>(
            listenWhen: (previous, current) {
              return current is MaintenanceError ||
                  current is MaintenanceOperationSuccess ||
                  (current is MaintenanceLoaded && isSaving);
            },
            listener: (context, state) {
              if (state is MaintenanceOperationSuccess &&
                  !_operationCompleted) {
                _operationCompleted = true;

                final message = state.message;

                if (isSaving) {
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
              } else if (state is MaintenanceLoaded &&
                  isSaving &&
                  !_operationCompleted) {
                _operationCompleted = true;

                const message = 'تم إنشاء طلب الصيانة بنجاح';

                completeSaveOperation(
                  successMessage: message,
                  navigateBackOnSuccess: true,
                );
              } else if (state is MaintenanceError && !_operationCompleted) {
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
            listener: (context, state) {
              if (state is CustomerLoaded) {
                setState(() {
                  _customers = state.customers;
                  _filteredCustomers = List.from(_customers);
                });
              }
            },
          ),
        ],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildWelcomeCard(context),
              const SizedBox(height: 6),
              _buildFormCard(context),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة طلب صيانة جديد',
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
                  'نظام إدارة الصيانة الآشوري',
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
      title: 'إضافة طلب صيانة جديد',
      subtitle: 'إنشاء طلب صيانة جديد وإضافته إلى قاعدة البيانات',
      icon: Icons.build,
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
            title: 'معلومات الطلب',
            icon: Icons.title,
            children: [
              _buildTextField(
                controller: _titleController,
                label: 'عنوان الطلب *',
                icon: Icons.title,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'عنوان الطلب مطلوب';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _descriptionController,
                label: 'وصف المشكلة *',
                icon: Icons.description,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'وصف المشكلة مطلوب';
                  }
                  return null;
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'تفاصيل الطلب',
            icon: Icons.build,
            children: [
              _buildPriorityDropdown(),
              _buildTextField(
                controller: _equipmentNameController,
                label: 'اسم المعدة',
                icon: Icons.precision_manufacturing,
              ),
              _buildTextField(
                controller: _locationController,
                label: 'الموقع',
                icon: Icons.location_on,
              ),
              _buildTextField(
                controller: _estimatedCostController,
                label: 'التكلفة المتوقعة',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_formattingService.getPriceInputFormatter()],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'التواريخ',
            icon: Icons.date_range,
            children: [
              _buildDateField(
                controller: _requestDateController,
                label: 'تاريخ الطلب *',
                icon: Icons.calendar_today,
                onTap: () => _selectDate(context, true),
              ),
              _buildDateField(
                controller: _scheduledDateController,
                label: 'تاريخ الصيانة المجدولة',
                icon: Icons.schedule,
                onTap: () => _selectDate(context, false),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'ملاحظات',
            icon: Icons.note,
            children: [
              _buildTextField(
                controller: _notesController,
                label: 'ملاحظات إضافية',
                icon: Icons.note,
                maxLines: 3,
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: LoadingButton(
                  text: 'إنشاء طلب الصيانة',
                  onPressed: isSaving ? null : _createMaintenanceRequest,
                  isLoading: isSaving,
                  icon: Icons.build,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving
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
                          });
                          SuggestionsOverlay.hide();
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
                    _selectedCustomer = null;
                    SuggestionsOverlay.hide();
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
                      SuggestionsOverlay.hide();
                    } else {
                      _selectedCustomer = null;
                      // Show suggestions using SuggestionsOverlay
                      SuggestionsOverlay.hide();
                      final suggestions = _filteredCustomers
                          .map(
                            (c) => c.toSuggestionItem(
                              formatCurrency: _formattingService.formatCurrency,
                            ),
                          )
                          .toList();
                      SuggestionsOverlay.show(
                        context: context,
                        anchorKey: _customerFieldKey,
                        layerLink: _customerLayerLink,
                        suggestions: suggestions,
                        onSuggestionSelected: (selectedValue) {
                          final customer = _filteredCustomers.firstWhere(
                            (c) => c.name == selectedValue,
                          );
                          setState(() {
                            _selectedCustomer = customer;
                            _customerSearchController.text = customer.name;
                          });
                        },
                        maxHeight: 200.h,
                      );
                    }
                  }
                });
              },
              onTap: () {
                if (_customerSearchController.text.isNotEmpty &&
                    _filteredCustomers.isNotEmpty) {
                  final suggestions = _filteredCustomers
                      .map(
                        (c) => c.toSuggestionItem(
                          formatCurrency: _formattingService.formatCurrency,
                        ),
                      )
                      .toList();
                  SuggestionsOverlay.show(
                    context: context,
                    anchorKey: _customerFieldKey,
                    layerLink: _customerLayerLink,
                    suggestions: suggestions,
                    onSuggestionSelected: (selectedValue) {
                      final customer = _filteredCustomers.firstWhere(
                        (c) => c.name == selectedValue,
                      );
                      setState(() {
                        _selectedCustomer = customer;
                        _customerSearchController.text = customer.name;
                      });
                    },
                    maxHeight: 200.h,
                  );
                }
              },
            ),
          ),
        ),

        // عرض العميل المحدد
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: _isCustomerExceedingLimit(_selectedCustomer!)
                  ? Colors.red.withValues(alpha: 0.1)
                  : AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: _isCustomerExceedingLimit(_selectedCustomer!)
                    ? Colors.red
                    : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isCustomerExceedingLimit(_selectedCustomer!)
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle,
                  color: _isCustomerExceedingLimit(_selectedCustomer!)
                      ? Colors.red
                      : Colors.green,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العميل المحدد: ${_selectedCustomer!.name}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _isCustomerExceedingLimit(_selectedCustomer!)
                              ? Colors.red
                              : AssyrianTheme.deepBlue,
                        ),
                      ),
                      Text(
                        'سيتم إنشاء فاتورة صيانة لهذا العميل',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _isCustomerExceedingLimit(_selectedCustomer!)
                              ? Colors.red[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
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

  Widget _buildPriorityDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPriority,
      decoration: InputDecoration(
        labelText: 'الأولوية *',
        prefixIcon: Icon(
          Icons.priority_high,
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
      items: _priorities.map((priority) {
        return DropdownMenuItem<String>(
          value: priority['id'],
          child: Row(
            children: [
              Container(
                width: 12.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: priority['color'],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Text(priority['name']),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedPriority = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'الأولوية مطلوبة';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
        suffixIcon: Icon(
          Icons.calendar_today,
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
      validator: label.contains('*')
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'التاريخ مطلوب';
              }
              return null;
            }
          : null,
    );
  }

  Future<void> _selectDate(BuildContext context, bool isRequestDate) async {
    var picked = await showDatePicker(
      context: context,
      initialDate: isRequestDate
          ? (_selectedRequestDate ?? DateTime.now())
          : (_selectedScheduledDate ?? DateTime.now()),
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
        if (isRequestDate) {
          _selectedRequestDate = picked;
          _requestDateController.text =
              '${picked.day}/${picked.month}/${picked.year}';
        } else {
          _selectedScheduledDate = picked;
          _scheduledDateController.text =
              '${picked.day}/${picked.month}/${picked.year}';
        }
      });
    }
  }

  Future<void> _createMaintenanceRequest() async {
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

    // ⚠️ ملاحظة للمبرمجين المستقبليين: DateTime.now() يُستدعي مرة واحدة فقط
    // لضمان أن الطابع الزمني والجزء العشوائي من نفس اللحظة وتجنب التصادم عند
    // إنشاء طلبين في نفس الملي ثانية. لا تُقسم إلى استدعاءين منفصلين.
    final now = DateTime.now();

    final maintenanceRequest = MaintenanceRequestEntity(
      // ⚠️ ملاحظة للمبرمجين المستقبليين: المعرف مبني على الوقت بالملي ثانية والميكروثانية،
      // مما يضمن الفريدة حتى عند إنشاء طلبين في نفس الملي ثانية.
      id: '${now.millisecondsSinceEpoch}${now.microsecond}',
      organizationEmail: currentUser.email!,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      status: 'pending',
      // ⚠️ ملاحظة للمبرمجين المستقبليين: التحقق من النموذج يضمن اختيار الأولوية،
      // ولكن يُفضل عدم استخدام ! مباشرة لتجنب استثناء محتمل إذا تجاوز التحقق.
      priority: _selectedPriority ?? 'medium',
      requestDate: _selectedRequestDate!,
      requestedBy: createdBy,
      customerId: _selectedCustomer?.id, // ربط العميل
      customerName: _selectedCustomer?.name, // اسم العميل
      equipmentName: _equipmentNameController.text.trim().isEmpty
          ? null
          : _equipmentNameController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      scheduledDate: _selectedScheduledDate,
      estimatedCost: _estimatedCostController.text.trim().isEmpty
          ? null
          : double.tryParse(
              _estimatedCostController.text.trim().replaceAll(',', ''),
            ),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    // نسجل موافقة المستخدم لتخطي فحص الحد المكرر عند حفظ الفاتورة.
    var skipInvoiceCreditCheck = false;

    // التحقق من حد الائتمان قبل الحفظ
    if (_selectedCustomer != null && maintenanceRequest.estimatedCost != null) {
      final currentDebt = _selectedCustomer!.totalDebt;
      final creditLimit = _selectedCustomer!.creditLimit ?? 0;
      final maintenanceCost = maintenanceRequest.estimatedCost!;
      final newDebt = currentDebt + maintenanceCost;

      // إذا تجاوز حد الائتمان، عرض تحذير
      if (creditLimit > 0 && newDebt > creditLimit) {
        if (mounted) {
          final shouldContinue = await CreditLimitWarningDialog.show(
            context,
            customerName: _selectedCustomer!.name,
            currentDebt: currentDebt,
            creditLimit: creditLimit,
            invoiceAmount: maintenanceCost,
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
                          'تم إلغاء العملية - لم يتم إنشاء طلب الصيانة',
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

    // الحصول على مرجع لـ MaintenanceBloc قبل العملية غير المتزامنة
    final maintenanceBloc = context.read<MaintenanceBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        maintenanceBloc.add(
          CreateMaintenanceRequestEvent(
            maintenanceRequest,
            skipInvoiceCreditCheck: skipInvoiceCreditCheck,
          ),
        );
      },
      successMessage: 'تم إنشاء طلب الصيانة بنجاح',
      loadingMessage: 'جاري إنشاء طلب الصيانة...',
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
