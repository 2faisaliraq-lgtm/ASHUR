import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

/// صفحة إضافة رف جديد
class CreateShelfPage extends StatefulWidget {
  const CreateShelfPage({super.key});

  @override
  State<CreateShelfPage> createState() => _CreateShelfPageState();
}

class _CreateShelfPageState extends State<CreateShelfPage>
    with SaveOperationMixin {
  // حماية من الحفظ المتكرر
  bool _operationCompleted = false;

  final FormattingService _formattingService = FormattingService();
  final _formKey = GlobalKey<FormState>();

  // Controllers للحقول النصية
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();

  // متغيرات للحقول الأخرى
  String? _selectedZone;
  bool _isActive = true;

  // قوائم للبيانات المرتبطة
  final List<String> _zones = [
    'المنطقة أ',
    'المنطقة ب',
    'المنطقة ج',
    'المنطقة د',
    'مخزن رئيسي',
    'مخزن فرعي',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const InventoryDrawer(currentRoute: 'shelves'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listenWhen: (previous, current) {
          return current is InventoryError ||
              current is InventoryOperationSuccess;
        },
        listener: (context, state) {
          if (state is InventoryOperationSuccess && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: state.message,
              onSuccess: () => Navigator.of(context).pop(true),
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
                  'إضافة رف جديد',
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
                  'نظام إدارة المخزن الآشوري',
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
          onPressed: () => Navigator.of(context).pop(),
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
    return const DetailScreenHeader(
      title: 'إضافة رف جديد',
      subtitle: 'إنشاء رف جديد وإضافته إلى قاعدة البيانات',
      icon: Icons.shelves,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context, bool isLoading) {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('المعلومات الأساسية'),
            const SizedBox(height: 12),
            _buildNameField(),
            const SizedBox(height: 12),
            _buildDescriptionField(),
            const SizedBox(height: 12),
            _buildLocationField(),
            const SizedBox(height: 12),
            _buildZoneDropdown(),
            const SizedBox(height: 20),

            _buildSectionTitle('السعة والإعدادات'),
            const SizedBox(height: 12),
            _buildCapacityField(),
            const SizedBox(height: 12),
            _buildActiveSwitch(),
            const SizedBox(height: 24),

            _buildSubmitButton(isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AssyrianTheme.deepBlue,
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

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: InputDecoration(
        labelText: 'الموقع',
        hintText: 'أدخل موقع الرف (اختياري)',
        prefixIcon: const Icon(
          Icons.location_on,
          color: AssyrianTheme.primaryGold,
        ),
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
      initialValue: _selectedZone,
      decoration: InputDecoration(
        labelText: 'المنطقة',
        hintText: 'اختر المنطقة (اختياري)',
        prefixIcon: const Icon(Icons.map, color: AssyrianTheme.primaryGold),
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
            (zone) => DropdownMenuItem<String>(value: zone, child: Text(zone)),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedZone = value;
        });
      },
    );
  }

  Widget _buildCapacityField() {
    return TextFormField(
      controller: _capacityController,
      keyboardType: TextInputType.number,
      inputFormatters: [_formattingService.getQuantityInputFormatter()],
      decoration: InputDecoration(
        labelText: 'السعة القصوى',
        hintText: 'أدخل عدد العناصر القصوى',
        prefixIcon: const Icon(
          Icons.inventory,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'عنصر',
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
          return null; // حقل اختياري
        }
        final capacity = int.tryParse(value.replaceAll(',', ''));
        if (capacity == null) {
          return 'يجب إدخال رقم صحيح';
        }
        if (capacity < 1) {
          return 'يجب أن تكون السعة أكبر من صفر';
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
            });
          },
          activeTrackColor: AssyrianTheme.primaryGold,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: LoadingButton(
        text: 'إنشاء الرف',
        onPressed: _createShelf,
        isLoading: isLoading,
        icon: Icons.add,
        backgroundColor: AssyrianTheme.primaryGold,
        foregroundColor: AssyrianTheme.deepBlue,
      ),
    );
  }

  Future<void> _createShelf() async {
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

    // الحصول على معرف المستخدم
    String createdBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdBy = switchedUser['id'] as String;
      } else {
        createdBy = currentUser.uid;
      }
    } on Exception catch (_) {
      createdBy = currentUser.uid;
    }

    final shelf = ShelfEntity(
      id: '', // سيتم إنشاؤه تلقائياً
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      zone: _selectedZone,
      capacity: _capacityController.text.trim().isEmpty
          ? 0
          : int.parse(_capacityController.text.trim().replaceAll(',', '')),
      isActive: _isActive,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      organizationEmail: currentUser.email!,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ InventoryBloc قبل العملية غير المتزامنة
    final inventoryBloc = context.read<InventoryBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        inventoryBloc.add(CreateShelf(shelf: shelf));
      },
      successMessage: 'تم إنشاء الرف بنجاح',
      loadingMessage: 'جاري إنشاء الرف...',
    );
  }
}
