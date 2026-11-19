import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../domain/entities/maintenance_request_entity.dart';
import '../bloc/maintenance_bloc.dart';
import '../widgets/maintenance_drawer.dart';

/// صفحة تفاصيل طلب الصيانة
class MaintenanceDetailsPage extends StatefulWidget {
  const MaintenanceDetailsPage({required this.maintenance, super.key});
  final MaintenanceRequestEntity maintenance;

  @override
  State<MaintenanceDetailsPage> createState() => _MaintenanceDetailsPageState();
}

class _MaintenanceDetailsPageState extends State<MaintenanceDetailsPage> {
  late MaintenanceRequestEntity _maintenance;

  void _applyUpdatedMaintenance(MaintenanceRequestEntity maintenance) {
    if (!mounted ||
        maintenance.id != _maintenance.id ||
        maintenance == _maintenance) {
      return;
    }
    setState(() => _maintenance = maintenance);
    _loadUserNames();
  }

  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool? _hasCustomerPermission;
  String? _createdByName;
  String? _updatedByName;
  String? _requestedByName;
  MaintenanceBloc? _maintenanceBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _maintenanceBloc = context.read<MaintenanceBloc>();
  }

  @override
  void initState() {
    super.initState();
    _maintenance = widget.maintenance;
    _loadRelatedData();
    _loadPermissions();
    _loadCustomerPermission();
    _loadUserNames();

    // بدء الاستماع للتحديثات الفورية لطلبات الصيانة
    final maintenanceBloc = context.read<MaintenanceBloc>();
    maintenanceBloc.add(
      StartMaintenanceStreamEvent(
        organizationEmail: _maintenance.organizationEmail,
      ),
    );
  }

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission('maintenance_edit');

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
      });
    }
  }

  /// تحميل صلاحية الوصول إلى العملاء
  Future<void> _loadCustomerPermission() async {
    final hasPermission = await _permissionChecker.hasPermission(
      'customers_view',
    );

    if (mounted) {
      setState(() {
        _hasCustomerPermission = hasPermission;
      });
    }
  }

  void _loadRelatedData() {
    // تحميل البيانات المرتبطة إذا كانت متاحة
    final state = context.read<MaintenanceBloc>().state;
    if (state is MaintenanceLoaded) {
      // يمكن إضافة منطق لتحميل بيانات مرتبطة هنا
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MaintenanceBloc, MaintenanceState>(
      listener: (context, state) {
        if (state is MaintenanceLoaded || state is MaintenanceStreamActive) {
          final requests = state is MaintenanceLoaded
              ? state.requests
              : (state as MaintenanceStreamActive).requests;
          for (final request in requests) {
            if (request.id == _maintenance.id) {
              _applyUpdatedMaintenance(request);
              break;
            }
          }
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const MaintenanceDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildMaintenanceHeader(),
              const SizedBox(height: 6),
              _buildBasicInfoCard(),
              const SizedBox(height: 6),
              _buildLocationInfoCard(),
              const SizedBox(height: 6),
              _buildTechnicianInfoCard(),
              const SizedBox(height: 6),
              _buildCostInfoCard(),
              const SizedBox(height: 6),
              _buildProgressCard(),
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
              'تفاصيل طلب الصيانة',
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
              final bloc = context.read<MaintenanceBloc>();
              final maintenance = _maintenance;
              final result = await Navigator.of(context).pushNamed(
                AppRoutes.editMaintenanceRequest,
                arguments: maintenance,
              );
              if (!mounted || result != true) return;
              bloc.add(
                LoadMaintenanceRequestsEvent(
                  maintenance.organizationEmail,
                  refresh: true,
                ),
              );
              bloc.add(
                StartMaintenanceStreamEvent(
                  organizationEmail: maintenance.organizationEmail,
                ),
              );
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل طلب الصيانة',
          ),
      ],
    );
  }

  Widget _buildMaintenanceHeader() {
    return DetailScreenHeader(
      title: _maintenance.title,
      subtitle: _maintenance.location ?? 'الموقع غير محدد',
      icon: Icons.build,
      iconBackgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      iconForegroundColor: AssyrianTheme.primaryGold,
    );
  }

  Widget _buildBasicInfoCard() {
    final canNavigateToCustomer = _hasCustomerPermission ?? false;

    return InfoCard(
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline,
      children: [
        // معلومات العميل المرتبط إذا كان موجود
        if (_maintenance.customerId != null &&
            _maintenance.customerName != null) ...[
          canNavigateToCustomer
              ? InkWell(
                  onTap: _navigateToCustomerDetails,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120.w,
                          child: Text(
                            'مرتبط بعميل',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _maintenance.customerName!,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AssyrianTheme.deepBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16.sp,
                          color: AssyrianTheme.primaryGold,
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120.w,
                        child: Text(
                          'مرتبط بعميل',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _maintenance.customerName!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AssyrianTheme.deepBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          SizedBox(height: 12.h),
        ],
        DetailRow(label: 'عنوان الطلب', value: _maintenance.title),
        const DetailRow(label: 'نوع الصيانة', value: 'طلب صيانة'),
        DetailRow(
          label: 'تاريخ الطلب',
          value: _formatDate(_maintenance.requestDate),
        ),
        if (_maintenance.scheduledDate != null)
          DetailRow(
            label: 'التاريخ المجدول',
            value: _formatDate(_maintenance.scheduledDate!),
          ),
        if (_maintenance.completedDate != null)
          DetailRow(
            label: 'تاريخ الإنجاز',
            value: _formatDate(_maintenance.completedDate!),
          ),
        DetailRow(label: 'الوصف', value: _maintenance.description),
      ],
    );
  }

  Widget _buildLocationInfoCard() {
    return InfoCard(
      title: 'معلومات الموقع',
      icon: Icons.location_on,
      children: [
        DetailRow(label: 'الموقع', value: _maintenance.location ?? 'غير محدد'),
        if (_maintenance.equipmentName != null &&
            _maintenance.equipmentName!.isNotEmpty)
          DetailRow(label: 'المعدة', value: _maintenance.equipmentName!),
      ],
    );
  }

  Widget _buildTechnicianInfoCard() {
    return InfoCard(
      title: 'معلومات الفني',
      icon: Icons.person_outline,
      children: [
        DetailRow(
          label: 'اسم الفني',
          value: _maintenance.assignedTo ?? 'لم يتم التعيين',
        ),
        if (_maintenance.notes != null && _maintenance.notes!.isNotEmpty)
          DetailRow(label: 'ملاحظات', value: _maintenance.notes!),
      ],
    );
  }

  Widget _buildCostInfoCard() {
    return InfoCard(
      title: 'معلومات التكلفة',
      icon: Icons.attach_money,
      children: [
        if (_maintenance.estimatedCost != null &&
            _maintenance.estimatedCost! > 0)
          AmountRow(
            label: 'التكلفة المقدرة',
            amount: _maintenance.estimatedCost!,
            color: Colors.blue,
          ),
        if (_maintenance.actualCost != null && _maintenance.actualCost! > 0)
          AmountRow(
            label: 'التكلفة الفعلية',
            amount: _maintenance.actualCost!,
            color: Colors.green,
          ),
        const Divider(),
        DetailRow(label: 'طلب بواسطة', value: _requestedByName ?? 'غير محدد'),
      ],
    );
  }

  Widget _buildProgressCard() {
    return InfoCard(
      title: 'تقدم العمل',
      icon: Icons.timeline,
      children: [
        StatusRow(
          label: 'الحالة الحالية',
          value: _getStatusText(_maintenance.status),
          color: _getStatusColor(_maintenance.status),
        ),
        StatusRow(
          label: 'الأولوية',
          value: _getPriorityText(_maintenance.priority),
          color: _getPriorityColor(_maintenance.priority),
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
          value: _formatDateTime(_maintenance.createdAt),
        ),
        DetailRow(label: 'أنشئ بواسطة', value: _createdByName ?? 'غير محدد'),
        if (_maintenance.updatedAt != null)
          DetailRow(
            label: 'آخر تحديث',
            value: _formatDateTime(_maintenance.updatedAt!),
          ),
        if (_maintenance.updatedBy != null)
          DetailRow(
            label: 'آخر تحديث بواسطة',
            value: _updatedByName ?? _maintenance.updatedBy!,
          ),
        if (_isOverdue())
          const StatusRow(
            label: 'تنبيه',
            value: 'الطلب متأخر عن الموعد المحدد',
            color: Colors.red,
          ),
        if (_isUrgent())
          const StatusRow(
            label: 'تنبيه',
            value: 'طلب عاجل يحتاج اهتمام فوري',
            color: Colors.orange,
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
                  final bloc = context.read<MaintenanceBloc>();
                  final maintenance = _maintenance;
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.editMaintenanceRequest,
                    arguments: maintenance,
                  );
                  if (!mounted || result != true) return;
                  bloc.add(
                    LoadMaintenanceRequestsEvent(
                      maintenance.organizationEmail,
                      refresh: true,
                    ),
                  );
                  bloc.add(
                    StartMaintenanceStreamEvent(
                      organizationEmail: maintenance.organizationEmail,
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('تعديل الطلب'),
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
                onPressed: () async {
                  final bloc = context.read<MaintenanceBloc>();
                  final maintenance = _maintenance;
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.editMaintenanceRequest,
                    arguments: maintenance,
                  );
                  if (!mounted || result != true) return;
                  bloc.add(
                    LoadMaintenanceRequestsEvent(
                      maintenance.organizationEmail,
                      refresh: true,
                    ),
                  );
                  bloc.add(
                    StartMaintenanceStreamEvent(
                      organizationEmail: maintenance.organizationEmail,
                    ),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('تعيين فني'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
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
                onPressed: () async {
                  final bloc = context.read<MaintenanceBloc>();
                  final maintenance = _maintenance;
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.editMaintenanceRequest,
                    arguments: maintenance,
                  );
                  if (!mounted || result != true) return;
                  bloc.add(
                    LoadMaintenanceRequestsEvent(
                      maintenance.organizationEmail,
                      refresh: true,
                    ),
                  );
                  bloc.add(
                    StartMaintenanceStreamEvent(
                      organizationEmail: maintenance.organizationEmail,
                    ),
                  );
                },
                icon: const Icon(Icons.update),
                label: const Text('تحديث الحالة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
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
                      content: Text('وظيفة طباعة التقرير غير متوفرة حالياً'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('طباعة تقرير'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// تحميل أسماء المستخدمين من Firebase
  Future<void> _loadUserNames() async {
    // ⚠️ ملاحظة للمبرمجين المستقبليين: القراءات الثلاث متوازية عبر Future.wait
    // بدلاً من التسلسل، لتقليل وقت التحميل ≈ أبطأ قراءة فقط.
    final results = await Future.wait<dynamic>([
      (_maintenance.createdBy != null && _maintenance.createdBy!.isNotEmpty)
          ? _loadUserNameHelper(_maintenance.createdBy!)
          : Future.value(null),
      (_maintenance.updatedBy != null)
          ? _loadUserNameHelper(_maintenance.updatedBy!)
          : Future.value(null),
      _loadUserNameHelper(_maintenance.requestedBy),
    ]);

    final createdByName = results[0] as String?;
    final updatedByName = results[1] as String?;
    final requestedByName = results[2] as String?;

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
        _updatedByName = updatedByName;
        _requestedByName = requestedByName ?? 'غير محدد';
      });
    }
  }

  /// تحميل اسم مستخدم واحد مع دعم SessionService و Firebase
  Future<String?> _loadUserNameHelper(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == userId) {
        return switchedUser['name'] as String?;
      }
    } on Exception {
      // تجاهل ومتابعة لـ Firebase
    }

    return _getUserNameFromFirebase(userId);
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

        final userDoc = await FirebaseFirestore.instance
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'في الانتظار';
      case 'assigned':
        return 'تم التعيين';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'on_hold':
        return 'معلق';
      default:
        // ⚠️ ملاحظة للمبرمجين المستقبليين: الحالات المسموحة في المدقق (MaintenanceValidator)
        // هي pending, in_progress, completed, cancelled فقط. الحالات assigned وon_hold
        // غير معتمدة في الطرح الأساسي ولكنها معروضة هنا للعرض فقط. لا تضف حالات جديدة
        // هنا دون تحديث المدقق ومتطلبات الانتقال في MaintenanceRequestEntity.allowedTransitions.
        // ✅ تم توثيق عدم المطابقة يدوياً (بدون تعديل أي منطق).
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'on_hold':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return 'منخفضة';
      case 'medium':
        return 'متوسطة';
      case 'high':
        return 'عالية';
      case 'urgent':
        return 'عاجل';
      case 'critical':
        return 'حرج';
      default:
        // ⚠️ ملاحظة للمبرمجين المستقبليين: الأولويات المسموحة في المدقق (MaintenanceValidator)
        // هي low, medium, high, urgent فقط. 'critical' غير معتمد في الطرح الأساسي ولكنها
        // معروضة هنا للعرض فقط. لا تضف أولويات جديدة هنا دون تحديث المدقق في
        // MaintenanceValidator._validateAllowedValues. ✅ تم توثيق عدم المطابقة يدوياً
        // (بدون تعديل أي منطق).
        return 'غير محدد';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.blue;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  bool _isOverdue() {
    if (_maintenance.scheduledDate == null) return false;
    final now = DateTime.now();
    return _maintenance.scheduledDate!.isBefore(now) &&
        _maintenance.status.toLowerCase() != 'completed';
  }

  bool _isUrgent() {
    return _maintenance.priority.toLowerCase() == 'urgent' ||
        _maintenance.priority.toLowerCase() == 'critical';
  }

  /// الانتقال إلى شاشة تفاصيل العميل
  Future<void> _navigateToCustomerDetails() async {
    if (_maintenance.customerId == null || _maintenance.customerId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد عميل مرتبط بطلب الصيانة'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final customerRepository = GetIt.instance<CustomerRepository>();

      // ⚡ تحسين الأداء: جلب مستند العميل الواحد بالمعرف
      // (قراءة O(1) لمستند واحد) بدلاً من تحميل كل
      // العملاء والبحث بينهم — نفس النتيجة ونفس
      // التنبيهات عند الفشل أو عدم الوجود.
      final customerResult = await customerRepository.getCustomerById(
        _maintenance.customerId!,
      );

      if (!mounted) return;

      await customerResult.fold(
        (failure) {
          if (mounted) {
            // getCustomerById يرجع "العميل غير موجود"
            // عند عدم الوجود — يُعرض بنفس التنبيه
            // البرتقالي السابق، وباقي الأخطاء تُعرض
            // بالأحمر كما كانت.
            final notFound = failure.message == 'العميل غير موجود';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  notFound
                      ? 'العميل غير موجود'
                      : 'فشل في جلب بيانات العميل: ${failure.message}',
                ),
                backgroundColor: notFound ? Colors.orange : Colors.red,
              ),
            );
          }
        },
        (customer) async {
          if (!mounted) return;

          await Navigator.of(
            context,
          ).pushNamed(AppRoutes.customerDetails, arguments: customer);
        },
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    // إيقاف الاستماع للتحديثات عند إغلاق الصفحة
    _maintenanceBloc?.add(const StopMaintenanceStreamEvent());
    super.dispose();
  }
}
