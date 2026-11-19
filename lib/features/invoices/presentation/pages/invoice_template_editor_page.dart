import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../domain/entities/invoice_template_entity.dart';
import '../bloc/invoice_bloc.dart';

class InvoiceTemplateEditorPage extends StatefulWidget {
  const InvoiceTemplateEditorPage({
    required this.organizationEmail,
    this.template,
    super.key,
  });

  final String organizationEmail;
  final InvoiceTemplateEntity? template;

  @override
  State<InvoiceTemplateEditorPage> createState() =>
      _InvoiceTemplateEditorPageState();
}

class _InvoiceTemplateEditorPageState extends State<InvoiceTemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _footerController;

  String _selectedType = 'sales';
  Color _headerColor = const Color(0xFF1B365D);
  Color _accentColor = const Color(0xFFD4AF37);
  bool _showLogo = true;
  String _logoPosition = 'right';
  bool _showCompanyInfo = true;
  bool _showCustomerInfo = true;
  bool _showItemsTable = true;
  bool _showNotes = true;
  bool _showSignature = false;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.template != null) {
      final template = widget.template!;
      _nameController = TextEditingController(text: template.name);
      _footerController = TextEditingController(text: template.footerText);
      _selectedType = template.type;
      _headerColor = _hexToColor(template.headerColor);
      _accentColor = _hexToColor(template.accentColor);
      _showLogo = template.showLogo;
      _logoPosition = template.logoPosition;
      _showCompanyInfo = template.showCompanyInfo;
      _showCustomerInfo = template.showCustomerInfo;
      _showItemsTable = template.showItemsTable;
      _showNotes = template.showNotes;
      _showSignature = template.showSignature;
      _isDefault = template.isDefault;
    } else {
      _nameController = TextEditingController();
      _footerController = TextEditingController(text: 'شكراً لتعاملكم معنا');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _buildBasicInfoSection(),
            SizedBox(height: 20.h),
            _buildColorsSection(),
            SizedBox(height: 20.h),
            _buildDisplayOptionsSection(),
            SizedBox(height: 20.h),
            _buildFooterSection(),
            SizedBox(height: 80.h), // مساحة للـ FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'invoices_template_save_fab',
        onPressed: _saveTemplate,
        backgroundColor: AssyrianTheme.primaryGold,
        foregroundColor: AssyrianTheme.deepBlue,
        tooltip: 'حفظ القالب',
        child: Icon(Icons.save, size: 28.sp),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
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
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: AssyrianTheme.primaryGold,
          size: 24.sp,
        ),
        onPressed: () => Navigator.pop(context),
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
                  widget.template == null ? 'قالب جديد' : 'تعديل القالب',
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
                  'قوالب الفواتير',
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

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AssyrianTheme.primaryGold,
                        AssyrianTheme.primaryGold.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'المعلومات الأساسية',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 18.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم القالب',
                labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال اسم القالب';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: 'نوع الفاتورة',
                labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                    width: 2,
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'sales', child: Text('مبيعات')),
                DropdownMenuItem(value: 'purchase', child: Text('مشتريات')),
                DropdownMenuItem(value: 'subscription', child: Text('اشتراك')),
                DropdownMenuItem(value: 'maintenance', child: Text('صيانة')),
                DropdownMenuItem(value: 'rental', child: Text('إيجار')),
                DropdownMenuItem(value: 'cash', child: Text('نقدية')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            SizedBox(height: 16.h),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8.r),
                child: SwitchListTile(
                title: const Text(
                  'جعل هذا القالب افتراضياً',
                  style: TextStyle(
                    color: AssyrianTheme.deepBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _isDefault,
                activeTrackColor: AssyrianTheme.primaryGold,
                onChanged: (value) {
                  setState(() {
                    _isDefault = value;
                  });
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AssyrianTheme.primaryGold,
                        AssyrianTheme.primaryGold.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'الألوان',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 18.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ListTile(
              title: const Text(
                'لون الهيدر',
                style: TextStyle(
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Container(
                width: 50.w,
                height: 50.h,
                decoration: BoxDecoration(
                  color: _headerColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AssyrianTheme.primaryGold,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _headerColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              onTap: () => _pickColor(
                context,
                _headerColor,
                (color) => setState(() => _headerColor = color),
              ),
            ),
            ListTile(
              title: const Text(
                'اللون الثانوي',
                style: TextStyle(
                  color: AssyrianTheme.deepBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Container(
                width: 50.w,
                height: 50.h,
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: AssyrianTheme.primaryGold,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              onTap: () => _pickColor(
                context,
                _accentColor,
                (color) => setState(() => _accentColor = color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayOptionsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AssyrianTheme.primaryGold,
                        AssyrianTheme.primaryGold.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.visibility_outlined,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'خيارات العرض',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 18.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text(
                'إظهار الشعار',
                style: TextStyle(color: AssyrianTheme.deepBlue),
              ),
              value: _showLogo,
              activeThumbColor: AssyrianTheme.primaryGold,
              onChanged: (value) => setState(() => _showLogo = value),
            ),
            if (_showLogo)
              Padding(
                padding: EdgeInsets.only(right: 16.w, left: 16.w, bottom: 8.h),
                child: DropdownButtonFormField<String>(
                  initialValue: _logoPosition,
                  decoration: InputDecoration(
                    labelText: 'موقع الشعار',
                    labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                        width: 2,
                      ),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'left', child: Text('يسار')),
                    DropdownMenuItem(value: 'center', child: Text('وسط')),
                    DropdownMenuItem(value: 'right', child: Text('يمين')),
                  ],
                  onChanged: (value) {
                    setState(() => _logoPosition = value!);
                  },
                ),
              ),
            SwitchListTile(
              title: const Text(
                'إظهار معلومات الشركة',
                style: TextStyle(color: AssyrianTheme.deepBlue),
              ),
              value: _showCompanyInfo,
              activeThumbColor: AssyrianTheme.primaryGold,
              onChanged: (value) => setState(() => _showCompanyInfo = value),
            ),
            SwitchListTile(
              title: const Text(
                'إظهار معلومات العميل',
                style: TextStyle(color: AssyrianTheme.deepBlue),
              ),
              value: _showCustomerInfo,
              activeThumbColor: AssyrianTheme.primaryGold,
              onChanged: (value) => setState(() => _showCustomerInfo = value),
            ),
            SwitchListTile(
              title: const Text(
                'إظهار جدول الأصناف',
                style: TextStyle(color: AssyrianTheme.deepBlue),
              ),
              value: _showItemsTable,
              activeThumbColor: AssyrianTheme.primaryGold,
              onChanged: (value) => setState(() => _showItemsTable = value),
            ),
            SwitchListTile(
              title: const Text(
                'إظهار الملاحظات',
                style: TextStyle(color: AssyrianTheme.deepBlue),
              ),
              value: _showNotes,
              activeThumbColor: AssyrianTheme.primaryGold,
              onChanged: (value) => setState(() => _showNotes = value),
            ),
            SwitchListTile(
              title: const Text(
                'إظهار التوقيع',
                style: TextStyle(color: AssyrianTheme.deepBlue),
              ),
              value: _showSignature,
              activeThumbColor: AssyrianTheme.primaryGold,
              onChanged: (value) => setState(() => _showSignature = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AssyrianTheme.primaryGold,
                        AssyrianTheme.primaryGold.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.text_fields,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'التذييل',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: 18.sp,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _footerController,
              decoration: InputDecoration(
                labelText: 'نص التذييل',
                labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(
                    color: AssyrianTheme.primaryGold,
                    width: 2,
                  ),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  void _pickColor(
    BuildContext context,
    Color currentColor,
    ValueChanged<Color> onColorChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر اللون'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: onColorChanged,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  void _saveTemplate() {
    if (!_formKey.currentState!.validate()) return;

    final template = InvoiceTemplateEntity(
      id:
          widget.template?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      type: _selectedType,
      headerColor: _colorToHex(_headerColor),
      accentColor: _colorToHex(_accentColor),
      showLogo: _showLogo,
      logoPosition: _logoPosition,
      showCompanyInfo: _showCompanyInfo,
      showCustomerInfo: _showCustomerInfo,
      showItemsTable: _showItemsTable,
      showNotes: _showNotes,
      showSignature: _showSignature,
      footerText: _footerController.text,
      isDefault: _isDefault,
    );

    context.read<InvoiceBloc>().add(
      SaveInvoiceTemplateEvent(
        template: template,
        organizationEmail: widget.organizationEmail,
      ),
    );

    // العودة للصفحة السابقة
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Color _hexToColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}

/// Widget لاختيار الألوان (بديل بسيط عن flutter_colorpicker)
class ColorPicker extends StatefulWidget {
  const ColorPicker({
    required this.pickerColor,
    required this.onColorChanged,
    this.showLabel = true,
    this.pickerAreaHeightPercent = 0.8,
    super.key,
  });

  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;
  final bool showLabel;
  final double pickerAreaHeightPercent;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late Color _color;

  @override
  void initState() {
    super.initState();
    _color = widget.pickerColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ألوان سريعة
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _colorButton(Colors.red),
            _colorButton(Colors.pink),
            _colorButton(Colors.purple),
            _colorButton(Colors.deepPurple),
            _colorButton(Colors.indigo),
            _colorButton(Colors.blue),
            _colorButton(Colors.lightBlue),
            _colorButton(Colors.cyan),
            _colorButton(Colors.teal),
            _colorButton(Colors.green),
            _colorButton(Colors.lightGreen),
            _colorButton(Colors.lime),
            _colorButton(Colors.yellow),
            _colorButton(Colors.amber),
            _colorButton(Colors.orange),
            _colorButton(Colors.deepOrange),
            _colorButton(Colors.brown),
            _colorButton(Colors.grey),
            _colorButton(Colors.blueGrey),
            _colorButton(Colors.black),
          ],
        ),
        SizedBox(height: 16.h),
        // عرض اللون المحدد
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
          child: Center(
            child: Text(
              '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(
                color: _color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorButton(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() => _color = color);
        widget.onColorChanged(color);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _color == color ? Colors.white : Colors.grey,
            width: _color == color ? 3 : 1,
          ),
        ),
        child: _color == color
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
