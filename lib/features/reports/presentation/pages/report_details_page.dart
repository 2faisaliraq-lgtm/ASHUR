import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../app/routes/app_routes.dart';
import '../../domain/entities/report_entity.dart';
import '../bloc/report_bloc.dart';
import '../widgets/delete_report_dialog.dart';
import '../widgets/report_drawer.dart';

/// صفحة تفاصيل التقرير
class ReportDetailsPage extends StatefulWidget {
  const ReportDetailsPage({required this.report, super.key});
  final ReportEntity report;

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage>
    with SaveOperationMixin<ReportDetailsPage> {
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canDownload = false;
  bool _canShare = false;
  bool _canPrint = false;
  bool _isLoading = true;
  late ReportEntity _report;
  String? _createdByName;
  String? _updatedByName;
  String? _generatedByName;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadPermissions();
    _loadUserNames();
  }

  Future<void> _loadPermissions() async {
    // ⚠️ تم إضافة try/catch لمنع تعليق الشاشة على التحميل إلى الأبد
    // إذا حدث خطأ أثناء تحميل الصلاحيات. في حال الفشل، تُضبط جميع
    // الصلاحيات إلى false ويستمر عرض الصفحة بدلاً من التوقف على شاشة التحميل.
    try {
      final canEdit = await _permissionChecker.hasPermission('reports_edit');
      final canDelete = await _permissionChecker.hasPermission(
        'reports_delete',
      );
      final canDownload = await _permissionChecker.hasPermission(
        'reports_download',
      );
      final canShare = await _permissionChecker.hasPermission('reports_share');
      final canPrint = await _permissionChecker.hasPermission('reports_print');

      if (mounted) {
        setState(() {
          _canEdit = canEdit;
          _canDelete = canDelete;
          _canDownload = canDownload;
          _canShare = canShare;
          _canPrint = canPrint;
          _isLoading = false;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return scaffold.ResponsiveScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('جاري تحميل التصاريح...'),
        ),
        body: LoadingWidget(message: 'جاري التحميل...'),
      );
    }

    return BlocListener<ReportBloc, ReportState>(
      listener: (context, state) {
        if (state is ReportOperationSuccess &&
            state.message.contains('تحديث')) {
          final user = FirebaseAuth.instance.currentUser;
          if (user?.email != null) {
            context.read<ReportBloc>().add(
              LoadReportsEvent(
                EmailNormalizationService().normalize(user!.email!),
              ),
            );
          }
        } else if (state is ReportLoaded || state is ReportsStreamActive) {
          final reports = state is ReportLoaded
              ? state.reports
              : (state as ReportsStreamActive).reports;
          for (final report in reports) {
            if (report.id == _report.id && report != _report) {
              setState(() => _report = report);
              _loadUserNames();
              break;
            }
          }
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const ReportDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildReportHeader(),
              const SizedBox(height: 6),
              _buildBasicInfoCard(),
              const SizedBox(height: 6),
              _buildPeriodCard(),
              const SizedBox(height: 6),
              _buildDataCard(),
              const SizedBox(height: 6),
              _buildSystemInfoCard(),
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
              'تفاصيل التقرير',
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
              final result = await Navigator.of(
                context,
              ).pushNamed(AppRoutes.editReport, arguments: _report);
              if (!mounted) return;
              if (result is ReportEntity) {
                setState(() => _report = result);
                _loadUserNames();
              }
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل التقرير',
          ),
      ],
    );
  }

  Widget _buildReportHeader() {
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
              _getReportIcon(),
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
                  _report.title,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _report.description,
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
                        color: _getStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _getStatusColor(),
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
                        _getTypeText(),
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
        _buildInfoRow('عنوان التقرير', _report.title),
        _buildInfoRow('الوصف', _report.description),
        _buildInfoRow('نوع التقرير', _getTypeText()),
        _buildStatusRow('الحالة', _getStatusText(), _getStatusColor()),
        if (_report.generatedBy != null)
          _buildInfoRow('تم الإنشاء بواسطة', _generatedByName ?? 'غير محدد'),
      ],
    );
  }

  Widget _buildPeriodCard() {
    return _buildCard(
      title: 'فترة التقرير',
      icon: Icons.date_range,
      children: [
        _buildInfoRow('تاريخ البداية', _formatDate(_report.startDate)),
        _buildInfoRow('تاريخ النهاية', _formatDate(_report.endDate)),
        _buildInfoRow('مدة التقرير', _getReportDuration()),
      ],
    );
  }

  Widget _buildDataCard() {
    return _buildCard(
      title: 'بيانات التقرير',
      icon: Icons.data_usage,
      children: [
        if (_report.data.isEmpty)
          Text(
            'لا توجد بيانات متاحة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ..._report.data.entries.take(5).map((entry) {
            return _buildInfoRow(entry.key, entry.value.toString());
          }),
        if (_report.data.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'و ${_report.data.length - 5} عنصر إضافي...',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return _buildCard(
      title: 'معلومات النظام',
      icon: Icons.system_update,
      children: [
        _buildInfoRow('تاريخ الإنشاء', _formatDateTime(_report.createdAt)),
        _buildInfoRow('أنشئ بواسطة', _createdByName ?? 'غير محدد'),
        if (_report.generatedBy != null)
          _buildInfoRow('تم إنتاجه بواسطة', _generatedByName ?? 'غير محدد'),
        if (_report.completedAt != null)
          _buildInfoRow('تاريخ الإكمال', _formatDateTime(_report.completedAt!)),
        if (_report.updatedBy != null)
          _buildInfoRow(
            'آخر تحديث بواسطة',
            _updatedByName ?? _report.updatedBy!,
          ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return _buildCard(
      title: 'الإجراءات',
      icon: Icons.settings,
      children: [
        if (_canDownload || _canShare)
          Row(
            children: [
              if (_canDownload)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _report.isCompleted
                        ? () {
                            // ⚠️ وظيفة التحميل قيد التطوير — يحتاج تنفيذ المنطق الفعلي
                            // باستخدام صلاحية reports_download.
                          }
                        : null,
                    icon: const Icon(Icons.download),
                    label: const Text('تحميل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AssyrianTheme.primaryGold,
                      foregroundColor: AssyrianTheme.deepBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (_canDownload && _canShare) const SizedBox(width: 12),
              if (_canShare)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _report.isCompleted
                        ? () {
                            // ⚠️ وظيفة المشاركة قيد التطوير — يحتاج تنفيذ المنطق الفعلي
                            // باستخدام صلاحية reports_share.
                          }
                        : null,
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AssyrianTheme.primaryGold,
                      side: const BorderSide(color: AssyrianTheme.primaryGold),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        if ((_canDownload || _canShare) && (_canPrint || _canDelete))
          const SizedBox(height: 12),
        if (_canPrint || _canDelete)
          Row(
            children: [
              if (_canPrint)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // ⚠️ وظيفة الطباعة قيد التطوير — يحتاج تنفيذ المنطق الفعلي
                      // باستخدام صلاحية reports_print.
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (_canPrint && _canDelete) const SizedBox(width: 12),
              if (_canDelete)
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
        if (_report.isPending)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showRegenerateDialog,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة إنشاء التقرير'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// تحميل أسماء المستخدمين من Firebase
  Future<void> _loadUserNames() async {
    // ⚠️ تحميل الأسماء الثلاثة بالتوازي عبر Future.wait
    // بدلاً من التتابعي — كل اسم قراءة Firestore
    // مستقلة فالتوازي يختصر الزمن إلى زمن أبطأ
    // قراءة فقط بدلاً من مجموع الثلاث قراءات
    final createdBy = _report.createdBy;
    final updatedBy = _report.updatedBy;
    final generatedBy = _report.generatedBy;

    final names = await Future.wait([
      (createdBy != null && createdBy.isNotEmpty)
          ? _loadUserName(createdBy)
          : Future<String?>.value(null),
      updatedBy != null
          ? _loadUserName(updatedBy)
          : Future<String?>.value(null),
      generatedBy != null
          ? _loadUserName(generatedBy)
          : Future<String?>.value(null),
    ]);

    if (mounted) {
      setState(() {
        _createdByName = names[0] ?? 'غير محدد';
        _updatedByName = names[1];
        _generatedByName = names[2];
      });
    }
  }

  /// تحميل اسم مستخدم واحد مع العودة للقراءة
  /// المباشرة عند الخطأ (نفس منطق التحميل السابق)
  Future<String?> _loadUserName(String userId) async {
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == userId) {
        final name = switchedUser['name'] as String?;
        if (name != null) {
          return name;
        }
      }

      return await _getUserNameFromFirebase(userId);
    } on Exception catch (_) {
      return _getUserNameFromFirebase(userId);
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

        // ⚠️ يستخدم FirebaseFirestore.instance مباشرة بدلاً من المثيل المحقون.
        // هذا من أجل بساطة تحميل أسماء المستخدمين، لكنه يكسر اختبار الوحدة
        // واتساق المعاملات. يُنصح بحقن Firestore عبر الموسّع أو استخدام
        // repository عند إعادة هيكلة هذه الصفحة.
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

  Color _getStatusColor() {
    switch (_report.status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_report.status) {
      case 'completed':
        return 'مكتمل';
      case 'pending':
        return 'قيد المعالجة';
      case 'failed':
        return 'فشل';
      default:
        return 'غير محدد';
    }
  }

  String _getTypeText() {
    switch (_report.type) {
      case 'financial':
        return 'تقرير مالي';
      case 'inventory':
        return 'تقرير مخزون';
      case 'sales':
        return 'تقرير مبيعات';
      case 'expenses':
        return 'تقرير مصاريف';
      case 'custom':
        return 'تقرير مخصص';
      default:
        return 'غير محدد';
    }
  }

  IconData _getReportIcon() {
    switch (_report.type) {
      case 'financial':
        return Icons.account_balance;
      case 'inventory':
        return Icons.inventory;
      case 'sales':
        return Icons.trending_up;
      case 'expenses':
        return Icons.money_off;
      case 'custom':
        return Icons.analytics;
      default:
        return Icons.description;
    }
  }

  String _getReportDuration() {
    // ⚠️ إذا كانت endDate قبل startDate (بسبب خطأ في البيانات)، ستكون القيمة سالبة
    // وتُعرض بشكل غير صحيح (مثل "-5 أيام"). يجب التحقق من صحة التواريخ قبل الحساب.
    final difference = _report.endDate.difference(_report.startDate).inDays;
    if (difference <= 0) {
      return 'يوم واحد'; // أو عرض خطأ إذا كانت التواريخ غير صحيحة
    } else if (difference < 7) {
      return '$difference أيام';
    } else if (difference < 30) {
      final weeks = (difference / 7).round();
      return '$weeks أسبوع';
    } else if (difference < 365) {
      final months = (difference / 30).round();
      return '$months شهر';
    } else {
      final years = (difference / 365).round();
      return '$years سنة';
    }
  }

  void _showDeleteDialog() {
    DeleteReportDialog.show(
      context,
      _report,
      context.read<ReportBloc>(),
      onDeleted: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showRegenerateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة إنشاء التقرير'),
        content: const Text('هل تريد إعادة إنشاء هذا التقرير؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // ⚠️ وظيفة إعادة الإنشاء قيد التطوير — يحتاج استدعاء BLoC
              // لتوليد تقرير جديد بناءً على التقرير الحالي.
            },
            child: const Text('إعادة إنشاء'),
          ),
        ],
      ),
    );
  }
}
