import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/theme/assyrian_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardView();
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    // لا يتم تحميل بيانات المستخدمين هنا عمداً لتجنب تحميل غير ضروري في لوحة المعلومات الرئيسية.
    // يتم تحميل المستخدمين عند الحاجة فقط عبر مربع حوار تبديل الدور.
  }

  /// التعامل مع زر الرجوع - الخروج من التطبيق عند الضغط مرتين
  Future<void> _handleBackButton() async {
    final now = DateTime.now();
    final shouldExit =
        _lastPressedAt == null ||
        now.difference(_lastPressedAt!) > const Duration(seconds: 2);

    if (shouldExit) {
      // الضغط الأول - إظهار رسالة تأكيد
      _lastPressedAt = now;

      // إظهار SnackBar مع رسالة التأكيد
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'اضغط مرة أخرى للخروج من التطبيق',
              style: TextStyle(fontSize: 14.sp, fontFamily: 'Cairo'),
            ),
            backgroundColor: AssyrianTheme.primaryGold,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      // الضغط الثاني - الخروج من التطبيق
      await _exitApp();
    }
  }

  /// الخروج من التطبيق
  Future<void> _exitApp() async {
    if (!mounted) return;

    // إظهار حوار التأكيد
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          backgroundColor: AssyrianTheme.ivoryWhite,
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AssyrianTheme.crimsonRed,
                size: 28.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                'تأكيد الخروج',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد أنك تريد الخروج من التطبيق؟',
            style: TextStyle(
              fontSize: 14.sp,
              fontFamily: 'Cairo',
              color: AssyrianTheme.deepBlue.withValues(alpha: 0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: 'Cairo',
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.crimsonRed,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'خروج',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      // الخروج من التطبيق (يدعم Android فقط؛ على iOS يستخدم النظام إدارة المسارات)
      if (Platform.isAndroid) {
        await SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // التعامل مع زر الرجوع - الخروج عند الضغط مرتين
        _handleBackButton();
      },
      child: scaffold.ResponsiveScaffold(
        appBar: AppBar(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'الصفحة الرئيسية',
                      style: AssyrianTheme.titleStyle.copyWith(
                        fontSize: 18.sp,
                        color: AssyrianTheme.primaryGold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'نظام إدارة المستخدمين الآشوري',
                      style: AssyrianTheme.subtitleStyle.copyWith(
                        fontSize: 10.sp,
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
        ),
        drawer: const DashboardDrawer(),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
        ), // هوامش متناسقة مع باقي الداشبوردات
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              WelcomeCard(),
              const QuickActionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
