import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/delete_subscription_type_dialog.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة عرض جميع أنواع الاشتراكات
class SubscriptionTypesListPage extends StatefulWidget {
  const SubscriptionTypesListPage({super.key});

  @override
  State<SubscriptionTypesListPage> createState() =>
      _SubscriptionTypesListPageState();
}

class _SubscriptionTypesListPageState extends State<SubscriptionTypesListPage>
    with SaveOperationMixin<SubscriptionTypesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  String _selectedFilter = 'all';
  bool _isFilterExpanded = false;
  late SubscriptionBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<SubscriptionBloc>();
    _loadSubscriptionTypes();
    // إضافة مستمع التمرير للتحميل التدريجي
    _scrollController.addListener(_onScroll);
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

  void forceRefresh() {
    _loadSubscriptionTypes();
  }

  Future<void> refreshWithDelay([
    Duration delay = const Duration(milliseconds: 300),
  ]) async {
    await Future.delayed(delay);
    _loadSubscriptionTypes();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! SubscriptionTypesLoaded ||
        !state.hasMoreTypesData ||
        state.isLoadingMoreTypes) {
      return;
    }
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) _bloc.add(LoadMoreSubscriptionTypesEvent(email));
  }

  void _loadSubscriptionTypes() {
    // بدء الاستماع لأنواع الاشتراكات مع التحديث الفوري
    _bloc.add(const StartSubscriptionTypesStreamEvent());
  }

  @override
  void dispose() {
    // إيقاف الـ streams عند إغلاق الصفحة
    _bloc.add(const StopSubscriptionTypesStreamEvent());
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<SubscriptionTypeEntity> _filterTypes(
    List<SubscriptionTypeEntity> types,
  ) {
    var filtered = types;

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((type) {
        return type.name.toLowerCase().contains(query) ||
            type.description.toLowerCase().contains(query);
      }).toList();
    }

    // تطبيق الفلتر
    if (_selectedFilter == 'active') {
      filtered = filtered.where((type) => type.isActive).toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered.where((type) => !type.isActive).toList();
    } else if (_selectedFilter == 'monthly') {
      filtered = filtered.where((type) => type.duration == 'monthly').toList();
    } else if (_selectedFilter == 'quarterly') {
      filtered = filtered
          .where((type) => type.duration == 'quarterly')
          .toList();
    } else if (_selectedFilter == 'yearly') {
      filtered = filtered.where((type) => type.duration == 'yearly').toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const SubscriptionDrawer(currentRoute: 'subscription_types'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: FloatingActionButton(
        heroTag: 'subscription_types_create_fab',
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/subscriptions/types/create',
          );
          if (result == true) forceRefresh();
        },
        backgroundColor: AssyrianTheme.primaryGold,
        foregroundColor: AssyrianTheme.deepBlue,
        child: Icon(Icons.add_box, size: 28.sp),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listenWhen: (previous, current) {
          return current is SubscriptionError ||
              current is SubscriptionOperationSuccess;
        },
        listener: (context, state) {
          // ✅ هذه شاشة قائمة: عمليات الحذف تُنفَّذ عبر حوار يستدعي
          // الـ repository مباشرة (لا يُصدر حالات عبر الـ BLoC)،
          // وأخطاء الستريم تصل كـ SubscriptionError. لذلك لا نستدعي
          // failSaveOperation/completeSaveOperation (كلتاهما تُغلق
          // نافذة تحميل غير موجودة فتُغلق صفحة القائمة نفسها).
          // القاعدة: اعرض رسالة وابقَ في الصفحة.
          if (state is SubscriptionError && !_operationCompleted) {
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
          } else if (state is SubscriptionOperationSuccess &&
              !_operationCompleted) {
            _operationCompleted = true;
            forceRefresh();
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
          }
        },
        builder: (context, state) {
          var allTypes = <SubscriptionTypeEntity>[];

          if (state is SubscriptionTypesLoaded) {
            allTypes = state.types.cast<SubscriptionTypeEntity>();
          }

          final filteredTypes = _filterTypes(allTypes);

          final bool hasMoreTypesData = state is SubscriptionTypesLoaded
              ? state.hasMoreTypesData
              : false;
          final bool isLoadingMoreTypes = state is SubscriptionTypesLoaded
              ? state.isLoadingMoreTypes
              : false;

          if (state is SubscriptionInitial || state is SubscriptionLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(
                    message: 'جاري تحميل أنواع الاشتراكات...',
                  ),
                ),
              ],
            );
          }

          if (state is SubscriptionError) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(child: _buildErrorState(state.message)),
              ],
            );
          }

          if (filteredTypes.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.category_outlined,
                    title: 'لا توجد أنواع اشتراكات',
                    message: 'ابدأ بإضافة نوع اشتراك جديد',
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<SubscriptionTypeEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredTypes,
                  hasMore: hasMoreTypesData,
                  isLoadingMore: isLoadingMoreTypes,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildTypeCard(filteredTypes[index]),
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
                  'أنواع الاشتراكات',
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
        IconButton(
          onPressed: _loadSubscriptionTypes,
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
                      hintText: 'البحث عن نوع اشتراك...',
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
          _buildFilterChip('نشط', 'active'),
          _buildFilterChip('غير نشط', 'inactive'),
          _buildFilterChip('شهري', 'monthly'),
          _buildFilterChip('ربع سنوي', 'quarterly'),
          _buildFilterChip('سنوي', 'yearly'),
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
            onPressed: _loadSubscriptionTypes,
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

  Widget _buildTypeCard(SubscriptionTypeEntity type) {
    final statusColor = type.isActive ? Colors.green : Colors.grey;
    final statusText = type.isActive ? 'نشط' : 'غير نشط';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
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
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        minTileHeight: 72.h,
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.subscriptionTypeDetails, arguments: type);
        },
        leading: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 100.w),
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.pushNamed(
                context,
                '/subscriptions/types/edit',
                arguments: type,
              );
            } else if (value == 'recharge') {
              Navigator.pushNamed(
                context,
                '/subscriptions/recharge-activations',
                arguments: type,
              );
            } else if (value == 'delete') {
              _showDeleteDialog(type);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'recharge',
              child: Row(
                children: [
                  Icon(
                    Icons.add_shopping_cart,
                    size: 16.sp,
                    color: Colors.green,
                  ),
                  SizedBox(width: 6.w),
                  Text('شحن تفعيلات', style: TextStyle(fontSize: 13.sp)),
                ],
              ),
            ),
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
              Icons.category,
              color: AssyrianTheme.primaryGold,
              size: 20.sp,
            ),
          ),
        ),
        title: Text(
          type.name,
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
              type.description,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: _getActivationColor(type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${type.activationQuantity} تفعيلة',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: _getActivationColor(type),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  '• ${_getDurationText(type.duration)}',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                ),
                SizedBox(width: 6.w),
                Text(
                  '• ${type.features.length} ميزة',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                ),
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  _formattingService.formatCurrency(type.price),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AssyrianTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getActivationColor(SubscriptionTypeEntity type) {
    return type.activationQuantity > 0 ? Colors.green : Colors.red;
  }

  String _getDurationText(String duration) {
    switch (duration) {
      case 'monthly':
        return 'شهري';
      case 'yearly':
        return 'سنوي';
      case 'quarterly':
        return 'ربع سنوي';
      default:
        return duration;
    }
  }

  void _showDeleteDialog(SubscriptionTypeEntity type) {
    DeleteSubscriptionTypeDialog.show(
      context,
      type,
      context.read<SubscriptionBloc>(),
      onDeleted: _loadSubscriptionTypes,
    );
  }
}
