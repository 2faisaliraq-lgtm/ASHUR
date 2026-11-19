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
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/delete_subscription_type_dialog.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة تفاصيل نوع الاشتراك
class SubscriptionTypeDetailsPage extends StatefulWidget {
  const SubscriptionTypeDetailsPage({
    required this.subscriptionType,
    super.key,
  });
  final SubscriptionTypeEntity subscriptionType;

  @override
  State<SubscriptionTypeDetailsPage> createState() =>
      _SubscriptionTypeDetailsPageState();
}

class _SubscriptionTypeDetailsPageState
    extends State<SubscriptionTypeDetailsPage> {
  late SubscriptionTypeEntity _subscriptionType;

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  String? _createdByName;
  String? _updatedByName;

  @override
  void initState() {
    super.initState();
    _subscriptionType = widget.subscriptionType;
    _loadPermissions();
    _loadUserNames();
  }

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission(
      'subscriptions_edit',
    );

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const SubscriptionDrawer(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            _buildSubscriptionTypeHeader(),
            const SizedBox(height: 6),
            _buildBasicInfoCard(),
            const SizedBox(height: 6),
            _buildFeaturesCard(),
            const SizedBox(height: 6),
            _buildActionsCard(),
          ],
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
              'تفاصيل نوع الاشتراك',
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
              final bloc = context.read<SubscriptionBloc>();
              final currentType = _subscriptionType;
              final result = await Navigator.of(context).pushNamed(
                AppRoutes.editSubscriptionType,
                arguments: currentType,
              );
              if (!mounted) return;
              if (result is SubscriptionTypeEntity) {
                setState(() => _subscriptionType = result);
                _loadUserNames();
              }
              bloc.add(const LoadSubscriptionTypesEvent());
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل نوع الاشتراك',
          ),
      ],
    );
  }

  Widget _buildSubscriptionTypeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            AssyrianTheme.deepBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.category,
              size: 32.sp,
              color: AssyrianTheme.primaryGold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subscriptionType.name,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subscriptionType.description,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.subscriptionType.isActive
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.subscriptionType.isActive ? 'نشط' : 'غير نشط',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: widget.subscriptionType.isActive
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formattingService.formatCurrency(
                          widget.subscriptionType.price,
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AssyrianTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildCard(
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline,
      children: [
        _buildInfoRow('اسم النوع', widget.subscriptionType.name),
        _buildInfoRow('الوصف', widget.subscriptionType.description),
        _buildInfoRow(
          'السعر',
          _formattingService.formatCurrency(widget.subscriptionType.price),
        ),
        _buildInfoRow('المدة', _getDurationText()),
        if (widget.subscriptionType.customDays != null)
          _buildInfoRow(
            'عدد الأيام المخصصة',
            '${widget.subscriptionType.customDays} يوم',
          ),
        _buildActivationQuantityRow(),
        _buildStatusRow(
          'الحالة',
          widget.subscriptionType.isActive ? 'نشط' : 'غير نشط',
          widget.subscriptionType.isActive ? Colors.green : Colors.red,
        ),
        const Divider(height: 24),
        if (widget.subscriptionType.createdAt != null)
          _buildInfoRow(
            'تاريخ الإنشاء',
            _formattingService.formatDate(widget.subscriptionType.createdAt!),
          ),
        _buildInfoRow('أنشئ بواسطة', _createdByName ?? 'غير محدد'),
        if (widget.subscriptionType.updatedBy != null)
          _buildInfoRow(
            'آخر تحديث بواسطة',
            _updatedByName ?? widget.subscriptionType.updatedBy!,
          ),
      ],
    );
  }

  Widget _buildActivationQuantityRow() {
    final quantity = widget.subscriptionType.activationQuantity;
    final hasActivations = quantity > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              'التفعيلات المتبقية',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasActivations
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasActivations ? Icons.check_circle : Icons.warning,
                        size: 14.sp,
                        color: hasActivations ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '$quantity تفعيلة',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: hasActivations ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/subscriptions/recharge-activations',
                      arguments: widget.subscriptionType,
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_shopping_cart, size: 14.sp),
                      SizedBox(width: 4.w),
                      Text('شحن', style: TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return _buildCard(
      title: 'الميزات المتاحة',
      icon: Icons.star,
      children: [
        if (widget.subscriptionType.features.isEmpty)
          Text(
            'لا توجد ميزات محددة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...widget.subscriptionType.features.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16.sp),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildActionsCard() {
    return _buildCard(
      title: 'الإجراءات',
      icon: Icons.settings,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.editSubscriptionType,
                    arguments: widget.subscriptionType,
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('تعديل النوع'),
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
                  // Copy functionality placeholder
                },
                icon: const Icon(Icons.copy),
                label: const Text('نسخ'),
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
                onPressed: _showToggleStatusDialog,
                icon: Icon(
                  widget.subscriptionType.isActive
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                label: Text(
                  widget.subscriptionType.isActive ? 'إيقاف' : 'تفعيل',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.subscriptionType.isActive
                      ? Colors.orange
                      : Colors.green,
                  side: BorderSide(
                    color: widget.subscriptionType.isActive
                        ? Colors.orange
                        : Colors.green,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showDeleteDialog,
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

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AssyrianTheme.primaryGold, size: 20.sp),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: AssyrianTheme.deepBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// تحميل أسماء المستخدمين من Firebase
  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ العنصر
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null &&
          switchedUser['id'] == widget.subscriptionType.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await _getUserNameFromFirebase(
        widget.subscriptionType.createdBy,
      );
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(
        widget.subscriptionType.createdBy,
      );
    }

    // تحميل اسم المستخدم الذي حدّث العنصر
    String? updatedByName;
    if (widget.subscriptionType.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null &&
            switchedUser['id'] == widget.subscriptionType.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await _getUserNameFromFirebase(
          widget.subscriptionType.updatedBy!,
        );
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(
          widget.subscriptionType.updatedBy!,
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

  String _getDurationText() {
    switch (widget.subscriptionType.duration) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربع سنوي';
      case 'yearly':
        return 'سنوي';
      case 'custom':
        return 'مخصص';
      default:
        return 'غير محدد';
    }
  }

  void _showToggleStatusDialog() {
    final action = widget.subscriptionType.isActive ? 'إيقاف' : 'تفعيل';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action نوع الاشتراك'),
        content: Text('هل تريد $action هذا النوع من الاشتراك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Toggle status functionality placeholder
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    DeleteSubscriptionTypeDialog.show(
      context,
      widget.subscriptionType,
      context.read<SubscriptionBloc>(),
      onDeleted: () {
        Navigator.of(context).pop();
      },
    );
  }
}
