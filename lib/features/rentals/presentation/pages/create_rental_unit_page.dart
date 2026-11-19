import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/rental_unit_entity.dart';
import '../bloc/rental_unit_bloc.dart';
import '../bloc/rental_unit_event.dart';
import '../bloc/rental_unit_state.dart';
import '../widgets/rental_drawer.dart';

/// صفحة إضافة شيء للإيجار قابلة للإيجار جديدة
class CreateRentalUnitPage extends StatefulWidget {
  const CreateRentalUnitPage({super.key});

  @override
  State<CreateRentalUnitPage> createState() => _CreateRentalUnitPageState();
}

class _CreateRentalUnitPageState extends State<CreateRentalUnitPage>
    with SaveOperationMixin {
  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final _formKey = GlobalKey<FormState>();

  final _itemNameController = TextEditingController();
  final _itemDescriptionController = TextEditingController();
  final _rentalPriceController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _conditionController = TextEditingController();
  final _locationController = TextEditingController();
  final _specificationsController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedItemType;

  final List<Map<String, String>> _itemTypes = [
    {'id': 'car', 'name': 'سيارة'},
    {'id': 'property', 'name': 'عقار'},
    {'id': 'equipment', 'name': 'معدات'},
    {'id': 'furniture', 'name': 'أثاث'},
    {'id': 'electronics', 'name': 'إلكترونيات'},
    {'id': 'other', 'name': 'أخرى'},
  ];

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemDescriptionController.dispose();
    _rentalPriceController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _conditionController.dispose();
    _locationController.dispose();
    _specificationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const RentalDrawer(currentRoute: 'rental_units'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocListener<RentalUnitBloc, RentalUnitState>(
        listenWhen: (previous, current) {
          return current is RentalUnitError ||
              (current is RentalUnitOperationSuccess && isSaving);
        },
        listener: (context, state) {
          if (state is RentalUnitOperationSuccess && !_operationCompleted) {
            _operationCompleted = true;

            if (isSaving) {
              completeSaveOperation(
                successMessage: state.message,
                navigateBackOnSuccess: true,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            }
          } else if (state is RentalUnitError && !_operationCompleted) {
            _operationCompleted = true;
            if (isSaving) {
              failSaveOperation(errorMessage: state.message);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 6),
              _buildFormCard(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة شيء للإيجار جديدة',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 18.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'نظام إدارة الإيجارات',
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

  Widget _buildWelcomeCard() {
    return const DetailScreenHeader(
      title: 'إضافة شيء للإيجار قابلة للإيجار',
      subtitle: 'إنشاء وحدة جديدة وإضافتها إلى قاعدة البيانات',
      icon: Icons.home_work,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'معلومات الشيء',
            icon: Icons.home,
            children: [
              _buildTextField(
                controller: _itemNameController,
                label: 'اسم الشيء *',
                icon: Icons.home,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'اسم الشيء مطلوب';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _itemDescriptionController,
                label: 'وصف الشيء',
                icon: Icons.location_on,
              ),
              _builditemTypeDropdown(),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'المعلومات المالية',
            icon: Icons.attach_money,
            children: [
              _buildTextField(
                controller: _rentalPriceController,
                label: 'سعر الإيجار *',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_formattingService.getPriceInputFormatter()],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'سعر الإيجار مطلوب';
                  }
                  final cleanValue = value.replaceAll(',', '');
                  if (double.tryParse(cleanValue) == null) {
                    return 'أدخل رقم صحيح';
                  }
                  return null;
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'تفاصيل الشيء',
            icon: Icons.info,
            children: [
              _buildTextField(
                controller: _brandController,
                label: 'الماركة',
                icon: Icons.badge,
              ),
              _buildTextField(
                controller: _modelController,
                label: 'الموديل',
                icon: Icons.build,
              ),
              _buildTextField(
                controller: _yearController,
                label: 'السنة',
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                controller: _conditionController,
                label: 'الحالة',
                icon: Icons.star,
              ),
              _buildTextField(
                controller: _locationController,
                label: 'الموقع',
                icon: Icons.location_on,
              ),
              _buildTextField(
                controller: _specificationsController,
                label: 'المواصفات',
                icon: Icons.list_alt,
                maxLines: 3,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'ملاحظات',
            icon: Icons.note,
            children: [
              _buildTextField(
                controller: _notesController,
                label: 'ملاحظات',
                icon: Icons.note,
                maxLines: 3,
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: LoadingButton(
                  text: 'إنشاء الشيء',
                  onPressed: isSaving ? null : _createUnit,
                  isLoading: isSaving,
                  icon: Icons.home_work,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AssyrianTheme.deepBlue,
                    side: const BorderSide(color: AssyrianTheme.deepBlue),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        validator: validator,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
          ),
          labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
        ),
      ),
    );
  }

  Widget _builditemTypeDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedItemType,
        decoration: InputDecoration(
          labelText: 'نوع الشيء *',
          prefixIcon: Icon(
            Icons.category,
            size: 20.sp,
            color: AssyrianTheme.primaryGold,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
          ),
          labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
        ),
        items: _itemTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type['id'],
            child: Text(type['name']!),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedItemType = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'نوع الشيء مطلوب';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _createUnit() async {
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

    final unit = RentalUnitEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      organizationEmail: currentUser.email!,
      itemName: _itemNameController.text.trim(),
      itemDescription: _itemDescriptionController.text.trim().isEmpty
          ? null
          : _itemDescriptionController.text.trim(),
      itemType: _selectedItemType!,
      rentalPrice: double.parse(
        _rentalPriceController.text.trim().replaceAll(',', ''),
      ),
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? null
          : _modelController.text.trim(),
      year: _yearController.text.trim().isEmpty
          ? null
          : int.tryParse(_yearController.text.trim()),
      condition: _conditionController.text.trim().isEmpty
          ? null
          : _conditionController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      specifications: _specificationsController.text.trim().isEmpty
          ? null
          : _specificationsController.text.trim(),
      status: 'available',
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    if (!mounted) return;

    // الحصول على مرجع لـ RentalUnitBloc قبل العملية غير المتزامنة
    final rentalUnitBloc = context.read<RentalUnitBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        rentalUnitBloc.add(CreateRentalUnitEvent(unit));
      },
      successMessage: 'تم إنشاء الشيء بنجاح',
      loadingMessage: 'جاري إنشاء الشيء...',
    );
  }
}
