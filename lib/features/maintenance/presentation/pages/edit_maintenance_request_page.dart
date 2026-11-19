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
import '../../domain/entities/maintenance_request_entity.dart';
import '../bloc/maintenance_bloc.dart';
import '../widgets/delete_maintenance_dialog.dart';
import '../widgets/maintenance_drawer.dart';

/// صفحة تعديل طلب الصيانة
class EditMaintenanceRequestPage extends StatefulWidget {
  const EditMaintenanceRequestPage({
    required this.maintenanceRequest,
    super.key,
  });
  final MaintenanceRequestEntity maintenanceRequest;

  @override
  State<EditMaintenanceRequestPage> createState() =>
      _EditMaintenanceRequestPageState();
}

class _EditMaintenanceRequestPageState extends State<EditMaintenanceRequestPage>
    with SaveOperationMixin<EditMaintenanceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();

  // Controllers للحقول النصية
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _locationController = TextEditingController();
  final _estimatedCostController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedPriority;
  String? _selectedStatus;

  // قوائم البيانات
  final List<Map<String, dynamic>> _priorities = [
    {'id': 'low', 'name': 'منخفضة', 'color': Colors.green},
    {'id': 'medium', 'name': 'متوسطة', 'color': Colors.orange},
    {'id': 'high', 'name': 'عالية', 'color': Colors.red},
    {'id': 'urgent', 'name': 'عاجلة', 'color': Colors.purple},
  ];

  final List<Map<String, dynamic>> _statuses = [
    {'id': 'pending', 'name': 'في الانتظار', 'color': Colors.orange},
    {'id': 'in_progress', 'name': 'قيد التنفيذ', 'color': Colors.blue},
    {'id': 'completed', 'name': 'مكتملة', 'color': Colors.green},
    {'id': 'cancelled', 'name': 'ملغية', 'color': Colors.red},
  ];

  // متغير لتتبع التغييرات
  bool _hasChanges = false;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  // متغيرات لأسماء المستخدمين
  String? _createdByName;
  String? _updatedByName;

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
  }

  void _loadCustomers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<CustomerBloc>().add(LoadCustomersEvent(user.email!));
    }
  }

  void _initializeFields() {
    _titleController.text = widget.maintenanceRequest.title;
    _descriptionController.text = widget.maintenanceRequest.description;
    _equipmentController.text = widget.maintenanceRequest.equipmentName ?? '';
    _locationController.text = widget.maintenanceRequest.location ?? '';
    _estimatedCostController.text = _formattingService.formatNumber(
      widget.maintenanceRequest.estimatedCost ?? 0.0,
    );
    _selectedPriority = widget.maintenanceRequest.priority;
    _selectedStatus = widget.maintenanceRequest.status;
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _equipmentController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _estimatedCostController.addListener(_onFieldChanged);
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
    _equipmentController.dispose();
    _locationController.dispose();
    _estimatedCostController.dispose();
    _customerSearchController.dispose();
    SuggestionsOverlay.hide();
    super.dispose();
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
        });
      },
      maxHeight: 200.h,
    );
  }

  /// إخفاء اقتراحات العملاء
  void _hideCustomerSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  /// تحميل أسماء المستخدمين للإنشاء والتحديث
  Future<void> _loadUserNames() async {
    // ⚡ تحسين الأداء: تحميلا الاسمين مستقلان —
    // يُنفذان بالتوازي عبر Future.wait بدلاً
    // من الانتظار المتسلسل (زمن التحميل ≈
    // أبطأ تحميل فقط).
    final results = await Future.wait<String?>([
      widget.maintenanceRequest.createdBy != null
          ? _getUserNameFromFirebase(widget.maintenanceRequest.createdBy!)
          : Future.value(_createdByName),
      widget.maintenanceRequest.updatedBy != null
          ? _getUserNameFromFirebase(widget.maintenanceRequest.updatedBy!)
          : Future.value(_updatedByName),
    ]);
    _createdByName = results[0];
    _updatedByName = results[1];
    if (mounted) {
      setState(() {});
    }
  }

  /// جلب اسم المستخدم من Firebase باستخدام UID
  ///
  // ⚠️ ملاحظة للمبرمجين المستقبليين: هذه الصفحة تستخدم مسار Firestore
  // مختلف عن بقية صفحات الصيانة (users/{uid} بدلاً من
  // {normalizedEmail}/users/users/{uid}). تم الإبقاء على المسار كما هو
  // لتجنب كسر البيانات المخزنة بالفعل. إذا تم unification هيكلةFirestore
  // مستقبلاً، حدّث هذا المسار ليستخدم EmailNormalizationService
  // مثل edit_maintenance_request_page و maintenance_details_page.
  Future<String?> _getUserNameFromFirebase(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        // تطبيع البريد الإلكتروني
        final emailService = EmailNormalizationService();
        final email = emailService.normalize(data?['email'] ?? '');
        return data?['name'] ?? email.split('@').first;
      }
    } on Exception catch (_) {
      // في حالة حدوث خطأ، نعود إلى القيمة الافتراضية
    }
    return null;
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
            onPressed: () async {
              Navigator.of(context).pop(false);
              // ⚠️ ملاحظة للمبرمجين المستقبليين: await ضروري قبل pop لضمان إكتمال الحفظ
              // قبل إغلاق الصفحة. بدون await قد يُفقد التحديث إذا تأخرت الاستجابة.
              await _updateMaintenanceRequest();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
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
        drawer: const MaintenanceDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: BlocConsumer<MaintenanceBloc, MaintenanceState>(
          listenWhen: (previous, current) {
            return current is MaintenanceError ||
                current is MaintenanceOperationSuccess ||
                (current is MaintenanceLoaded && isSaving);
          },
          listener: (context, state) {
            if (state is MaintenanceLoaded &&
                isSaving &&
                !_operationCompleted) {
              _operationCompleted = true;
              completeSaveOperation(
                successMessage: 'تم تحديث طلب الصيانة بنجاح',
                navigateBackOnSuccess: true,
              );
            } else if (state is MaintenanceError && !_operationCompleted) {
              _operationCompleted = true;
              failSaveOperation(errorMessage: state.message);
            } else if (state is MaintenanceOperationSuccess &&
                !_operationCompleted) {
              _operationCompleted = true;
              if (state.message.contains('حذف')) {
                Navigator.of(context).pop('deleted');
              } else {
                completeSaveOperation(
                  successMessage: state.message,
                  navigateBackOnSuccess: true,
                );
              }
            }
          },
          builder: (context, state) {
            final isLoading = state is MaintenanceLoading;

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
              'تعديل طلب الصيانة',
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
            onPressed: _updateMaintenanceRequest,
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
      title: 'تعديل ${widget.maintenanceRequest.title}',
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
              // عرض معلومات العميل المرتبط إذا كان موجود
              if (widget.maintenanceRequest.customerId != null &&
                  widget.maintenanceRequest.customerName != null) ...[
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
                              'مرتبط بعميل: ${widget.maintenanceRequest.customerName}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AssyrianTheme.deepBlue,
                              ),
                            ),
                            Text(
                              'معرف العميل: ${widget.maintenanceRequest.customerId}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (widget.maintenanceRequest.estimatedCost !=
                                    null &&
                                widget.maintenanceRequest.estimatedCost! > 0)
                              Text(
                                'تم إنشاء فاتورة صيانة لهذا العميل',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.green[700],
                                  fontStyle: FontStyle.italic,
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
              _buildTitleField(),
              _buildDescriptionField(),
              _buildEquipmentField(),
              _buildLocationField(),
            ],
          ),
          const SizedBox(height: 16),

          InfoCard(
            title: 'تفاصيل الطلب',
            icon: Icons.build,
            children: [
              _buildPriorityDropdown(),
              _buildStatusDropdown(),
              _buildEstimatedCostField(),
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

  Widget _buildCustomerSearchField() {
    return CompositedTransformTarget(
      link: _customerLayerLink,
      child: Container(
        key: _customerFieldKey,
        child: TextFormField(
          controller: _customerSearchController,
          decoration: InputDecoration(
            labelText: 'البحث عن عميل (اختياري)',
            hintText: 'ابحث عن عميل لربطه بهذا الطلب...',
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

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'عنوان طلب الصيانة *',
        hintText: 'أدخل عنوان الطلب',
        prefixIcon: const Icon(Icons.title, color: AssyrianTheme.primaryGold),
        suffixIcon: _titleController.text != widget.maintenanceRequest.title
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
          return 'يجب إدخال عنوان الطلب';
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
        labelText: 'وصف المشكلة *',
        hintText: 'اشرح المشكلة بالتفصيل',
        prefixIcon: const Icon(
          Icons.description,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon:
            _descriptionController.text != widget.maintenanceRequest.description
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
          return 'يجب إدخال وصف المشكلة';
        }
        return null;
      },
    );
  }

  Widget _buildEquipmentField() {
    return TextFormField(
      controller: _equipmentController,
      decoration: InputDecoration(
        labelText: 'المعدة أو الجهاز',
        hintText: 'اسم المعدة التي تحتاج صيانة',
        prefixIcon: const Icon(Icons.build, color: AssyrianTheme.primaryGold),
        suffixIcon:
            _equipmentController.text !=
                (widget.maintenanceRequest.equipmentName ?? '')
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

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: InputDecoration(
        labelText: 'الموقع',
        hintText: 'موقع المعدة أو المشكلة',
        prefixIcon: const Icon(
          Icons.location_on,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon:
            _locationController.text !=
                (widget.maintenanceRequest.location ?? '')
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

  Widget _buildPriorityDropdown() {
    return DropdownButtonFormField<String>(
      initialValue:
          _priorities.any((priority) => priority['id'] == _selectedPriority)
          ? _selectedPriority
          : null,
      decoration: InputDecoration(
        labelText: 'الأولوية *',
        hintText: 'اختر مستوى الأولوية',
        prefixIcon: const Icon(
          Icons.priority_high,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _selectedPriority != widget.maintenanceRequest.priority
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
      items: _priorities
          .map(
            (priority) => DropdownMenuItem<String>(
              value: priority['id'],
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: priority['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(priority['name']),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedPriority = value;
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار الأولوية';
        }
        return null;
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _statuses.any((status) => status['id'] == _selectedStatus)
          ? _selectedStatus
          : null,
      decoration: InputDecoration(
        labelText: 'الحالة *',
        hintText: 'اختر حالة الطلب',
        prefixIcon: const Icon(Icons.info, color: AssyrianTheme.primaryGold),
        suffixIcon: _selectedStatus != widget.maintenanceRequest.status
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
      items: _statuses
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
          _selectedStatus = value;
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار الحالة';
        }
        return null;
      },
    );
  }

  Widget _buildEstimatedCostField() {
    return TextFormField(
      controller: _estimatedCostController,
      keyboardType: TextInputType.number,
      inputFormatters: [_formattingService.getPriceInputFormatter()],
      decoration: InputDecoration(
        labelText: 'التكلفة المتوقعة',
        hintText: 'أدخل التكلفة المتوقعة (اختياري)',
        prefixIcon: const Icon(
          Icons.attach_money,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'د.ع',
        suffixIcon:
            _estimatedCostController.text !=
                _formattingService.formatNumber(
                  widget.maintenanceRequest.estimatedCost ?? 0.0,
                )
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
          final cost = double.tryParse(value.replaceAll(',', ''));
          if (cost == null) {
            return 'يجب إدخال رقم صحيح';
          }
          if (cost < 0) {
            return 'يجب أن تكون التكلفة أكبر من أو تساوي صفر';
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
            DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(widget.maintenanceRequest.createdAt),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow('تم الإنشاء بواسطة', _createdByName ?? 'غير محدد'),
          if (widget.maintenanceRequest.updatedAt != null) ...[
            const SizedBox(height: 8),
            _buildReadOnlyRow(
              'آخر تحديث',
              DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(widget.maintenanceRequest.updatedAt!),
            ),
          ],
          if (widget.maintenanceRequest.updatedBy != null) ...[
            const SizedBox(height: 8),
            _buildReadOnlyRow(
              'تم التحديث بواسطة',
              _updatedByName ?? widget.maintenanceRequest.updatedBy!,
            ),
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
                onPressed: _hasChanges ? _updateMaintenanceRequest : null,
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
                label: const Text('حذف الطلب'),
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
                    AppRoutes.maintenanceDetails,
                    arguments: widget.maintenanceRequest,
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

  Future<void> _updateMaintenanceRequest() async {
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

    final updatedMaintenanceRequest = widget.maintenanceRequest.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      equipmentName: _equipmentController.text.trim().isEmpty
          ? null
          : _equipmentController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      priority: _selectedPriority,
      status: _selectedStatus,
      estimatedCost: _estimatedCostController.text.trim().isEmpty
          ? null
          : double.tryParse(
              _estimatedCostController.text.trim().replaceAll(',', ''),
            ),
      customerId: _selectedCustomer?.id ?? widget.maintenanceRequest.customerId,
      customerName:
          _selectedCustomer?.name ?? widget.maintenanceRequest.customerName,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ MaintenanceBloc قبل العملية غير المتزامنة
    final maintenanceBloc = context.read<MaintenanceBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        maintenanceBloc.add(
          UpdateMaintenanceRequestEvent(updatedMaintenanceRequest),
        );
      },
      successMessage: 'تم تحديث طلب الصيانة بنجاح',
      loadingMessage: 'جاري تحديث طلب الصيانة...',
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
    DeleteMaintenanceDialog.show(
      context,
      widget.maintenanceRequest,
      context.read<MaintenanceBloc>(),
      onDeleted: () {
        // العودة إلى الصفحة السابقة بعد الحذف
        Navigator.of(context).pop('deleted');
      },
    );
  }
}
