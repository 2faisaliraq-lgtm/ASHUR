import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';

import '../../../../app/routes/app_routes.dart';
import '../../domain/entities/customer_group_entity.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';
import '../widgets/delete_customer_group_dialog.dart';

/// صفحة قائمة مجموعات العملاء
class CustomerGroupsListPage extends StatefulWidget {
  const CustomerGroupsListPage({super.key});

  @override
  State<CustomerGroupsListPage> createState() => _CustomerGroupsListPageState();
}

class _CustomerGroupsListPageState extends State<CustomerGroupsListPage>
    with SaveOperationMixin<CustomerGroupsListPage> {
  List<CustomerGroupEntity> _customerGroups = [];
  List<CustomerGroupEntity> _filteredGroups = [];

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  bool _isGridView = true;
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  CustomerBloc? _customerBloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();

    // بدء الاستماع للتحديثات الفورية لمجموعات العملاء
    final customerBloc = context.read<CustomerBloc>();
    _customerBloc = customerBloc;
    customerBloc.add(const StartCustomerGroupsStreamEvent());
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission(
      'customers_create',
    );
    final canEdit = await _permissionChecker.hasPermission('customers_edit');
    final canDelete = await _permissionChecker.hasPermission(
      'customers_delete',
    );

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // حفظ مرجع الـ bloc لاستخدامه بأمان في dispose
    _customerBloc = context.read<CustomerBloc>();
    // ===== ملاحظة للمبرمجين المستقبليين =====
    // لماذا لا نعيد تحميل البيانات هنا؟
    // لأن initState يبدأ ستريم المجموعات بالفعل،
    // وإعادة التحميل هنا تُعيد بدء الستريم عند كل
    // تغيّر (مثل ظهور الكيبورد) فتهدم الواجهة
    // وتغلق الكيبورد.
    // ==========================================
  }

  void forceRefresh() {
    _loadCustomerGroups();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadCustomerGroups();
  }

  void _loadCustomerGroups() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      context.read<CustomerBloc>().add(
        LoadCustomerGroupsEvent(currentUser.email!),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _customerBloc?.state;
    if (state is! CustomerGroupsLoaded ||
        !state.hasMoreGroupsData ||
        state.isLoadingMoreGroups) {
      return;
    }
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      _customerBloc?.add(LoadMoreCustomerGroupsEvent(email));
    }
  }

  void _filterGroups(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = List.from(_customerGroups);
      } else {
        _filteredGroups = _customerGroups
            .where(
              (group) =>
                  group.name.toLowerCase().contains(query.toLowerCase()) ||
                  group.description.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _refreshGroups() {
    _customerBloc?.add(const StartCustomerGroupsStreamEvent());
    if (_customerBloc == null) {
      context.read<CustomerBloc>().add(const StartCustomerGroupsStreamEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const CustomerDrawer(currentRoute: 'customer_groups'),
      body: BlocListener<CustomerBloc, CustomerState>(
        listenWhen: (previous, current) {
          return current is CustomerGroupsLoaded ||
              current is CustomerGroupOperationSuccess ||
              current is CustomerError;
        },
        listener: (context, state) {
          // ✅ هذه شاشة قائمة: عمليات الحذف تُنفَّذ عبر حوار يستدعي
          // الـ repository مباشرة (لا يُصدر حالات عبر الـ BLoC)،
          // وأخطاء الستريم تصل كـ CustomerError. لذلك لا نستدعي
          // completeSaveOperation/failSaveOperation (كلتاهما تُغلق
          // نافذة تحميل غير موجودة فتُغلق صفحة القائمة نفسها).
          // القاعدة: اعرض رسالة وابقَ في الصفحة.
          if (state is CustomerGroupsLoaded) {
            setState(() {
              _customerGroups = state.groups;
              _filteredGroups = List.from(_customerGroups);
            });
          } else if (state is CustomerGroupOperationSuccess &&
              !_operationCompleted) {
            _operationCompleted = true;
            _refreshGroups();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          } else if (state is CustomerError && !_operationCompleted) {
            _operationCompleted = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        },
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchAndActions(context),
            Expanded(
              child: BlocBuilder<CustomerBloc, CustomerState>(
                builder: (context, state) {
                  if (state is CustomerLoading) {
                    return LoadingWidget(message: 'جاري تحميل المجموعات...');
                  }

                  if (_filteredGroups.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.group_off,
                      title: 'لا توجد مجموعات عملاء',
                      message: 'ابدأ بإضافة مجموعة عملاء جديدة',
                    );
                  }

                  return _isGridView
                      ? _buildGridView(context)
                      : _buildListView(context);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.createCustomerGroup);
                if (result == true) _refreshGroups();
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                'إضافة مجموعة',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            )
          : null,
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
                  'مجموعات العملاء',
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
                  'إدارة مجموعات العملاء',
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: AssyrianTheme.cardGradient,
        boxShadow: AssyrianTheme.assyrianShadow,
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.group,
              size: 32.sp,
              color: AssyrianTheme.primaryGold,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مجموعات العملاء',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'إدارة وتنظيم مجموعات العملاء',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${_filteredGroups.length} مجموعة',
              style: TextStyle(
                fontSize: 12.sp,
                color: AssyrianTheme.deepBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: _filterGroups,
              decoration: InputDecoration(
                hintText: 'البحث في مجموعات العملاء...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AssyrianTheme.primaryGold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          IconButton(
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_view,
              color: AssyrianTheme.primaryGold,
            ),
            tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minItemWidth = 400;
        final availableWidth = constraints.maxWidth;
        final maxColumns = (availableWidth / minItemWidth).floor().clamp(1, 2);
        final state = _customerBloc?.state;
        final hasMore = state is CustomerGroupsLoaded && state.hasMoreGroupsData;
        final isLoadingMore =
            state is CustomerGroupsLoaded && state.isLoadingMoreGroups;

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(16.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: maxColumns,
            childAspectRatio: 3,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
          ),
          itemCount: _filteredGroups.length + (hasMore || isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _filteredGroups.length) {
              return const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              );
            }
            return _buildGroupCard(_filteredGroups[index]);
          },
        );
      },
    );
  }

  Widget _buildListView(BuildContext context) {
    final state = _customerBloc?.state;
    final hasMore = state is CustomerGroupsLoaded && state.hasMoreGroupsData;
    final isLoadingMore =
        state is CustomerGroupsLoaded && state.isLoadingMoreGroups;
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16.w),
      itemCount: _filteredGroups.length + (hasMore || isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _filteredGroups.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: _buildGroupCard(_filteredGroups[index]),
        );
      },
    );
  }

  Widget _buildGroupCard(CustomerGroupEntity group) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AssyrianTheme.cardGradient,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Container(
                width: 12.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: Color(int.parse('0xFF${group.color}')),
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      group.description,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (group.features.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 4.w,
                        children: group.features.take(3).map((feature) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AssyrianTheme.primaryGold.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: AssyrianTheme.deepBlue,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      Navigator.of(context)
                          .pushNamed('/customers/groups/edit', arguments: group)
                          .then((_) => _refreshGroups());
                      break;
                    case 'delete':
                      _showDeleteDialog(group);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (_canEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ],
                      ),
                    ),
                  if (_canDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(CustomerGroupEntity group) {
    DeleteCustomerGroupDialog.show(
      context,
      group,
      context.read<CustomerBloc>(),
      // Stream سيقوم بتحديث القائمة تلقائياً
    );
  }

  @override
  void dispose() {
    // إيقاف الاستماع للتحديثات عند إغلاق الصفحة
    _customerBloc?.add(const StopCustomerGroupsStreamEvent());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
