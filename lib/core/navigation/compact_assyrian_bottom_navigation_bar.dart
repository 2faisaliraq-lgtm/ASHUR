import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/assyrian_theme.dart';
import 'navigation_item.dart';

/// شريط التنقل السفلي الآشوري المضغوط - بدون انيميشن ثقيل
class CompactAssyrianBottomNavigationBar extends StatelessWidget {
  const CompactAssyrianBottomNavigationBar({
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
    // عرض عنصر افتراضي ("الرئيسية") عند عدم توفر العناصر بعد، لتجنب ظهور الشريط السفلي فارغاً
    final displayItems = items.isEmpty
        ? [const NavigationItem(id: DefaultNavigationItems.dashboard, label: 'الرئيسية', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, page: SizedBox(), color: Colors.blue)]
        : items;

    return DecoratedBox(
      decoration: _decoration,
      child: SafeArea(
        child: Container(
          height: 55.h,
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(displayItems.length, (index) {
              final item = displayItems[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: _NavigationItem(
                  key: ValueKey('nav_${item.id}'),
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  static const BoxDecoration _decoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFAFFFFFF), Color(0x0CFFD700)],
    ),
    border: Border(top: BorderSide(color: Color(0x4DFFD700))),
    boxShadow: [
      BoxShadow(
        color: Color(0x26FFD700),
        blurRadius: 10,
        offset: Offset(0, -3),
      ),
    ],
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected
        ? AssyrianTheme.primaryGold
        : const Color(0xB3003366);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 0.5.w),
          padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 1.w),
          decoration: isSelected ? _selectedDecoration : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Icon(
                  isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                  size: 20.sp,
                  color: iconColor,
                ),
              ),
              if (isSelected) ...[
                SizedBox(height: 2.h),
                Flexible(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: AssyrianTheme.primaryGold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const BoxDecoration _selectedDecoration = BoxDecoration(
    color: Color(0x1AFFD700),
    borderRadius: BorderRadius.all(Radius.circular(8)),
    border: Border.fromBorderSide(
      BorderSide(color: Color(0x4DFFD700), width: 0.8),
    ),
  );
}
