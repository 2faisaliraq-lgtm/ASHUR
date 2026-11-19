import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/permissions/permission_checker.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';

/// صفحة تفاصيل الفئة
class CategoryDetailsPage extends StatefulWidget {
  const CategoryDetailsPage({required this.category, super.key});
  final CategoryEntity category;

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage> {
  late CategoryEntity _category;

  void _applyUpdatedCategory(CategoryEntity category) {
    if (!mounted || category.id != _category.id || category == _category) {
      return;
    }
    setState(() => _category = category);
    _loadRelatedData();
    _loadUserNames();
  }

  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  CategoryEntity? _parentCategory;
  List<CategoryEntity> _subCategories = [];
  int _productsCount = 0;
  String? _createdByName;
  String? _updatedByName;

  // Helper methods for number formatting
  String _formatInteger(int number) {
    return NumberFormat('#,###', 'en_US').format(number);
  }

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _loadPermissions();
    _loadRelatedData();
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ الفئة
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == _category.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }

      createdByName ??= await _getUserNameFromFirebase(_category.createdBy);
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(_category.createdBy);
    }

    // تحميل اسم المستخدم الذي حدّث الفئة
    String? updatedByName;
    if (_category.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] == _category.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await _getUserNameFromFirebase(_category.updatedBy!);
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(_category.updatedBy!);
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

  Future<void> _loadPermissions() async {
    final canEdit = await _permissionChecker.hasPermission('inventory_edit');

    if (mounted) {
      setState(() {
        _canEdit = canEdit;
      });
    }
  }

  void _loadRelatedData() {
    final state = context.read<InventoryBloc>().state;
    if (state is InventoryLoaded) {
      // البحث عن الفئة الرئيسية
      if (_category.parentId != null) {
        try {
          _parentCategory = state.categories.firstWhere(
            (cat) => cat.id == _category.parentId,
          );
        } on Exception catch (_) {
          _parentCategory = null;
        }
      }

      // البحث عن الفئات الفرعية
      _subCategories = state.categories
          .where((cat) => cat.parentId == _category.id)
          .toList();

      // حساب عدد المنتجات في هذه الفئة
      _productsCount = state.products
          .where((product) => product.categoryId == _category.id)
          .length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        if (state is InventoryLoaded) {
          for (final category in state.categories) {
            if (category.id == _category.id) {
              _applyUpdatedCategory(category);
              break;
            }
          }
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const InventoryDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildCategoryHeader(),
              const SizedBox(height: 6),
              _buildBasicInfoCard(),
              const SizedBox(height: 6),
              _buildHierarchyCard(),
              const SizedBox(height: 6),
              _buildStatsCard(),
              const SizedBox(height: 6),
              if (_subCategories.isNotEmpty) ...[
                _buildSubCategoriesCard(),
                const SizedBox(height: 6),
              ],
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
              'تفاصيل الفئة',
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
              final bloc = context.read<InventoryBloc>();
              final organizationEmail = _category.organizationEmail;
              final result = await Navigator.pushNamed(
                context,
                AppRoutes.editCategory,
                arguments: _category,
              );
              if (!mounted || result != true) return;
              bloc.add(LoadCategories(organizationEmail: organizationEmail));
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل الفئة',
          ),
      ],
    );
  }

  Widget _buildCategoryHeader() {
    return DetailScreenHeader(
      title: _category.name,
      subtitle: _category.description ?? 'لا توجد وصف',
      icon: _category.icon != null
          ? _parseIcon(_category.icon!)
          : Icons.category,
      iconBackgroundColor: _category.color != null
          ? _parseColor(_category.color!)
          : AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      iconForegroundColor: _category.color != null
          ? Colors.white
          : AssyrianTheme.primaryGold,
    );
  }

  Widget _buildBasicInfoCard() {
    return InfoCard(
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline,
      children: [
        DetailRow(label: 'اسم الفئة', value: _category.name),
        if (_category.description != null && _category.description!.isNotEmpty)
          DetailRow(label: 'الوصف', value: _category.description!),
        DetailRow(
          label: 'النوع',
          value: _category.isMainCategory ? 'فئة رئيسية' : 'فئة فرعية',
        ),
        DetailRow(label: 'ترتيب العرض', value: _category.sortOrder.toString()),
        DetailRow(
          label: 'الحالة',
          value: _category.isActive ? 'نشط' : 'غير نشط',
        ),
      ],
    );
  }

  Widget _buildHierarchyCard() {
    return InfoCard(
      title: 'التسلسل الهرمي',
      icon: Icons.account_tree,
      children: [
        if (_parentCategory != null)
          DetailRow(label: 'الفئة الرئيسية', value: _parentCategory!.name)
        else
          const DetailRow(
            label: 'الفئة الرئيسية',
            value: 'لا توجد (فئة رئيسية)',
          ),
        DetailRow(
          label: 'عدد الفئات الفرعية',
          value: _formatInteger(_subCategories.length),
        ),
        if (_category.color != null) _buildColorRow('اللون', _category.color!),
        if (_category.icon != null) _buildIconRow('الأيقونة', _category.icon!),
      ],
    );
  }

  Widget _buildStatsCard() {
    return InfoCard(
      title: 'الإحصائيات',
      icon: Icons.analytics,
      children: [
        DetailRow(label: 'عدد المنتجات', value: _formatInteger(_productsCount)),
        DetailRow(
          label: 'عدد الفئات الفرعية',
          value: _formatInteger(_subCategories.length),
        ),
        if (_subCategories.isNotEmpty) ...[
          DetailRow(
            label: 'الفئات الفرعية النشطة',
            value: _formatInteger(
              _subCategories.where((cat) => cat.isActive).length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubCategoriesCard() {
    return InfoCard(
      title: 'الفئات الفرعية',
      icon: Icons.folder_open,
      children: [..._subCategories.map(_buildSubCategoryRow)],
    );
  }

  Widget _buildStatusCard() {
    return InfoCard(
      title: 'معلومات النظام',
      icon: Icons.system_update,
      children: [
        DetailRow(
          label: 'تاريخ الإنشاء',
          value: _formatDate(_category.createdAt),
        ),
        DetailRow(
          label: 'تم الإنشاء بواسطة',
          value: _createdByName ?? 'غير محدد',
        ),
        if (_category.updatedAt != null)
          DetailRow(
            label: 'آخر تحديث',
            value: _formatDate(_category.updatedAt),
          ),
        if (_category.updatedBy != null)
          DetailRow(
            label: 'تم التحديث بواسطة',
            value: _updatedByName ?? _category.updatedBy!,
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
                  final bloc = context.read<InventoryBloc>();
                  final category = _category;
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.editCategory,
                    arguments: category,
                  );
                  if (!mounted || result != true) return;
                  bloc.add(
                    LoadCategories(
                      organizationEmail: category.organizationEmail,
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('تعديل الفئة'),
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
                  Navigator.of(context).pushNamed(AppRoutes.productsList);
                },
                icon: const Icon(Icons.inventory_2),
                label: const Text('عرض المنتجات'),
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

  Widget _buildColorRow(String label, String colorValue) {
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
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _parseColor(colorValue),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  colorValue,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AssyrianTheme.deepBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconRow(String label, String iconValue) {
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
            child: Row(
              children: [
                Icon(
                  _parseIcon(iconValue),
                  size: 24.sp,
                  color: AssyrianTheme.primaryGold,
                ),
                const SizedBox(width: 8),
                Text(
                  iconValue,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AssyrianTheme.deepBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCategoryRow(CategoryEntity subCategory) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              subCategory.icon != null
                  ? _parseIcon(subCategory.icon!)
                  : Icons.folder,
              size: 20.sp,
              color: subCategory.color != null
                  ? _parseColor(subCategory.color!)
                  : AssyrianTheme.primaryGold,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subCategory.name,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: subCategory.isActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                subCategory.isActive ? 'نشط' : 'غير نشط',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: subCategory.isActive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorValue) {
    try {
      return Color(int.parse(colorValue.replaceFirst('#', '0xFF')));
    } on Exception catch (_) {
      return AssyrianTheme.primaryGold;
    }
  }

  IconData _parseIcon(String iconValue) {
    switch (iconValue) {
      case 'category':
        return Icons.category;
      case 'restaurant':
        return Icons.restaurant;
      case 'checkroom':
        return Icons.checkroom;
      case 'devices':
        return Icons.devices;
      case 'book':
        return Icons.book;
      case 'sports':
        return Icons.sports;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      default:
        return Icons.category;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month}/${date.year}';
  }
}
