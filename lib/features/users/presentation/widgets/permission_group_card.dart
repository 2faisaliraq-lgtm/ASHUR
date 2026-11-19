import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/assyrian_theme.dart';

/// بطاقة مجموعة صلاحيات قابلة للطي
class PermissionGroupCard extends StatefulWidget {
  const PermissionGroupCard({
    super.key,
    required this.groupName,
    required this.groupIcon,
    required this.permissions,
    required this.selectedPermissions,
    required this.onPermissionsChanged,
    this.initiallyExpanded = false,
  });

  final String groupName;
  final IconData groupIcon;
  final List<MapEntry<String, String>>
  permissions; // key: permissionId, value: displayName
  final List<String> selectedPermissions;
  final Function(List<String>) onPermissionsChanged;
  final bool initiallyExpanded;

  @override
  State<PermissionGroupCard> createState() => _PermissionGroupCardState();
}

class _PermissionGroupCardState extends State<PermissionGroupCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  /// التحقق مما إذا كانت جميع الصلاحيات محددة
  bool get _areAllSelected {
    if (widget.permissions.isEmpty) return false;
    return widget.permissions.every(
      (perm) => widget.selectedPermissions.contains(perm.key),
    );
  }

  /// تبديل تحديد جميع الصلاحيات
  void _toggleAll(bool? value) {
    var newSelected = List<String>.from(widget.selectedPermissions);

    if (value == true) {
      // إضافة جميع صلاحيات القسم
      for (final perm in widget.permissions) {
        if (!newSelected.contains(perm.key)) {
          newSelected.add(perm.key);
        }
      }
    } else {
      // إزالة جميع صلاحيات القسم
      for (final perm in widget.permissions) {
        newSelected.remove(perm.key);
      }
    }

    widget.onPermissionsChanged(newSelected);
  }

  /// تبديل صلاحية فردية
  void _togglePermission(String permissionId, bool? value) {
    var newSelected = List<String>.from(widget.selectedPermissions);

    if (value == true) {
      if (!newSelected.contains(permissionId)) {
        newSelected.add(permissionId);
      }
    } else {
      newSelected.remove(permissionId);
    }

    widget.onPermissionsChanged(newSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس القسم
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // أيقونة القسم
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.groupIcon,
                        size: 20,
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // اسم القسم
                    Expanded(
                      child: Text(
                        widget.groupName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AssyrianTheme.deepBlue,
                        ),
                      ),
                    ),
                    // Checkbox الرئيسي
                    Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: _areAllSelected,
                        tristate: true,
                        onChanged: _toggleAll,
                        activeColor: AssyrianTheme.primaryGold,
                        checkColor: AssyrianTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // أيقونة البسط/الطي
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AssyrianTheme.deepBlue.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // الصلاحيات الفردية
          if (_isExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: widget.permissions.map((perm) {
                  final isSelected = widget.selectedPermissions.contains(
                    perm.key,
                  );
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) => _togglePermission(perm.key, value),
                    title: Text(
                      perm.value,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: AssyrianTheme.deepBlue,
                      ),
                    ),
                    activeColor: AssyrianTheme.primaryGold,
                    checkColor: AssyrianTheme.deepBlue,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
