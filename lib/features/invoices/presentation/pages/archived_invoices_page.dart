import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/invoice_entity.dart';
import '../bloc/invoice_bloc.dart';
import '../widgets/delete_invoice_dialog.dart';
import '../widgets/invoice_drawer.dart';

/// صفحة عرض الفواتير المؤرشفة
class ArchivedInvoicesPage extends StatefulWidget {
  const ArchivedInvoicesPage({super.key});

  @override
  State<ArchivedInvoicesPage> createState() => _ArchivedInvoicesPageState();
}

class _ArchivedInvoicesPageState extends State<ArchivedInvoicesPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  Map<String, bool> _userPermissions = {};
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  String? _customerId; // معرف العميل للفلترة
  String? _customerName; // اسم العميل للعرض في العنوان فقط
  bool _initialized = false; // لمنع التحميل المتكرر

  // خريطة لتتبع حالة الطي/الفتح لكل مجموعة تاريخ
  final Map<String, bool> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final permissions = await _permissionChecker.getUserPermissions();
    final permissionsMap = <String, bool>{};

    for (final permission in permissions) {
      permissionsMap[permission] = true;
    }

    if (mounted) {
      setState(() {
        _userPermissions = permissionsMap;
      });
    }
  }

  /// التحقق من صلاحية حذف فاتورة بناءً على نوعها
  bool _canDeleteInvoice(InvoiceEntity invoice) {
    switch (invoice.type) {
      case 'sales':
        return _userPermissions['invoices_sales_manage'] == true;
      case 'purchase':
        return _userPermissions['invoices_purchase_manage'] == true;
      case 'cash':
        return _userPermissions['invoices_cash_manage'] == true;
      case 'subscription':
        return _userPermissions['invoices_subscription_manage'] == true;
      case 'sales_return':
        return _userPermissions['invoices_sales_return_manage'] == true;
      default:
        return false;
    }
  }

  /// ✅ تم الإصلاح: هذه الدالة تتحقق من صلاحية "إدارة" كل نوع من الفواتير.
  /// إذا كان المقصود فصل العرض عن الإدارة، يجب إضافة صلاحيات منفصلة للعرض (view)
  /// لكل نوع واستخدامها هنا بدلاً من صلاحيات الإدارة.
  bool _canViewInvoice(InvoiceEntity invoice) {
    switch (invoice.type) {
      case 'sales':
        return _userPermissions['invoices_sales_manage'] == true;
      case 'purchase':
        return _userPermissions['invoices_purchase_manage'] == true;
      case 'cash':
        return _userPermissions['invoices_cash_manage'] == true;
      case 'subscription':
        return _userPermissions['invoices_subscription_manage'] == true;
      case 'sales_return':
        return _userPermissions['invoices_sales_return_manage'] == true;
      default:
        return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // تنفيذ مرة واحدة فقط لتجنب التحميل المتكرر
    if (_initialized) return;

    // قراءة customerId من arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _customerId = args?['customerId'] as String?;
    _customerName = args?['customerName'] as String?;

    // تحميل البيانات
    _loadInvoices();

    _initialized = true;
  }

  void forceRefresh() {
    _loadInvoices();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadInvoices();
  }

  void _loadInvoices() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // 🔧 استخدام حدث تحميل الفواتير المؤرخة خصيصاً لصفحة الأرشيف
      // بدلاً من LoadInvoicesEvent الذي يستثني الفواتير المؤرched (isArchived == false).
      context.read<InvoiceBloc>().add(LoadArchivedInvoicesEvent(user.email!));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InvoiceEntity> _filterInvoices(List<InvoiceEntity> invoices) {
    Iterable<InvoiceEntity> filtered = invoices;

    // فلترة الفواتير حسب الصلاحيات - عرض فقط الفواتير المسموحة
    filtered = filtered.where((invoice) {
      return _canViewInvoice(invoice);
    });

    // فلترة حسب العميل إذا تم تمرير معرف العميل
    if (_customerId != null) {
      // استخدام معرف العميل فقط لضمان الدقة وتجنب الأسماء المتشابهة
      filtered = filtered.where((invoice) {
        return invoice.customerId == _customerId;
      });
    }

    // فلترة الفواتير المؤرشفة فقط (التي تم تعيين isArchived = true لها)
    filtered = filtered.where((invoice) {
      return invoice.isArchived == true;
    });

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((invoice) {
        return invoice.invoiceNumber.toLowerCase().contains(query) ||
            invoice.customerName.toLowerCase().contains(query) ||
            invoice.customerPhone.toLowerCase().contains(query);
      });
    }

    // تطبيق الفلتر
    if (_selectedFilter != 'all') {
      filtered = filtered.where((invoice) {
        return invoice.type == _selectedFilter;
      });
    }

    // ترتيب الفواتير حسب التاريخ (الأحدث أولاً)
    final result = filtered.toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  /// تجميع الفواتير حسب تاريخ الأرشفة
  Map<String, List<InvoiceEntity>> _groupInvoicesByArchiveDate(
    List<InvoiceEntity> invoices,
  ) {
    var groupedInvoices = <String, List<InvoiceEntity>>{};

    for (final invoice in invoices) {
      // استخدام تاريخ آخر تحديث كتاريخ الأرشفة
      var archiveDate = DateTime(
        invoice.updatedAt.year,
        invoice.updatedAt.month,
        invoice.updatedAt.day,
      );
      var dateKey = _formatArchiveDate(archiveDate);

      if (groupedInvoices.containsKey(dateKey)) {
        groupedInvoices[dateKey]!.add(invoice);
      } else {
        groupedInvoices[dateKey] = [invoice];
      }
    }

    // ترتيب الفواتير داخل كل مجموعة حسب الوقت
    groupedInvoices.forEach((key, invoices) {
      invoices.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });

    return groupedInvoices;
  }

  /// تنسيق تاريخ الأرشفة
  String _formatArchiveDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final archiveDate = DateTime(date.year, date.month, date.day);

    if (archiveDate == today) {
      return 'اليوم - ${date.day}/${date.month}/${date.year}';
    } else if (archiveDate == yesterday) {
      return 'أمس - ${date.day}/${date.month}/${date.year}';
    } else {
      // تحديد اسم اليوم
      final weekdays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      final weekday = weekdays[date.weekday - 1];
      return '$weekday - ${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InvoiceDrawer(currentRoute: 'archived_invoices'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<InvoiceBloc, InvoiceState>(
        listener: (context, state) {
          if (state is InvoiceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            _loadInvoices();
          }
        },
        builder: (context, state) {
          var allInvoices = <InvoiceEntity>[];

          if (state is InvoiceLoaded) {
            allInvoices = state.invoices.cast<InvoiceEntity>();
          }

          final filteredInvoices = _filterInvoices(allInvoices);

          if (state is InvoiceInitial || state is InvoiceLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل الأرشيف...'),
                ),
              ],
            );
          }

          if (state is InvoiceError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (filteredInvoices.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.archive_outlined,
                    title: _customerName != null
                        ? 'لا توجد فواتير مؤرشفة لهذا العميل'
                        : 'لا توجد فواتير مؤرشفة',
                    message: _customerName != null
                        ? 'لم يتم أرشفة أي فواتير لـ $_customerName بعد.'
                        : 'لا توجد فواتير مؤرشفة في النظام',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              _buildStatsCard(filteredInvoices),
              Expanded(child: _buildGroupedInvoicesList(filteredInvoices)),
            ],
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
                  _customerName != null
                      ? 'أرشيف فواتير: $_customerName'
                      : 'أرشيف الفواتير',
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
                  _customerName != null
                      ? 'الفواتير المؤرشفة للعميل المحدد'
                      : 'جميع الفواتير المؤرشفة',
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
        // زر فتح/إغلاق جميع المجموعات
        IconButton(
          onPressed: () {
            setState(() {
              final hasExpandedGroups = _expandedGroups.values.any(
                (expanded) => expanded,
              );
              _expandedGroups.clear();
              if (!hasExpandedGroups) {
                // فتح جميع المجموعات - سيتم تحديد المفاتيح عند البناء
                _expandedGroups['_expand_all'] = true;
              }
            });
          },
          icon: Icon(
            _expandedGroups.values.any((expanded) => expanded)
                ? Icons.unfold_less
                : Icons.unfold_more,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: _expandedGroups.values.any((expanded) => expanded)
              ? 'إغلاق الكل'
              : 'فتح الكل',
        ),
        IconButton(
          onPressed: _loadInvoices,
          icon: Icon(
            Icons.refresh,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildSearchFilter() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'البحث في الأرشيف...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AssyrianTheme.primaryGold,
                        size: 24.sp,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                              },
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey,
                                size: 20.sp,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: AssyrianTheme.primaryGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                          color: AssyrianTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _isFilterExpanded || _selectedFilter != 'all'
                        ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _isFilterExpanded || _selectedFilter != 'all'
                          ? AssyrianTheme.primaryGold
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _isFilterExpanded = !_isFilterExpanded;
                      });
                    },
                    icon: Stack(
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: _isFilterExpanded || _selectedFilter != 'all'
                              ? AssyrianTheme.primaryGold
                              : Colors.grey[600],
                          size: 24.sp,
                        ),
                        if (_selectedFilter != 'all')
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8.w,
                              height: 8.h,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'فلترة النتائج',
                  ),
                ),
              ],
            ),
          ),
          if (_isFilterExpanded) _buildFilterOptions(),
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    // التحقق من أنواع الفواتير المسموحة - بدون invoices_view العامة
    final canViewSales = _userPermissions['invoices_sales_manage'] == true;
    final canViewPurchase =
        _userPermissions['invoices_purchase_manage'] == true;
    final canViewCash = _userPermissions['invoices_cash_manage'] == true;
    final canViewSubscription =
        _userPermissions['invoices_subscription_manage'] == true;
    final canViewSalesReturn =
        _userPermissions['invoices_sales_return_manage'] == true;

    // إذا لم يكن هناك أي صلاحية لعرض أي نوع من الفواتير
    if (!canViewSales &&
        !canViewPurchase &&
        !canViewCash &&
        !canViewSubscription &&
        !canViewSalesReturn) {
      return Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 48.sp, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              'لا توجد فواتير مؤرشفة متاحة للعرض',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'ليس لديك صلاحية للوصول إلى أي نوع من الفواتير',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          _buildFilterChip('الكل', 'all'),
          if (canViewSales) _buildFilterChip('مبيعات', 'sales'),
          if (canViewPurchase) _buildFilterChip('مشتريات', 'purchase'),
          if (canViewCash) _buildFilterChip('نقدية', 'cash'),
          if (canViewSubscription) _buildFilterChip('اشتراكات', 'subscription'),
          if (canViewSalesReturn) _buildFilterChip('مرجع بيع', 'sales_return'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13.sp,
      ),
      side: BorderSide(
        color: isSelected
            ? AssyrianTheme.primaryGold
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStatsCard(List<InvoiceEntity> invoices) {
    final totalAmount = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );
    final salesCount = invoices.where((i) => i.type == 'sales').length;
    final purchaseCount = invoices.where((i) => i.type == 'purchase').length;
    final cashCount = invoices.where((i) => i.type == 'cash').length;
    final subscriptionCount = invoices
        .where((i) => i.type == 'subscription')
        .length;

    // حساب عدد أيام الأرشفة
    final groupedInvoices = _groupInvoicesByArchiveDate(invoices);
    final archiveDaysCount = groupedInvoices.keys.length;

    // تحديد ما إذا كانت الشاشة أفقية
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      margin: const EdgeInsets.all(4),
      padding: EdgeInsets.all(isLandscape ? 8 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withValues(alpha: 0.1),
            Colors.purple.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.archive,
                color: Colors.indigo,
                size: isLandscape ? 16.sp : 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'إحصائيات الأرشيف',
                style: TextStyle(
                  fontSize: isLandscape ? 14.sp : 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          SizedBox(height: isLandscape ? 8.h : 12.h),

          // في الشاشة الأفقية، نعرض جميع الإحصائيات في صفين بدلاً من أربعة
          if (isLandscape) ...[
            // الصف الأول: الإحصائيات الأساسية
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'إجمالي الفواتير',
                    '${invoices.length}',
                    Icons.receipt_long,
                    Colors.indigo,
                    isCompact: true,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'أيام الأرشفة',
                    '$archiveDaysCount',
                    Icons.date_range,
                    Colors.purple,
                    isCompact: true,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'إجمالي المبلغ',
                    _formattingService.formatCurrency(totalAmount),
                    Icons.attach_money,
                    Colors.green,
                    isCompact: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            // الصف الثاني: أنواع الفواتير
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'مبيعات',
                    '$salesCount',
                    Icons.trending_up,
                    Colors.green,
                    isCompact: true,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'مشتريات',
                    '$purchaseCount',
                    Icons.trending_down,
                    Colors.blue,
                    isCompact: true,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'نقدية',
                    '$cashCount',
                    Icons.payments,
                    Colors.orange,
                    isCompact: true,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'اشتراكات',
                    '$subscriptionCount',
                    Icons.subscriptions,
                    Colors.purple,
                    isCompact: true,
                  ),
                ),
              ],
            ),
          ] else ...[
            // في الشاشة العمودية، نحتفظ بالتصميم الأصلي
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'إجمالي الفواتير',
                    '${invoices.length}',
                    Icons.receipt_long,
                    Colors.indigo,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'أيام الأرشفة',
                    '$archiveDaysCount',
                    Icons.date_range,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'إجمالي المبلغ',
                    _formattingService.formatCurrency(totalAmount),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'مبيعات',
                    '$salesCount',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'مشتريات',
                    '$purchaseCount',
                    Icons.trending_down,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'نقدية',
                    '$cashCount',
                    Icons.payments,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'اشتراكات',
                    '$subscriptionCount',
                    Icons.subscriptions,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 6.r : 8.r),
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isCompact ? 12.sp : 16.sp),
          SizedBox(height: isCompact ? 2.h : 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 11.sp : 14.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 8.sp : 10.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80.sp, color: Colors.red[300]),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadInvoices,
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedInvoicesList(List<InvoiceEntity> invoices) {
    final groupedInvoices = _groupInvoicesByArchiveDate(invoices);
    final sortedKeys = groupedInvoices.keys.toList();

    sortedKeys.sort((a, b) {
      // ترتيب المجموعات حسب التاريخ (الأحدث أولاً)
      final dateA = groupedInvoices[a]!.first.updatedAt;
      final dateB = groupedInvoices[b]!.first.updatedAt;
      return dateB.compareTo(dateA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final invoicesForDate = groupedInvoices[dateKey]!;
        return _buildArchiveDateGroup(dateKey, invoicesForDate);
      },
    );
  }

  Widget _buildArchiveDateGroup(String dateKey, List<InvoiceEntity> invoices) {
    // تحديد حالة الطي/الفتح لهذه المجموعة
    final expandAll = _expandedGroups.containsKey('_expand_all');
    final isExpanded = expandAll || (_expandedGroups[dateKey] ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // عنوان المجموعة القابل للنقر
          InkWell(
            onTap: () {
              setState(() {
                // إزالة حالة "فتح الكل" عند النقر على مجموعة محددة
                _expandedGroups.remove('_expand_all');
                _expandedGroups[dateKey] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.withValues(alpha: 0.1),
                    Colors.purple.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.archive,
                      color: Colors.indigo,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          dateKey,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        Text(
                          'تم أرشفة ${invoices.length} فاتورة',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.indigo[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Colors.indigo.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${invoices.length}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // أيقونة الطي/الفتح
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.indigo,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // قائمة الفواتير (تظهر فقط عند الفتح)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isExpanded ? 1.0 : 0.0,
              child: isExpanded
                  ? Container(
                      margin: EdgeInsets.only(top: 8.h),
                      child: Column(
                        children: invoices
                            .map(
                              (invoice) => Padding(
                                padding: EdgeInsets.only(bottom: 6.h),
                                child: _buildInvoiceCard(
                                  invoice,
                                  showArchiveTime: true,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(
    InvoiceEntity invoice, {
    bool showArchiveTime = false,
  }) {
    final statusColor = _getStatusColor(invoice.status);
    final statusText = _getStatusText(invoice.status);
    final typeColor = invoice.type == 'sales'
        ? Colors.green
        : invoice.type == 'purchase'
        ? Colors.blue
        : invoice.type == 'subscription'
        ? Colors.purple
        : invoice.type == 'sales_return'
        ? Colors.teal
        : Colors.orange;
    final typeText = invoice.type == 'sales'
        ? 'مبيعات'
        : invoice.type == 'purchase'
        ? 'مشتريات'
        : invoice.type == 'subscription'
        ? 'اشتراك'
        : invoice.type == 'sales_return'
        ? 'مرجع بيع'
        : 'نقدية';

    // تحديد لون الخلفية حسب تأثير الفاتورة على الدين
    final cardBackgroundColor = _getCardBackgroundColor(
      invoice.type,
      invoice.totalAmount,
      invoice.notes,
    );
    final borderColor = _getCardBorderColor(
      invoice.type,
      invoice.totalAmount,
      invoice.notes,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          minTileHeight: 72.h,
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.invoiceDetails, arguments: invoice);
        },
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'delete') {
              _showDeleteDialog(invoice);
            }
          },
          itemBuilder: (context) => [
            if (_canDeleteInvoice(invoice))
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16.sp, color: Colors.red),
                    SizedBox(width: 6.w),
                    Text('حذف', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
          ],
          child: CircleAvatar(
            backgroundColor: typeColor.withValues(alpha: 0.1),
            radius: 22.r,
            child: Icon(Icons.receipt_long, color: typeColor, size: 20.sp),
          ),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 3.h),
            Text(
              invoice.customerName,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 5.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    typeText,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.calendar_today,
                  size: 10.sp,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 3.w),
                Text(
                  _formattingService.formatInvoiceDate(invoice.invoiceDate),
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                ),
                if (showArchiveTime) ...[
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.access_time,
                    size: 10.sp,
                    color: Colors.indigo[400],
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    _formatArchiveTime(invoice.updatedAt),
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.indigo[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _getDisplayAmount(invoice),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
         ),
       ),
       ),
     );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'جزئية';
      case 'unpaid':
        return 'غير مدفوعة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  void _showDeleteDialog(InvoiceEntity invoice) {
    DeleteInvoiceDialog.show(
      context,
      invoice,
      context.read<InvoiceBloc>(),
      onDeleted: _loadInvoices,
    );
  }

  /// تنسيق وقت الأرشفة
  String _formatArchiveTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// تحديد لون خلفية الكارت حسب تأثير الفاتورة على الدين
  Color _getCardBackgroundColor(
    String type,
    double totalAmount,
    String? notes,
  ) {
    // للفواتير النقدية، نعتمد على الملاحظات لتحديد التأثير على الدين
    if (type == 'cash' && notes != null) {
      if (notes.contains('عليه') ||
          notes.contains('تسديد دين') ||
          notes.contains('مدين') ||
          notes.contains('إعطاء مبلغ نقدي للعميل')) {
        // "عليه" (يزيد الدين) - لون أحمر فاتح
        return Colors.red.withValues(alpha: 0.05);
      } else if (notes.contains('له') ||
          notes.contains('دفع مقدم') ||
          notes.contains('دائن') ||
          notes.contains('استلام مبلغ نقدي من العميل')) {
        // "له" (يقلل الدين) - لون أخضر فاتح
        return Colors.green.withValues(alpha: 0.05);
      }
    } else if (type == 'sales') {
      // فواتير المبيعات تزيد الدين دائماً - لون أحمر فاتح
      return Colors.red.withValues(alpha: 0.05);
    } else if (type == 'subscription') {
      // فواتير الاشتراكات تزيد الدين دائماً - لون بنفسجي فاتح
      return Colors.purple.withValues(alpha: 0.05);
    } else if (type == 'sales_return') {
      // فواتير مرجع البيع تقلل الدين - لون أزرق مخضر فاتح
      return Colors.teal.withValues(alpha: 0.08);
    }

    // فواتير المشتريات أو أي نوع آخر - اللون الافتراضي
    return Colors.white;
  }

  /// تحديد لون حدود الكارت حسب تأثير الفاتورة على الدين
  Color _getCardBorderColor(String type, double totalAmount, String? notes) {
    // للفواتير النقدية، نعتمد على الملاحظات لتحديد التأثير على الدين
    if (type == 'cash' && notes != null) {
      if (notes.contains('عليه') ||
          notes.contains('تسديد دين') ||
          notes.contains('مدين') ||
          notes.contains('إعطاء مبلغ نقدي للعميل')) {
        // "عليه" (يزيد الدين) - حدود حمراء فاتحة
        return Colors.red.withValues(alpha: 0.3);
      } else if (notes.contains('له') ||
          notes.contains('دفع مقدم') ||
          notes.contains('دائن') ||
          notes.contains('استلام مبلغ نقدي من العميل')) {
        // "له" (يقلل الدين) - حدود خضراء فاتحة
        return Colors.green.withValues(alpha: 0.3);
      }
    } else if (type == 'sales') {
      // فواتير المبيعات تزيد الدين دائماً - حدود حمراء فاتحة
      return Colors.red.withValues(alpha: 0.3);
    } else if (type == 'subscription') {
      // فواتير الاشتراكات تزيد الدين دائماً - حدود بنفسجية فاتحة
      return Colors.purple.withValues(alpha: 0.3);
    } else if (type == 'sales_return') {
      // فواتير مرجع البيع تقلل الدين - حدود زرقاء مخضرة
      return Colors.teal.withValues(alpha: 0.4);
    }

    // فواتير المشتريات أو أي نوع آخر - الحدود الافتراضية
    return AssyrianTheme.primaryGold.withValues(alpha: 0.2);
  }

  /// تحديد المبلغ المناسب للعرض في القائمة
  String _getDisplayAmount(InvoiceEntity invoice) {
    // للفواتير النقدية "له" التي لها totalAmount = 0، نعرض المبلغ المدفوع بدون إشارة سالبة
    if (invoice.type == 'cash' &&
        invoice.isCashAccountReceipt &&
        invoice.totalAmount == 0 &&
        invoice.paidAmount != 0 &&
        invoice.notes != null &&
        (invoice.notes!.contains('له') ||
            invoice.notes!.contains('دفع مقدم') ||
            invoice.notes!.contains('دائن') ||
            invoice.notes!.contains('استلام مبلغ نقدي من العميل'))) {
      return _formattingService.formatInvoiceTotal(invoice.paidAmount.abs());
    }

    // للفواتير العادية، نعرض المبلغ الإجمالي
    return _formattingService.formatInvoiceTotal(invoice.totalAmount);
  }
}
