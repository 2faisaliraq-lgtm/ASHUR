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
import '../../domain/entities/rental_entity.dart';
import '../bloc/rental_bloc.dart';
import '../widgets/rental_drawer.dart';

/// صفحة تفاصيل عقد الإيجار
class RentalDetailsPage extends StatefulWidget {
  const RentalDetailsPage({required this.rental, super.key});
  final RentalEntity rental;

  @override
  State<RentalDetailsPage> createState() => _RentalDetailsPageState();
}

class _RentalDetailsPageState extends State<RentalDetailsPage> {
  late RentalEntity _rental;

  void _applyUpdatedRental(RentalEntity rental) {
    if (!mounted || rental.id != _rental.id || rental == _rental) return;
    setState(() => _rental = rental);
    _loadUserNames();
  }

  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool? _hasCustomerPermission;
  String? _createdByName;
  String? _updatedByName;
  RentalBloc? _rentalBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _rentalBloc = context.read<RentalBloc>();
  }

  @override
  void initState() {
    super.initState();
    _rental = widget.rental;
    _loadRelatedData();
    _loadPermissions();
    _loadCustomerPermission();
    _loadUserNames();

    // بدء الاستماع للتحديثات الفورية لعقود الإيجار
    final rentalBloc = context.read<RentalBloc>();
    rentalBloc.add(
      StartRentalsStreamEvent(organizationEmail: _rental.organizationEmail),
    );
  }

  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ العقد
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == _rental.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await _getUserNameFromFirebase(_rental.createdBy);
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(_rental.createdBy);
    }

    // تحميل اسم المستخدم الذي حدّث العقد
    String? updatedByName;
    if (_rental.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] == _rental.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await _getUserNameFromFirebase(_rental.updatedBy!);
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(_rental.updatedBy!);
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

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final emailService = EmailNormalizationService();
        final normalizedEmail = emailService.normalize(currentUser.email!);

        // ملاحظة للمبرمجين المستقبليين: يُستخدم المثيل المحقون عبر GetIt بدلاً من
        // FirebaseFirestore.instance للحفاظ على اتساق نمط الحقن المستخدم في القسم
        // وتمكين الاختبار بسهولة.
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

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission('rentals_edit');

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
    final state = context.read<RentalBloc>().state;
    if (state is RentalLoaded) {
      // يمكن إضافة منطق لتحميل بيانات مرتبطة هنا
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RentalBloc, RentalState>(
      listener: (context, state) {
        if (state is RentalLoaded || state is RentalsStreamActive) {
          final rentals = state is RentalLoaded
              ? state.rentals
              : (state as RentalsStreamActive).rentals;
          for (final rental in rentals) {
            if (rental.id == _rental.id) {
              _applyUpdatedRental(rental);
              break;
            }
          }
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const RentalDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildRentalHeader(),
              const SizedBox(height: 6),
              _buildBasicInfoCard(),
              const SizedBox(height: 6),
              _buildTenantInfoCard(),
              const SizedBox(height: 6),
              _buildPropertyInfoCard(),
              const SizedBox(height: 6),
              _buildFinancialInfoCard(),
              const SizedBox(height: 6),
              _buildContractInfoCard(),
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
              'تفاصيل عقد الإيجار',
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
                AppRoutes.editRental,
                arguments: _rental,
              );
              if (!mounted) return;
              if (result is RentalEntity) _applyUpdatedRental(result);
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل عقد الإيجار',
          ),
      ],
    );
  }

  Widget _buildRentalHeader() {
    return DetailScreenHeader(
      title: _rental.itemDescription ?? _rental.itemName,
      subtitle: _rental.renterName,
      icon: Icons.home_work,
      iconBackgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      iconForegroundColor: AssyrianTheme.primaryGold,
    );
  }

  Widget _buildBasicInfoCard() {
    return InfoCard(
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline,
      children: [
        DetailRow(label: 'اسم الشيء المؤجر', value: _rental.itemName),
        DetailRow(
          label: 'تاريخ بداية العقد',
          value: _formatDate(_rental.startDate),
        ),
        DetailRow(
          label: 'تاريخ انتهاء العقد',
          value: _formatDate(_rental.endDate),
        ),
        DetailRow(
          label: 'مدة العقد',
          value: '${_calculateContractDuration()} شهر',
        ),
        if (_rental.notes != null && _rental.notes!.isNotEmpty)
          DetailRow(label: 'ملاحظات', value: _rental.notes!),
      ],
    );
  }

  Widget _buildTenantInfoCard() {
    final canNavigateToCustomer = _hasCustomerPermission ?? false;

    return InfoCard(
      title: 'معلومات المستأجر',
      icon: Icons.person_outline,
      children: [
        // معلومات العميل المرتبط إذا كان موجود
        if (_rental.customerId != null && _rental.customerName != null) ...[
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
                            _rental.customerName!,
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
                          _rental.customerName!,
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
        DetailRow(label: 'اسم المستأجر', value: _rental.renterName),
        DetailRow(
          label: 'رقم الهاتف',
          value: _rental.renterPhone ?? 'غير محدد',
        ),
        if (_rental.renterEmail != null && _rental.renterEmail!.isNotEmpty)
          DetailRow(label: 'البريد الإلكتروني', value: _rental.renterEmail!),
      ],
    );
  }

  Widget _buildPropertyInfoCard() {
    return InfoCard(
      title: 'معلومات الشيء المؤجر',
      icon: Icons.home,
      children: [
        DetailRow(
          label: 'وصف الشيء',
          value: _rental.itemDescription ?? _rental.itemName,
        ),
      ],
    );
  }

  Widget _buildFinancialInfoCard() {
    return InfoCard(
      title: 'المعلومات المالية',
      icon: Icons.attach_money,
      children: [
        AmountRow(
          label: 'سعر الإيجار',
          amount: _rental.rentalPrice,
          color: Colors.green,
        ),
        AmountRow(
          label: 'التأمين/العربون',
          amount: _rental.deposit,
          color: Colors.blue,
        ),
        const Divider(),
        DetailRow(
          label: 'تكرار الدفع',
          value: _getPaymentFrequencyText(_rental.paymentFrequency),
        ),
        DetailRow(
          label: 'يوم الدفع',
          value:
              'يوم ${_rental.paymentDay} من كل ${_getPaymentPeriod(_rental.paymentFrequency)}',
        ),
      ],
    );
  }

  Widget _buildContractInfoCard() {
    return InfoCard(
      title: 'تفاصيل العقد',
      icon: Icons.description,
      children: [
        StatusRow(
          label: 'حالة العقد',
          value: _getStatusText(_rental.status),
          color: _getStatusColor(_rental.status),
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
          value: _formatDateTime(_rental.createdAt),
        ),
        DetailRow(label: 'أنشئ بواسطة', value: _createdByName ?? 'غير محدد'),
        if (_rental.updatedAt != null)
          DetailRow(
            label: 'آخر تحديث',
            value: _formatDateTime(_rental.updatedAt!),
          ),
        if (_rental.updatedBy != null)
          DetailRow(
            label: 'آخر تحديث بواسطة',
            value: _updatedByName ?? _rental.updatedBy!,
          ),
        if (_isContractExpiringSoon())
          const StatusRow(
            label: 'تنبيه',
            value: 'العقد ينتهي قريباً',
            color: Colors.orange,
          ),
        if (_isContractExpired())
          const StatusRow(
            label: 'تنبيه',
            value: 'العقد منتهي الصلاحية',
            color: Colors.red,
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
                    AppRoutes.editRental,
                    arguments: _rental,
                  );
                  if (!mounted) return;
                  if (result is RentalEntity) _applyUpdatedRental(result);
                },
                icon: const Icon(Icons.edit),
                label: const Text('تعديل العقد'),
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
                      content: Text('وظيفة طباعة العقد قيد التطوير'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('طباعة العقد'),
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
                      content: Text('وظيفة تجديد العقد قيد التطوير'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('تجديد العقد'),
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
                      content: Text('وظيفة إنهاء العقد قيد التطوير'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.close),
                label: const Text('إنهاء العقد'),
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'نشط';
      case 'expired':
        return 'منتهي';
      case 'terminated':
        return 'منتهي مبكراً';
      case 'pending':
        return 'في الانتظار';
      case 'draft':
        return 'مسودة';
      default:
        return 'غير محدد';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'terminated':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  int _calculateContractDuration() {
    final difference = _rental.endDate.difference(_rental.startDate);
    return (difference.inDays / 30).round();
  }

  bool _isContractExpiringSoon() {
    final now = DateTime.now();
    final daysUntilExpiry = _rental.endDate.difference(now).inDays;
    return daysUntilExpiry > 0 && daysUntilExpiry <= 30; // ينتهي خلال 30 يوم
  }

  bool _isContractExpired() {
    final now = DateTime.now();
    return _rental.endDate.isBefore(now);
  }

  String _getPaymentFrequencyText(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return 'يومياً';
      case 'weekly':
        return 'أسبوعياً';
      case 'monthly':
        return 'شهرياً';
      case 'quarterly':
        return 'ربع سنوي';
      case 'yearly':
        return 'سنوياً';
      default:
        return frequency;
    }
  }

  String _getPaymentPeriod(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return 'يوم';
      case 'weekly':
        return 'أسبوع';
      case 'monthly':
        return 'شهر';
      case 'quarterly':
        return 'ربع سنة';
      case 'yearly':
        return 'سنة';
      default:
        return 'فترة';
    }
  }

  /// الانتقال إلى شاشة تفاصيل العميل
  Future<void> _navigateToCustomerDetails() async {
    if (_rental.customerId == null || _rental.customerId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد عميل مرتبط بهذا العقد'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final customerRepository = GetIt.instance<CustomerRepository>();
      final customerResult = await customerRepository.getCustomers(
        _rental.organizationEmail,
      );

      if (!mounted) return;

      await customerResult.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في جلب بيانات العميل: ${failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        (customers) async {
          try {
            final customer = customers.firstWhere(
              (c) => c.id == _rental.customerId,
            );

            if (!mounted) return;

            await Navigator.of(
              context,
            ).pushNamed(AppRoutes.customerDetails, arguments: customer);
          } on Exception catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('العميل غير موجود'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
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
    _rentalBloc?.add(const StopRentalsStreamEvent());
    super.dispose();
  }
}
