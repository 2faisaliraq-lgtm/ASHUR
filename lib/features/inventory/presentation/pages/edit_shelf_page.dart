import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/email/email_normalization_service.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/shelf_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../widgets/inventory_drawer.dart';

/// صفحة تعديل الرف
class EditShelfPage extends StatefulWidget {
  const EditShelfPage({required this.shelf, super.key});
  final ShelfEntity shelf;

  @override
  State<EditShelfPage> createState() => _EditShelfPageState();
}

class _EditShelfPageState extends State<EditShelfPage>
    with SaveOperationMixin<EditShelfPage> {
  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final _formKey = GlobalKey<FormState>();

  // Controllers للحقول النصية
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedZone;
  bool _isActive = true;

  // قائمة المناطق
  final List<Map<String, String>> _zones = [
    {'id': 'zone_a', 'name': 'المنطقة أ'},
    {'id': 'zone_b', 'name': 'المنطقة ب'},
    {'id': 'zone_c', 'name': 'المنطقة ج'},
    {'id': 'zone_d', 'name': 'المنطقة د'},
    {'id': 'storage', 'name': 'منطقة التخزين'},
    {'id': 'display', 'name': 'منطقة العرض'},
  ];

  // متغير لتتبع التغييرات
  bool _hasChanges = false;

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;
  bool _isDeleting = false; // للتمييز بين التحديث والحذف

  // متغيرات لأسماء المستخدمين
  String? _createdByName;
  String? _updatedByName;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _setupChangeListeners();
    _loadUserNames();
  }

  void _initializeFields() {
    _nameController.text = widget.shelf.name;
    _descriptionController.text = widget.shelf.description ?? '';
    _locationController.text = widget.shelf.location ?? '';
    _capacityController.text = widget.shelf.capacity.toString();
    _selectedZone = widget.shelf.zone;
    _isActive = widget.shelf.isActive;
  }

  void _setupChangeListeners() {
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _capacityController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserNames() async {
    String? createdByName;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null &&
          switchedUser['id'] == widget.shelf.createdBy) {
        createdByName = switchedUser['name'] as String?;
      }
      createdByName ??= await _getUserNameFromFirebase(widget.shelf.createdBy);
    } on Exception catch (_) {
      createdByName = await _getUserNameFromFirebase(widget.shelf.createdBy);
    }

    String? updatedByName;
    if (widget.shelf.updatedBy != null) {
      try {
        final switchedUser = await SessionService.getSwitchedUser();
        if (switchedUser != null &&
            switchedUser['id'] == widget.shelf.updatedBy) {
          updatedByName = switchedUser['name'] as String?;
        }
        updatedByName ??= await _getUserNameFromFirebase(
          widget.shelf.updatedBy!,
        );
      } on Exception catch (_) {
        updatedByName = await _getUserNameFromFirebase(widget.shelf.updatedBy!);
      }
    }

    if (mounted) {
      setState(() {
        _createdByName = createdByName ?? 'غير محدد';
        _updatedByName = updatedByName;
      });
    }
  }

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
            if (name != null && name.isNotEmpty) return name;
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
    } on Exception catch (_) {}
    return userId;
  }

  Future<bool> _handleBackPress() async {
    if (!_hasChanges) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text(
          'لديك تغييرات غير محفوظة. هل تريد الخروج بدون حفظ؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('خروج بدون حفظ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              _updateShelf();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: AssyrianTheme.deepBlue,
            ),
            child: const Text('حفظ والخروج'),
          ),
        ],
      ),
    );

    if (shouldDiscard ?? false) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: scaffold.ResponsiveScaffold(
        appBar: _buildAppBar(context),
        drawer: const InventoryDrawer(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        body: BlocConsumer<InventoryBloc, InventoryState>(
          listenWhen: (previous, current) {
            return current is InventoryError ||
                current is InventoryOperationSuccess;
          },
          listener: (context, state) {
            if (state is InventoryOperationSuccess && !_operationCompleted) {
              _operationCompleted = true;
              final message = _isDeleting
                  ? 'تم حذف الرف بنجاح'
                  : 'تم تحديث الرف بنجاح';
              completeSaveOperation(
                successMessage: message,
                onSuccess: () =>
                    Navigator.of(context).pop(_isDeleting ? 'deleted' : true),
              );
            } else if (state is InventoryError && !_operationCompleted) {
              _operationCompleted = true;
              failSaveOperation(errorMessage: state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is InventoryLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _buildWelcomeCard(context),
                  const SizedBox(height: 6),
                  _buildFormCard(context, isLoading),
                ],
              ),
            );
          },
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
              'تعديل الرف',
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
        if (_hasChanges)
          IconButton(
            onPressed: _updateShelf,
            icon: Icon(
              Icons.save,
              color: AssyrianTheme.primaryGold,
              size: 24.sp,
            ),
            tooltip: 'حفظ التغييرات',
          ),
        IconButton(
          onPressed: _handleBackPress,
          icon: Icon(
            Icons.close,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return DetailScreenHeader(
      title: 'تعديل ${widget.shelf.name}',
      subtitle: 'قم بتعديل معلومات الرف',
      icon: Icons.edit,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'المعلومات الأساسية',
            icon: Icons.info_outline,
            children: [
              _buildNameField(),
              _buildDescriptionField(),
              _buildZoneDropdown(),
              _buildLocationField(),
              _buildCapacityField(),
            ],
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'الإعدادات',
            icon: Icons.settings,
            children: [_buildActiveSwitch()],
          ),
          const SizedBox(height: 16),
          InfoCard(
            title: 'معلومات النظام',
            icon: Icons.info_outline,
            children: [_buildSystemInfo()],
          ),
          const SizedBox(height: 24),
          _buildActionButtons(isLoading),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'اسم الرف *',
        hintText: 'أدخل اسم الرف',
        prefixIcon: const Icon(Icons.shelves, color: AssyrianTheme.primaryGold),
        suffixIcon: _nameController.text != widget.shelf.name
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يجب إدخال اسم الرف';
        }
        if (value.trim().length < 2) {
          return 'يجب أن يكون الاسم أكثر من حرف واحد';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'الوصف',
        hintText: 'أدخل وصف الرف (اختياري)',
        prefixIcon: const Icon(
          Icons.description,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon:
            _descriptionController.text != (widget.shelf.description ?? '')
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildZoneDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _zones.any((zone) => zone['id'] == _selectedZone)
          ? _selectedZone
          : null,
      decoration: InputDecoration(
        labelText: 'المنطقة *',
        hintText: 'اختر المنطقة',
        prefixIcon: const Icon(
          Icons.location_city,
          color: AssyrianTheme.primaryGold,
        ),
        suffixIcon: _selectedZone != widget.shelf.zone
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
      items: _zones
          .map(
            (zone) => DropdownMenuItem<String>(
              value: zone['id'],
              child: Text(zone['name']!),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedZone = value;
          _onFieldChanged();
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يجب اختيار المنطقة';
        }
        return null;
      },
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: InputDecoration(
        labelText: 'الموقع التفصيلي',
        hintText: 'أدخل الموقع التفصيلي للرف',
        prefixIcon: const Icon(Icons.place, color: AssyrianTheme.primaryGold),
        suffixIcon: _locationController.text != (widget.shelf.location ?? '')
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildCapacityField() {
    return TextFormField(
      controller: _capacityController,
      keyboardType: TextInputType.number,
      inputFormatters: [_formattingService.getQuantityInputFormatter()],
      decoration: InputDecoration(
        labelText: 'السعة القصوى',
        hintText: 'أدخل السعة القصوى للرف',
        prefixIcon: const Icon(
          Icons.inventory,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'عنصر',
        suffixIcon: _capacityController.text != widget.shelf.capacity.toString()
            ? Icon(Icons.edit, color: Colors.orange, size: 16.sp)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AssyrianTheme.primaryGold,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          final capacity = int.tryParse(value.replaceAll(',', ''));
          if (capacity == null) {
            return 'يجب إدخال رقم صحيح';
          }
          if (capacity < 0) {
            return 'يجب أن تكون السعة أكبر من أو تساوي صفر';
          }
        }
        return null;
      },
    );
  }

  Widget _buildActiveSwitch() {
    return Row(
      children: [
        const Icon(Icons.toggle_on, color: AssyrianTheme.primaryGold),
        const SizedBox(width: 8),
        Text(
          'الرف نشط',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        const Spacer(),
        Switch(
          value: _isActive,
          onChanged: (value) {
            setState(() {
              _isActive = value;
              _onFieldChanged();
            });
          },
          activeTrackColor: AssyrianTheme.primaryGold,
        ),
        if (_isActive != widget.shelf.isActive)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.edit, color: Colors.orange, size: 16.sp),
          ),
      ],
    );
  }

  Widget _buildSystemInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildReadOnlyRow(
            'تاريخ الإنشاء',
            DateFormat('dd/MM/yyyy HH:mm').format(widget.shelf.createdAt),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow('تم الإنشاء بواسطة', _createdByName ?? 'غير محدد'),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            'آخر تحديث',
            DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(widget.shelf.updatedAt ?? DateTime.now()),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            'تم التحديث بواسطة',
            _updatedByName ?? widget.shelf.updatedBy ?? 'غير محدد',
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isLoading) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: LoadingButton(
                text: 'حفظ التغييرات',
                onPressed: _hasChanges ? _updateShelf : null,
                isLoading: isLoading,
                icon: Icons.save,
                backgroundColor: _hasChanges
                    ? AssyrianTheme.primaryGold
                    : Colors.grey[300]!,
                foregroundColor: _hasChanges
                    ? AssyrianTheme.deepBlue
                    : Colors.grey[600]!,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة تعيين'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
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
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete),
                label: const Text('حذف الرف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to shelf details if route exists
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('صفحة تفاصيل الرف قيد التطوير'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.visibility),
                label: const Text('عرض التفاصيل'),
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

  Future<void> _updateShelf() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    String updatedBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        updatedBy = switchedUser['id'] as String;
      } else {
        updatedBy = currentUser.uid;
      }
    } on Exception catch (_) {
      updatedBy = currentUser.uid;
    }

    final updatedShelf = widget.shelf.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      zone: _selectedZone,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      capacity: _capacityController.text.trim().isEmpty
          ? 0
          : int.tryParse(_capacityController.text.trim().replaceAll(',', '')) ??
                0,
      isActive: _isActive,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ InventoryBloc قبل العملية غير المتزامنة
    final inventoryBloc = context.read<InventoryBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        inventoryBloc.add(UpdateShelfEvent(updatedShelf));
      },
      successMessage: 'تم تحديث الرف بنجاح',
      navigateBackOnSuccess: true,
      loadingMessage: 'جاري تحديث الرف...',
    );
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين النموذج'),
        content: const Text(
          'هل تريد إعادة تعيين جميع الحقول إلى القيم الأصلية؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeFields();
              setState(() {
                _hasChanges = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إعادة تعيين النموذج'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28.sp),
            SizedBox(width: 8.w),
            const Text('تأكيد الحذف'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف رف "${widget.shelf.name}"؟\n'
          'لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteShelf();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteShelf() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;
    _isDeleting = true; // تعيين أننا في عملية حذف

    if (mounted) {
      context.read<InventoryBloc>().add(
        DeleteShelfEvent(
          shelfId: widget.shelf.id,
          organizationEmail: currentUser.email!,
        ),
      );
    }
  }
}
