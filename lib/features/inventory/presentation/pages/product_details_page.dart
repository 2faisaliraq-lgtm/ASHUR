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
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';
import 'product_logs_page.dart';

/// صفحة تفاصيل المنتج
class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({required this.product, super.key});
  final ProductEntity product;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late ProductEntity _product;

  void _applyUpdatedProduct(ProductEntity product) {
    if (!mounted || product.id != _product.id || product == _product) return;
    setState(() {
      _product = product;
      _category = null;
      _shelfName = null;
    });
    _findCategory();
    _loadShelfAndName();
    _loadUserNames();
  }

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final PermissionChecker _permissionChecker = PermissionChecker();
  bool _canEdit = false;
  CategoryEntity? _category;
  String? _createdByName;
  String? _updatedByName;
  String? _shelfName;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _findCategory();
    _loadPermissions();

    // تحميل الرفوف وتحميل اسم الرف
    _loadShelfAndName();

    // تحميل أسماء المستخدمين
    _loadUserNames();
  }

  void _loadShelfAndName() {
    if (_product.shelfId == null || _product.shelfId!.isEmpty) {
      return;
    }

    final state = context.read<InventoryBloc>().state;

    // إذا كانت الرفوف محملة، نحمل اسم الرف مباشرة
    if (state is InventoryLoaded &&
        state.shelves != null &&
        state.shelves!.isNotEmpty) {
      try {
        final shelf = state.shelves!.firstWhere(
          (s) => s.id == _product.shelfId,
        );
        if (mounted) {
          setState(() {
            _shelfName = shelf.name;
          });
        }
        return;
      } on Exception catch (_) {
        // الرف غير موجود
      }
    }

    // إذا لم تكن الرفوف محملة، نحملها
    if (state is! InventoryLoaded ||
        state.shelves == null ||
        state.shelves!.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final emailService = EmailNormalizationService();
        final normalizedEmail = emailService.normalize(user.email!);
        context.read<InventoryBloc>().add(
          LoadShelves(organizationEmail: normalizedEmail),
        );
      }
    }
  }

  Future<void> _loadUserNames() async {
    // تحميل اسم المستخدم الذي أنشأ المنتج
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] == _product.createdBy) {
        // المستخدم المبدل هو نفسه الذي أنشأ المنتج
        createdByName = switchedUser['name'] as String?;
      }

      // إذا لم نجد الاسم، نحاول تحميله من Firebase
      createdByName ??= await _getUserNameFromFirebase(_product.createdBy);
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(_product.createdBy);
    }

    // تحميل اسم المستخدم الذي حدّث المنتج
    String? updatedByName;
    if (_product.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null && switchedUser['id'] == _product.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }

        updatedByName ??= await _getUserNameFromFirebase(_product.updatedBy!);
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(_product.updatedBy!);
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

    // تحميل من Firebase - نستخدم المسار الصحيح مع البريد الإلكتروني
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

  void _findCategory() {
    final state = context.read<InventoryBloc>().state;
    if (state is InventoryLoaded) {
      try {
        _category = state.categories.firstWhere(
          (cat) => cat.id == _product.categoryId,
        );
      } on Exception catch (_) {
        _category = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        if (state is InventoryLoaded) {
          for (final category in state.categories) {
            if (category.id == _product.categoryId && category != _category) {
              setState(() => _category = category);
              break;
            }
          }
          for (final product in state.products) {
            if (product.id == _product.id) {
              _applyUpdatedProduct(product);
              break;
            }
          }
        }
      },
      child: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          // إذا كان الـ state هو InventoryLoaded والرفوف محملة، نحاول تحميل اسم الرف
          if (state is InventoryLoaded &&
              state.shelves != null &&
              _product.shelfId != null &&
              _product.shelfId!.isNotEmpty) {
            try {
              final shelf = state.shelves!.firstWhere(
                (s) => s.id == _product.shelfId,
              );
              // تحديث _shelfName إذا كانت مختلفة
              if (_shelfName != shelf.name) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _shelfName = shelf.name;
                    });
                  }
                });
              }
            } on Exception catch (_) {
              // الرف غير موجود
            }
          }

          // استخدام _shelfName المخزنة، إذا لم تكن محملة نعرض نص فارغ
          final shelfName = _shelfName ?? '';

          return scaffold.ResponsiveScaffold(
            appBar: _buildAppBar(context),
            drawer: const InventoryDrawer(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _buildProductHeader(),
                  const SizedBox(height: 6),
                  _buildBasicInfoCard(shelfName: shelfName),
                  const SizedBox(height: 6),
                  _buildPricingCard(),
                  const SizedBox(height: 6),
                  _buildInventoryCard(),
                  const SizedBox(height: 6),
                  _buildStatusCard(
                    createdByName: _createdByName,
                    updatedByName: _updatedByName,
                  ),
                  const SizedBox(height: 6),
                  _buildActionsCard(),
                ],
              ),
            ),
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
            child: Text(
              'تفاصيل المنتج',
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
              final organizationEmail = _product.organizationEmail;
              final result = await Navigator.of(
                context,
              ).pushNamed(AppRoutes.editProduct, arguments: _product);
              if (!mounted) return;
              if (result == true) {
                bloc.add(
                  LoadProductsPaginatedEvent(
                    organizationEmail: organizationEmail,
                    isRefresh: true,
                  ),
                );
                bloc.add(LoadCategories(organizationEmail: organizationEmail));
                bloc.add(LoadShelves(organizationEmail: organizationEmail));
              }
            },
            icon: Icon(
              Icons.edit,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'تعديل المنتج',
          ),
      ],
    );
  }

  Widget _buildProductHeader() {
    return DetailScreenHeader(
      title: _product.name,
      subtitle: _product.description ?? 'لا توجد وصف',
      icon: Icons.inventory_2,
      iconBackgroundColor: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
      iconForegroundColor: AssyrianTheme.primaryGold,
    );
  }

  Widget _buildBasicInfoCard({String? shelfName}) {
    return InfoCard(
      title: 'المعلومات الأساسية',
      icon: Icons.info_outline,
      children: [
        if (_product.barcode != null && _product.barcode!.isNotEmpty)
          DetailRow(label: 'الباركود', value: _product.barcode!),
        DetailRow(label: 'الفئة', value: _category?.name ?? 'غير محدد'),
        DetailRow(label: 'الوحدة', value: _product.unit),
        DetailRow(
          label: 'تتبع الكمية',
          value: _product.trackQuantity ? 'نعم' : 'لا',
        ),
        if (_product.shelfId != null && _product.shelfId!.isNotEmpty)
          DetailRow(label: 'الرف', value: shelfName ?? _product.shelfId!),
      ],
    );
  }

  Widget _buildPricingCard() {
    return InfoCard(
      title: 'معلومات التسعير',
      icon: Icons.attach_money,
      children: [
        if (_product.costPrice != null)
          DetailRow(
            label: 'سعر التكلفة',
            value: _formattingService.formatProductPrice(_product.costPrice!),
          ),
        DetailRow(
          label: 'سعر البيع',
          value: _formattingService.formatProductPrice(_product.sellingPrice),
        ),
        if (_product.costPrice != null)
          DetailRow(
            label: 'هامش الربح',
            value: _formattingService.formatPercentage(_product.profitMargin),
          ),
      ],
    );
  }

  Widget _buildInventoryCard() {
    return InfoCard(
      title: 'معلومات المخزون',
      icon: Icons.inventory,
      children: [
        DetailRow(
          label: 'الكمية الحالية',
          value:
              '${_formattingService.formatStockQuantity(_product.quantity.round())} ${_product.unit}',
        ),
        DetailRow(
          label: 'الحد الأدنى',
          value:
              '${_formattingService.formatStockQuantity(_product.minQuantity.round())} ${_product.unit}',
        ),
        if (_product.maxQuantity != null)
          DetailRow(
            label: 'الحد الأقصى',
            value:
                '${_formattingService.formatStockQuantity(_product.maxQuantity!.round())} ${_product.unit}',
          ),
        DetailRow(
          label: 'قيمة المخزون',
          value: _formattingService.formatCurrency(_product.inventoryValue),
        ),
      ],
    );
  }

  Widget _buildStatusCard({String? createdByName, String? updatedByName}) {
    return InfoCard(
      title: 'حالة المخزون',
      icon: Icons.analytics,
      children: [
        StatusRow(
          label: 'حالة المخزون',
          value: _getStockStatus(),
          color: _getStockStatusColor(),
        ),
        DetailRow(label: 'آخر تحديث', value: _formatDate(_product.updatedAt)),
        if (_product.updatedBy != null && updatedByName != null)
          DetailRow(label: 'تم التحديث بواسطة', value: updatedByName),
        DetailRow(
          label: 'تاريخ الإنشاء',
          value: _formatDate(_product.createdAt),
        ),
        DetailRow(
          label: 'تم الإنشاء بواسطة',
          value: createdByName ?? 'غير محدد',
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    final inventoryBloc = context.read<InventoryBloc>();

    return ActionButtons(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final bloc = context.read<InventoryBloc>();
                  final product = _product;
                  final result = await Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.editProduct, arguments: product);
                  if (!mounted || result != true) return;
                  bloc.add(
                    LoadProductsPaginatedEvent(
                      organizationEmail: product.organizationEmail,
                      isRefresh: true,
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('تعديل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AssyrianTheme.primaryGold,
                  foregroundColor: AssyrianTheme.deepBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: inventoryBloc,
                        child: ProductLogsPage(
                          productId: _product.id,
                          productName: _product.name,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('سجل الحركة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getStockStatus() {
    if (_product.isOutOfStock) {
      return 'نافد';
    } else if (_product.isLowStock) {
      return 'منخفض';
    } else {
      return 'متوفر';
    }
  }

  Color _getStockStatusColor() {
    if (_product.isOutOfStock) {
      return Colors.red;
    } else if (_product.isLowStock) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month}/${date.year}';
  }
}
