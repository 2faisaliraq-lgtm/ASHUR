import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/paginated_list_view.dart';
import '../../domain/entities/rental_unit_entity.dart';
import '../bloc/rental_unit_bloc.dart';
import '../bloc/rental_unit_event.dart';
import '../bloc/rental_unit_state.dart';
import '../widgets/rental_drawer.dart';

/// صفحة عرض جميع الوحدات القابلة للإيجار
class RentalUnitsListPage extends StatefulWidget {
  const RentalUnitsListPage({super.key});

  @override
  State<RentalUnitsListPage> createState() => _RentalUnitsListPageState();
}

class _RentalUnitsListPageState extends State<RentalUnitsListPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final TextEditingController _searchController = TextEditingController();
  final PermissionChecker _permissionChecker = PermissionChecker();
  String _selectedFilter = 'all';
  bool _canCreate = false;
  late RentalUnitBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bloc = context.read<RentalUnitBloc>();
    _startRealTimeUpdates();
    _loadPermissions();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionChecker.hasPermission('rentals_create');

    if (mounted) {
      setState(() {
        _canCreate = canCreate;
      });
    }
  }

  void _startRealTimeUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailService = EmailNormalizationService();
      final normalizedEmail = emailService.normalize(user.email!);
      _bloc.add(StartRentalUnitsStreamEvent(normalizedEmail));
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    final state = _bloc.state;
    if (state is! RentalUnitsStreamActive ||
        !state.hasMoreData ||
        state.isLoadingMore) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final normalizedEmail = EmailNormalizationService().normalize(user.email!);
      _bloc.add(LoadMoreRentalUnitsEvent(normalizedEmail));
    }
  }

  @override
  void dispose() {
    _bloc.add(const StopRentalUnitsStreamEvent());
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<RentalUnitEntity> _filterUnits(List<RentalUnitEntity> units) {
    var filtered = units;

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((unit) {
        return unit.itemName.toLowerCase().contains(query) ||
            (unit.itemDescription?.toLowerCase().contains(query) ?? false) ||
            unit.itemType.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedFilter != 'all') {
      filtered = filtered
          .where((unit) => unit.status == _selectedFilter)
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const RentalDrawer(currentRoute: 'rental_units'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              heroTag: 'rental_units_create_fab',
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  AppRoutes.createRentalUnit,
                );
                if (result == true) _startRealTimeUpdates();
              },
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
              child: Icon(Icons.add, size: 28.sp),
            )
          : null,
      body: BlocConsumer<RentalUnitBloc, RentalUnitState>(
        listener: (context, state) {
          if (state is RentalUnitError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is RentalUnitOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            _startRealTimeUpdates();
          }
        },
        builder: (context, state) {
          var allUnits = <RentalUnitEntity>[];

          if (state is RentalUnitLoaded) {
            allUnits = state.units.cast<RentalUnitEntity>();
          } else if (state is RentalUnitsStreamActive) {
            allUnits = state.units;
          }

          final filteredUnits = _filterUnits(allUnits);

          if (state is RentalUnitInitial || state is RentalUnitLoading) {
            return Column(
              children: [
                _buildSearchFilter(),
                const Expanded(
                  child: LoadingWidget(message: 'جاري تحميل الوحدات...'),
                ),
              ],
            );
          }

          if (filteredUnits.isEmpty) {
            return Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'لا توجد أشياء قابلة للإيجار',
                    message: 'ابدأ بإضافة شيء جديد للإيجار',
                  ),
                ),
              ],
            );
          }



          return Column(
            children: [
              _buildSearchFilter(),
              Expanded(
                child: PaginatedListView<RentalUnitEntity>(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(4),
                  items: filteredUnits,
                  hasMore:
                      state is RentalUnitsStreamActive && state.hasMoreData,
                  isLoadingMore:
                      state is RentalUnitsStreamActive && state.isLoadingMore,
                  onLoadMore: _onScroll,
                  itemBuilder: (context, index) =>
                      _buildUnitCard(filteredUnits[index]),
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
                  'الأشياء القابلة للإيجار',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 18.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'إدارة الوحدات',
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: 10.sp,
                    color: AssyrianTheme.ivoryWhite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'البحث عن شيء مؤجر...',
              prefixIcon: const Icon(
                Icons.search,
                color: AssyrianTheme.primaryGold,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
            ),
            // ⚠️ إصلاح (2026-10-12): كان onChanged
            // فارغاً — الكتابة لا تعيد البناء فلا
            // تُطبَّق الفلترة (_filterUnits تقرأ
            // _searchController.text). setState هنا
            // ضروري ليُعيد البناء ويُفلتر فوراً
            // عند الكتابة.
            onChanged: (value) {
              setState(() {});
            },
          ),
          SizedBox(height: 8.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                _buildFilterChip('متاحة', 'available'),
                _buildFilterChip('مؤجرة', 'rented'),
                _buildFilterChip('صيانة', 'maintenance'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        checkmarkColor: AssyrianTheme.primaryGold,
        labelStyle: TextStyle(
          color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildUnitCard(RentalUnitEntity unit) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        onTap: () {
          // Navigate to unit details
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        unit.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      _getUnitTypeIcon(unit.itemType),
                      color: _getStatusColor(unit.status),
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.itemName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                          ),
                        ),
                        if (unit.itemDescription != null) ...[
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14.sp,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  unit.itemDescription!,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        unit.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      _getStatusText(unit.status),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(unit.status),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.attach_money,
                    _formattingService.formatCurrency(unit.rentalPrice),
                    Colors.green,
                  ),
                  if (unit.brand != null) ...[
                    SizedBox(width: 8.w),
                    _buildInfoChip(Icons.badge, unit.brand!, Colors.blue),
                  ],
                  if (unit.model != null) ...[
                    SizedBox(width: 8.w),
                    _buildInfoChip(Icons.build, unit.model!, Colors.orange),
                  ],
                ],
              ),
              if (unit.currentRenterName != null) ...[
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16.sp, color: Colors.blue),
                      SizedBox(width: 8.w),
                      Text(
                        'المستأجر: ${unit.currentRenterName}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'rented':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'متاحة';
      case 'rented':
        return 'مؤجرة';
      case 'maintenance':
        return 'صيانة';
      default:
        return status;
    }
  }

  IconData _getUnitTypeIcon(String type) {
    switch (type) {
      case 'car':
        return Icons.directions_car;
      case 'property':
        return Icons.home;
      case 'equipment':
        return Icons.construction;
      case 'furniture':
        return Icons.chair;
      case 'electronics':
        return Icons.devices;
      default:
        return Icons.category;
    }
  }
}
