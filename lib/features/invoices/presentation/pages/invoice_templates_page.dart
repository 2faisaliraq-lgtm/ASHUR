import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/invoice_template_entity.dart';
import '../bloc/invoice_bloc.dart';
import 'invoice_template_preview_page.dart';

class InvoiceTemplatesPage extends StatefulWidget {
  const InvoiceTemplatesPage({required this.organizationEmail, super.key});

  final String organizationEmail;

  @override
  State<InvoiceTemplatesPage> createState() => _InvoiceTemplatesPageState();
}

class _InvoiceTemplatesPageState extends State<InvoiceTemplatesPage> {
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadSelectedTemplate();
  }

  void _loadTemplates() {
    context.read<InvoiceBloc>().add(
      LoadInvoiceTemplatesEvent(widget.organizationEmail),
    );
  }

  Future<void> _loadSelectedTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getString('selected_template_id');
    if (selectedId != null && mounted) {
      setState(() {
        _selectedTemplateId = selectedId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildResponsiveAppBar(context),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      body: BlocConsumer<InvoiceBloc, InvoiceState>(
        listener: (context, state) {
          if (state is InvoiceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is InvoiceLoading) {
            return LoadingWidget(message: 'جاري تحميل القوالب...');
          }

          if (state is InvoiceTemplatesLoaded) {
            if (state.templates.isEmpty) {
              return AppEmptyState(
                icon: Icons.description_outlined,
                title: 'لا توجد قوالب',
                message: 'القوالب المتاحة ستظهر هنا',
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _loadTemplates(),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 16.h,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: state.templates.length,
                  itemBuilder: (context, index) {
                    final template = state.templates[index];
                    return _buildTemplateCard(template, state.templates);
                  },
                ),
              ),
            );
          }

          return const SizedBox();
        },
      ),
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
                  'قوالب الفواتير',
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
          icon: Icon(
            Icons.refresh,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
          onPressed: _loadTemplates,
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildTemplateCard(InvoiceTemplateEntity template, List<InvoiceTemplateEntity> allTemplates) {
    final headerColor = _hexToColor(template.headerColor);
    final accentColor = _hexToColor(template.accentColor);
    final isSelected = _selectedTemplateId == template.id;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: LinearGradient(
          colors: isSelected
              ? [
                  AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                  AssyrianTheme.primaryGold.withValues(alpha: 0.08),
                ]
              : [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.98),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isSelected ? AssyrianTheme.primaryGold : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AssyrianTheme.primaryGold.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isSelected ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTemplatePreview(template, allTemplates),
          borderRadius: BorderRadius.circular(12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // معاينة مصغرة للتصميم
              Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.r),
                        topRight: Radius.circular(12.r),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              headerColor.withValues(alpha: 0.15),
                              Colors.white,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: _buildMiniPreview(headerColor, accentColor, template),
                      ),
                    ),
                    // شارة القالب النشط
                    if (isSelected)
                      Positioned(
                        top: 6.h,
                        right: 6.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AssyrianTheme.primaryGold,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // معلومات القالب
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // اسم القالب
                      Text(
                        template.name,
                        style: AssyrianTheme.titleStyle.copyWith(
                          fontSize: 12.sp,
                          color: isSelected
                              ? AssyrianTheme.primaryGold
                              : AssyrianTheme.deepBlue,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      // نوع القالب
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          _getTemplateTypeName(template.type),
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      // زر التحديد
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _selectTemplate(template),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? AssyrianTheme.primaryGold
                                    : Colors.transparent,
                                foregroundColor: isSelected
                                    ? Colors.white
                                    : AssyrianTheme.deepBlue,
                                elevation: isSelected ? 3 : 0,
                                padding: EdgeInsets.symmetric(vertical: 4.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AssyrianTheme.primaryGold
                                      : accentColor.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check_circle, size: 16.sp, color: Colors.white)
                                  : Text(
                                      'تحديد',
                                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTemplateTypeName(String type) {
    switch (type) {
      case 'sales': return 'مبيعات';
      case 'purchase': return 'مشتريات';
      case 'subscription': return 'اشتراك';
      case 'maintenance': return 'صيانة';
      case 'rental': return 'إيجار';
      case 'cash': return 'نقدية';
      default: return 'عامة';
    }
  }

  Widget _buildMiniPreview(
    Color headerColor,
    Color accentColor,
    InvoiceTemplateEntity template,
  ) {
    return Column(
      children: [
        // الهيدر المصغر
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: headerColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (template.showCompanyInfo)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 8.h,
                          width: 80.w,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          height: 4.h,
                          width: 50.w,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                if (template.showLogo)
                  Container(
                    width: 30.w,
                    height: 30.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Icon(Icons.business, size: 16.sp, color: headerColor),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 6.h,
                        width: 60.w,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      SizedBox(height: 3.h),
                      Container(
                        height: 4.h,
                        width: 40.w,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // جسم الفاتورة المصغر
        Expanded(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              children: [
                if (template.showCustomerInfo)
                  Container(
                    margin: EdgeInsets.only(bottom: 6.h),
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: accentColor, width: 1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 4.h,
                          width: 40.w,
                          color: accentColor.withValues(alpha: 0.5),
                        ),
                        Spacer(),
                        Container(
                          height: 4.h,
                          width: 40.w,
                          color: accentColor.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                
                if (template.showItemsTable)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: accentColor, width: 1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Column(
                        children: [
                          // رأس الجدول
                          Container(
                            height: 12.h,
                            color: headerColor.withValues(alpha: 0.3),
                            child: Row(
                              children: [
                                Expanded(child: Container(height: 4.h, width: 30.w, color: headerColor.withValues(alpha: 0.7))),
                                Expanded(child: Container(height: 4.h, width: 30.w, color: headerColor.withValues(alpha: 0.7))),
                                Expanded(child: Container(height: 4.h, width: 30.w, color: headerColor.withValues(alpha: 0.7))),
                              ],
                            ),
                          ),
                          // صفوف البيانات
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Container(height: 3.h, color: Colors.grey[300])),
                                      Expanded(child: Container(height: 3.h, color: Colors.grey[300])),
                                      Expanded(child: Container(height: 3.h, color: Colors.grey[300])),
                                    ],
                                  ),
                                  SizedBox(height: 3.h),
                                  Row(
                                    children: [
                                      Expanded(child: Container(height: 3.h, color: Colors.grey[200])),
                                      Expanded(child: Container(height: 3.h, color: Colors.grey[200])),
                                      Expanded(child: Container(height: 3.h, color: Colors.grey[200])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // التذييل المصغر
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: accentColor, width: 1)),
            ),
            child: Center(
              child: Container(
                height: 3.h,
                width: 100.w,
                color: accentColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTemplatePreview(InvoiceTemplateEntity template, List<InvoiceTemplateEntity> allTemplates) async {
    // تحميل جميع القوالب مسبقاً قبل فتح المعاينة
    await InvoiceTemplatePreviewPage.preloadTemplate(template);
    for (final t in allTemplates) {
      if (t.id != template.id) {
        await InvoiceTemplatePreviewPage.preloadTemplate(t);
      }
    }
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceTemplatePreviewPage(
          template: template,
          allTemplates: allTemplates,
        ),
      ),
    ).then((selectedId) async {
      // عند العودة من صفحة المعاينة
      if (selectedId != null && mounted) {
        setState(() {
          _selectedTemplateId = selectedId;
        });
        
        // حفظ القالب المحدد في الذاكرة المحلية
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_template_id', selectedId);
        
        // إظهار رسالة نجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم تحديد القالب بنجاح'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _selectTemplate(InvoiceTemplateEntity template) async {
    setState(() {
      _selectedTemplateId = template.id;
    });
    
    // حفظ القالب المحدد في الذاكرة المحلية
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_template_id', template.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تحديد "${template.name}" كقالب للطباعة'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Color _hexToColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
