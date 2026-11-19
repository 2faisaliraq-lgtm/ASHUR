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
import '../../../../core/services/section_badge_service.dart';
import '../../../../core/services/section_notification_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../../../core/widgets/section_alert_banner.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';
import '../widgets/delete_customer_dialog.dart';

/// صفحة عرض جميع العملاء
class CustomersListPage extends StatefulWidget {
  const CustomersListPage({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  State<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends State<CustomersListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final ScrollController _scrollController = ScrollController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  late CustomerBloc _bloc; // حفظ reference للـ bloc
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  List<CustomerEntity> _allCustomersFromServer =
      []; // جميع العملاء من السيرفر للتنبيهات والملخص
  bool _canViewReports = false;
  bool _waitingForInitialData = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
      _waitingForInitialData = true;
    }
    // حفظ reference للـ bloc
    _bloc = context.read<CustomerBloc>();
    _loadCustomersPaginated();
    _loadPermissions();

    // إضافة مستمع للتمرير
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'customers_create',
    );
    final canEdit = await _permissionChecker.hasPermission('customers_edit');
    final canDelete = await _permissionChecker.hasPermission(
      'customers_delete',
    );
    final canViewReports = await _permissionChecker.hasPermission(
      'reports_view',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canViewReports = canViewReports;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نعيد تحميل البيانات هنا؟
    // لأن initState يبدأ التحميل بالفعل، وإعادة
    // التحميل هنا تُعيد بدء الستريم عند كل تغيّر
    // (مثل ظهور الكيبورد) فتهدم الواجهة وتغلق الكيبورد.
    // ==========================================
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! CustomerLoaded || !state.hasMore || state.isLoadingMore) {
      return;
    }
    final email = EmailNormalizationService().normalize(
      FirebaseAuth.instance.currentUser?.email ?? '',
    );
    if (email.isNotEmpty) _bloc.add(LoadMoreCustomersEvent(email));
  }

  void _loadCustomersPaginated({bool isRefresh = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      context.read<CustomerBloc>().add(
        LoadCustomersPaginatedEvent(
          organizationEmail: normalizedEmail,
          isRefresh: isRefresh,
          searchQuery: _searchController.text.isNotEmpty
              ? _searchController.text
              : null,
        ),
      );
      // تحميل الإحصائيات
      context.read<CustomerBloc>().add(
        StartCustomerStatsStreamEvent(normalizedEmail),
      );
    }
  }

  /// ✅ التحقق من تنبيهات جميع العملاء من السيرفر (بدون حد)
  Future<void> _checkAllCustomersNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      try {
        final repo = GetIt.instance<CustomerRepository>();
        final result = await repo.getCustomers(
          normalizedEmail,
          forceRefresh: true,
        );
        result.fold((failure) {}, (allCustomers) {
          _allCustomersFromServer = allCustomers;
          SectionNotificationService.checkAndNotifyCustomers(allCustomers);
        });
      } on Exception catch (_) {
        // تجاهل الأخطاء في فحص التنبيهات
      }
    }
  }

  void forceRefresh() {
    _loadCustomersPaginated(isRefresh: true);
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadCustomersPaginated(isRefresh: true);
  }

  void _loadCustomers() {
    _loadCustomersPaginated(isRefresh: true);
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopCustomerStatsStreamEvent());
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<CustomerEntity> _filterCustomers(List<CustomerEntity> customers) {
    var filtered = customers;

    // تطبيق الفلتر أولاً
    if (_selectedFilter != 'all') {
      filtered = filtered.where((customer) {
        switch (_selectedFilter) {
          case 'active':
            return customer.isActive;
          case 'inactive':
            return customer.isInactive;
          case 'blocked':
            return customer.isBlocked;
          case 'with_group':
            return customer.hasGroup;
          case 'without_group':
            return !customer.hasGroup;
          default:
            return true;
        }
      }).toList();
    }

    // ثم تطبيق البحث على النتائج المفلترة
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((customer) {
        return customer.name.toLowerCase().contains(query) ||
            customer.email.toLowerCase().contains(query) ||
            customer.phone.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const CustomerDrawer(currentRoute: AppRoutes.customersList),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'customers_list_create_fab',
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.createCustomer);
                // إعادة تحميل البيانات بعد نجاح إنشاء العميل.
                if (result == true) {
                  forceRefresh();
                }
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<CustomerBloc, CustomerState>(
        listener: (context, state) {
          if (_waitingForInitialData &&
              (state is CustomerLoaded || state is CustomerStreamActive)) {
            _waitingForInitialData = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _bloc.add(FilterCustomersEvent(_selectedFilter));
              }
            });
          }
          if (state is CustomerLoaded) {
            _checkAllCustomersNotifications();
          }
          if (state is CustomerStreamActive) {
            _checkAllCustomersNotifications();
          }
          if (state is CustomerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            // إعادة تحميل العملاء بعد الخطأ
            _loadCustomers();
          }
        },
        builder: (context, state) {
          var allCustomers = <CustomerEntity>[];

          if (state is CustomerLoaded) {
            allCustomers = state.customers.cast<CustomerEntity>();
          } else if (state is CustomerStreamActive) {
            allCustomers = state.customers.cast<CustomerEntity>();
          }

          final filteredCustomers = _filterCustomers(allCustomers);
          final customerSummary = SectionBadgeService.buildCustomerSummary(
            _allCustomersFromServer.isNotEmpty
                ? _allCustomersFromServer
                : allCustomers,
          );

          // إذا كانت الحالة أولية أو تحميل، نعرض شاشة التحميل
          if (state is CustomerInitial || state is CustomerLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل العملاء...'),
                ),
              ],
            );
          }

          // إذا كانت الحالة خطأ
          if (state is CustomerError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          // إذا كانت القائمة فارغة
          if (filteredCustomers.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    title: 'لا توجد عملاء',
                    message: 'ابدأ بإضافة عميل جديد',
                    icon: Icons.people_outline,
                  ),
                ),
              ],
            );
          }

          // عرض القائمة
          return Column(
            children: [
              _buildSearchFilter(),
              if (customerSummary.hasUrgentItems)
                SectionAlertBanner(
                  title: customerSummary.urgencyType == 'critical'
                      ? '⚠️ تنبيه تجاوز حد الائتمان'
                      : '👤 تنبيه ديون العملاء',
                  message: customerSummary.summaryMessage,
                  count: customerSummary.totalUrgentCount,
                  urgencyType: customerSummary.urgencyType,
                ),
              Expanded(
                child: PaginatedListView<CustomerEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredCustomers,
                  hasMore: state is CustomerLoaded && state.hasMore,
                  isLoadingMore:
                      state is CustomerLoaded && state.isLoadingMore,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildCustomerCard(filteredCustomers[index]),
                ),
              ),
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
                  'إدارة العملاء',
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
                  'نظام إدارة المتاجر الآشوري',
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
        if (_canViewReports)
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.customersReports),
            icon: Icon(
              Icons.analytics,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تقارير العملاء',
          ),
        IconButton(
          onPressed: _loadCustomers,
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
          // شريط البحث الرئيسي
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // حقل البحث
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _bloc.add(SearchCustomersEvent(value));
                    },
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن عميل...',
                      hintTextDirection: TextDirection.rtl,
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
                // زر الفلتر
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
          // قسم الفلاتر القابل للطي
          if (_isFilterExpanded) _buildFiltersSection(),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'نوع العميل',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
              const Spacer(),
              if (_selectedFilter != 'all')
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'all';
                    });
                  },
                  child: Text(
                    'مسح الفلتر',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildFilterChip('الكل', 'all'),
              _buildFilterChip('لديهم مجموعة', 'with_group'),
              _buildFilterChip('بدون مجموعة', 'without_group'),
            ],
          ),
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
      selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
      checkmarkColor: AssyrianTheme.deepBlue,
      labelStyle: TextStyle(
        color: isSelected ? AssyrianTheme.deepBlue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 14.sp,
      ),
      side: BorderSide(
        color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[400]!,
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red[400]),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              message,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadCustomers,
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

  Widget _buildCustomerCard(CustomerEntity customer) {
    final isExceedingCreditLimit = _isExceedingCreditLimit(customer);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isExceedingCreditLimit
            ? Colors.red.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isExceedingCreditLimit
              ? Colors.red.withValues(alpha: 0.3)
              : AssyrianTheme.primaryGold.withValues(alpha: 0.2),
          width: isExceedingCreditLimit ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        minTileHeight: 72.h,
        onTap: () => _showCustomerDetails(customer),
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.of(context)
                  .pushNamed(AppRoutes.editCustomer, arguments: customer)
                  .then((_) {
                    forceRefresh();
                  });
            } else if (value == 'delete') {
              DeleteCustomerDialog.show(
                context,
                customer,
                context.read<CustomerBloc>(),
                onDeleted: _loadCustomers,
              );
            }
          },
          itemBuilder: (context) => [
            if (_canEdit)
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16.sp, color: Colors.blue),
                    SizedBox(width: 6.w),
                    Text('تعديل', style: TextStyle(fontSize: 13.sp)),
                  ],
                ),
              ),
            if (_canDelete)
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
            backgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
            radius: 22.r,
            child: Icon(
              customer.hasGroup ? Icons.group : Icons.person,
              color: AssyrianTheme.primaryGold,
              size: 20.sp,
            ),
          ),
        ),
        title: Text(
          customer.name,
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
              customer.email,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              customer.phone,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: customer.hasGroup
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  customer.hasGroup
                      ? (customer.customerGroupName ?? 'مجموعة')
                      : 'بدون مجموعة',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: customer.hasGroup ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 3.h),
              _buildDebtInfo(customer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtInfo(CustomerEntity customer) {
    if (customer.totalDebt == 0) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 12.sp, color: Colors.green),
            SizedBox(width: 3.w),
            Text(
              'لا يوجد دين',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final isDebt = customer.totalDebt > 0;
    final color = isDebt ? Colors.red : Colors.green;
    final icon = isDebt ? Icons.trending_up : Icons.trending_down;
    final label = isDebt ? 'عليه' : 'له';
    final amount = customer.totalDebt.abs();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formattingService.formatCurrency(amount),
            style: TextStyle(
              fontSize: 10.sp,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(CustomerEntity customer) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.customerDetails, arguments: customer);
  }

  /// التحقق من تجاوز حد الدين
  bool _isExceedingCreditLimit(CustomerEntity customer) {
    // استخدام دالة الكيان الموحدة لتجنب تكرار المنطق
    return customer.exceedsCreditLimit;
  }
}
