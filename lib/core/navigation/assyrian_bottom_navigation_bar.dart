import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/session_service.dart';
import '../theme/assyrian_theme.dart';
import 'assyrian_navigation_decorations.dart';
import 'assyrian_navigation_effects.dart';
import 'compact_assyrian_bottom_navigation_bar.dart';
import 'navigation_item.dart';

/// شريط التنقل السفلي الآشوري المخصص
/// مصمم بالنمط الآشوري التقليدي مع عناصر الحضارة الآشورية
class AssyrianBottomNavigationBar extends StatelessWidget {
  const AssyrianBottomNavigationBar({
    required this.onTap,
    required this.currentIndex,
    required this.items,
    super.key,
  });
  final Function(int) onTap;
  final int currentIndex;
  final List<NavigationItem> items;

  @override
  Widget build(BuildContext context) {
    _printUserInfo();

    if (items.isEmpty) return const SizedBox.shrink();

    // استخدام النسخة المضغوطة إذا كان عدد العناصر أكثر من 5
    if (items.length > 5) {
      return CompactAssyrianBottomNavigationBar(
        onTap: onTap,
        currentIndex: currentIndex,
        items: items,
      );
    }

    // استخدام النسخة المضغوطة للشاشات الصغيرة أو عند وجود مساحة محدودة
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight =
        screenHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    // إذا كانت الشاشة صغيرة أو المساحة محدودة، استخدم النسخة المضغوطة
    if (screenHeight < 700 || availableHeight < 600) {
      return CompactAssyrianBottomNavigationBar(
        onTap: onTap,
        currentIndex: currentIndex,
        items: items,
      );
    }

    return Stack(
      children: [
        // الخلفية الآشورية مع النقوش
        AssyrianNavigationDecorations.buildAssyrianBackground(
          height:
              65.h + MediaQuery.of(context).padding.bottom, // تحديث الارتفاع
          child: Container(),
        ),
        // الحد العلوي الآشوري
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AssyrianNavigationDecorations.assyrianTopBorder,
        ),
        // محتوى الشريط
        DecoratedBox(
          decoration: _buildAssyrianDecoration(),
          child: SafeArea(
            child: Container(
              height: 65.h, // تقليل الارتفاع
              padding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: 4.h,
              ), // تقليل الحشو العمودي
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildNavigationItems(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// بناء عناصر التنقل مع الفواصل الآشورية
  List<Widget> _buildNavigationItems() {
    final widgets = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isSelected = i == currentIndex;

      widgets.add(
        Expanded(
          child: _buildAssyrianNavigationItem(item, isSelected, () => onTap(i)),
        ),
      );

      // إضافة فاصل آشوري بين العناصر (ما عدا العنصر الأخير)
      if (i < items.length - 1) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: AssyrianNavigationDecorations.assyrianDivider,
          ),
        );
      }
    }

    return widgets;
  }

  /// بناء الزخرفة الآشورية للشريط السفلي
  BoxDecoration _buildAssyrianDecoration() {
    return BoxDecoration(
      // تدرج لوني آشوري محسن
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AssyrianTheme.ivoryWhite.withValues(alpha: 0.95),
          AssyrianTheme.ivoryWhite.withValues(alpha: 0.98),
          AssyrianTheme.primaryGold.withValues(alpha: 0.08),
        ],
        stops: const [0.0, 0.6, 1.0],
      ),
      // ظلال آشورية متعددة الطبقات محسنة
      boxShadow: [
        // ظل ذهبي رئيسي
        BoxShadow(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, -8),
          spreadRadius: 2,
        ),
        // ظل أزرق للعمق
        BoxShadow(
          color: AssyrianTheme.deepBlue.withValues(alpha: 0.08),
          blurRadius: 15,
          offset: const Offset(0, -4),
        ),
        // ظل ناعم للحواف
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  /// بناء عنصر التنقل الآشوري
  Widget _buildAssyrianNavigationItem(
    NavigationItem item,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return AssyrianNavigationEffects.createRippleEffect(
      rippleColor: AssyrianTheme.primaryGold,
      onTap: () {
        AssyrianNavigationEffects.playSelectionHaptic();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        margin: EdgeInsets.symmetric(horizontal: 1.w), // تقليل الهامش
        padding: EdgeInsets.symmetric(
          vertical: 2.h,
          horizontal: 2.w,
        ), // تقليل الحشو
        decoration: _buildItemDecoration(isSelected, item.color),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الأيقونة مع تأثيرات آشورية
            Flexible(
              // استخدام Flexible بدلاً من العنصر الثابت
              child: AssyrianNavigationEffects.createGlowEffect(
                isActive: isSelected,
                glowColor: AssyrianTheme.primaryGold,
                child: _buildAssyrianIcon(item, isSelected),
              ),
            ),
            SizedBox(height: 2.h), // تقليل المسافة
            // النص مع الخط الآشوري
            Flexible(
              // استخدام Flexible للنص أيضاً
              child: _buildAssyrianLabel(item, isSelected),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء زخرفة العنصر المحدد
  BoxDecoration _buildItemDecoration(bool isSelected, Color? itemColor) {
    if (!isSelected) return const BoxDecoration();

    return BoxDecoration(
      // تدرج ذهبي محسن للعنصر المحدد
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AssyrianTheme.primaryGold.withValues(alpha: 0.18),
          AssyrianTheme.primaryGold.withValues(alpha: 0.12),
          AssyrianTheme.primaryGold.withValues(alpha: 0.06),
        ],
      ),
      borderRadius: BorderRadius.circular(16.r),
      // حدود ذهبية متدرجة
      border: Border.all(
        color: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
        width: 1.2,
      ),
      // ظلال آشورية للعنصر المحدد
      boxShadow: [
        // توهج ذهبي داخلي
        BoxShadow(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.15),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        // توهج خارجي ناعم
        BoxShadow(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
          spreadRadius: 1,
        ),
      ],
    );
  }

  /// بناء الأيقونة الآشورية
  Widget _buildAssyrianIcon(NavigationItem item, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      padding: EdgeInsets.all(isSelected ? 8.w : 6.w), // تقليل الحشو
      decoration: BoxDecoration(
        // خلفية دائرية ذهبية للأيقونة المحددة
        gradient: isSelected
            ? RadialGradient(
                colors: [
                  AssyrianTheme.primaryGold.withValues(alpha: 0.15),
                  AssyrianTheme.primaryGold.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              )
            : null,
        shape: BoxShape.circle,
        // حدود ذهبية للأيقونة المحددة
        border: isSelected
            ? Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
                width: 1.2,
              )
            : null,
        // ظل للأيقونة المحددة
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: isSelected ? 1.15 : 1.0,
        child: Icon(
          isSelected ? (item.activeIcon ?? item.icon) : item.icon,
          size: 22.sp, // تقليل حجم الأيقونة
          color: isSelected
              ? AssyrianTheme.primaryGold
              : AssyrianTheme.deepBlue.withValues(alpha: 0.65),
          // ظل للأيقونة المحددة
          shadows: isSelected
              ? [
                  Shadow(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  /// بناء النص الآشوري
  Widget _buildAssyrianLabel(NavigationItem item, bool isSelected) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: isSelected ? 10.sp : 9.sp, // تقليل حجم النص
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? AssyrianTheme.primaryGold
            : AssyrianTheme.deepBlue.withValues(alpha: 0.75),
        // ظل نصي آشوري محسن للعنصر المحدد
        shadows: isSelected
            ? [
                Shadow(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.4),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
                Shadow(
                  color: AssyrianTheme.deepBlue.withValues(alpha: 0.1),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ]
            : null,
      ),
      child: Text(
        item.label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// طباعة معلومات المستخدم (المبدل أو الأصلي)
  Future<void> _printUserInfo() async {
    final hasSwitchedUser = await SessionService.hasSwitchedUser();

    if (hasSwitchedUser) {
      final switchedUserData = await SessionService.getSwitchedUser();
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
    }
  }
}
