import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../features/customers/domain/entities/customer_entity.dart';
import '../../../features/inventory/domain/entities/product_entity.dart';

/// نوع الاقتراح لتحديد الأيقونة والنص المناسب
enum SuggestionType {
  person, // للأشخاص (عملاء، مستخدمين)
  phone, // لأرقام الهواتف
  email, // للبريد الإلكتروني
  product, // للمنتجات
  category, // للأصناف
  role, // للأدوار
  custom, // مخصص
}

/// موديل يمثل اقتراحاً واحداً
class SuggestionItem {
  final String value; // القيمة المعروضة
  final String? title; // العنوان (اختياري - للمنتجات مع الرف)
  final String? subtitle; // نص ثانوي اختياري
  final bool isExactMatch; // هل هو تطابق تام (موجود مسبقاً)
  final SuggestionType type; // نوع الاقتراح
  final IconData? customIcon; // أيقونة مخصصة (اختياري)
  final Color? customColor; // لون مخصص (اختياري)
  final String? status; // نص الحالة المخصص (محظور، تجاوز الحد، إلخ)
  final bool isBlocked; // هل العميل محظور
  final bool isExceedingLimit; // هل تجاوز حد الدين
  final bool isOutOfStock; // هل نفذت الكمية (للمنتجات)
  final bool isLowStock; // هل الكمية قليلة (للمنتجات)
  final Map<String, dynamic>? customData; // بيانات مخصصة

  const SuggestionItem({
    required this.value,
    this.title,
    this.subtitle,
    this.isExactMatch = false,
    this.type = SuggestionType.person,
    this.customIcon,
    this.customColor,
    this.status,
    this.isBlocked = false,
    this.isExceedingLimit = false,
    this.isOutOfStock = false,
    this.isLowStock = false,
    this.customData,
  });

  /// الحصول على الأيقونة المناسبة للنوع
  IconData get icon {
    if (customIcon != null) return customIcon!;

    // إذا كان محظور أو تجاوز الحد أو نفذت الكمية، عرض أيقونة التحذير
    if (isBlocked || isExceedingLimit || isOutOfStock) {
      return Icons.warning_amber_rounded;
    }

    switch (type) {
      case SuggestionType.person:
        return isExactMatch ? Icons.block : Icons.person_outline;
      case SuggestionType.phone:
        return isExactMatch ? Icons.block : Icons.phone_outlined;
      case SuggestionType.email:
        return isExactMatch ? Icons.block : Icons.email_outlined;
      case SuggestionType.product:
        return isLowStock
            ? Icons.inventory_2_outlined
            : Icons.inventory_2_outlined;
      case SuggestionType.category:
        return isExactMatch ? Icons.block : Icons.category;
      case SuggestionType.role:
        return isExactMatch ? Icons.block : Icons.badge_outlined;
      case SuggestionType.custom:
        return isExactMatch ? Icons.block : Icons.info_outline;
    }
  }

  /// الحصول على اللون المناسب
  Color get color {
    if (customColor != null) return customColor!;

    // إذا كان محظور أو تجاوز الحد أو نفذت الكمية، استخدام اللون الأحمر
    if (isBlocked || isExceedingLimit || isOutOfStock) {
      return Colors.red;
    }

    return isExactMatch ? Colors.red : Colors.orange;
  }

  /// الحصول على نص الحالة
  String get statusText {
    if (status != null) return status!;
    return isExactMatch ? 'موجود' : 'تحذير';
  }
}

/// extension لتحويل CustomerEntity إلى SuggestionItem بسهولة
extension CustomerSuggestionExtension on CustomerEntity {
  SuggestionItem toSuggestionItem({String? Function(double)? formatCurrency}) {
    // حساب حساب العميل
    final totalDebt = this.totalDebt;
    final creditLimit = this.creditLimit ?? 0.0;
    final isExceedingLimit = creditLimit > 0 && totalDebt > creditLimit;
    final isBlocked = this.isBlocked;

    // تحديد النص الثانوي (الهاتف + الحساب + الحالة)
    String subtitle = phone;

    // إضافة الحساب
    if (totalDebt != 0 && formatCurrency != null) {
      final balanceText = totalDebt > 0
          ? 'عليه ${formatCurrency(totalDebt)}'
          : 'له ${formatCurrency(totalDebt.abs())}';
      subtitle = subtitle.isNotEmpty ? '$subtitle • $balanceText' : balanceText;
    }

    // إضافة الحالة (محظور أو تجاوز الحد)
    if (isBlocked) {
      subtitle = subtitle.isNotEmpty ? '$subtitle • ⛔ محظور' : '⛔ محظور';
    } else if (isExceedingLimit) {
      subtitle = subtitle.isNotEmpty
          ? '$subtitle • ⚠️ تجاوز الحد'
          : '⚠️ تجاوز الحد';
    }

    return SuggestionItem(
      value: name,
      subtitle: subtitle,
      isExactMatch: false,
      type: SuggestionType.person,
      isBlocked: isBlocked,
      isExceedingLimit: isExceedingLimit,
    );
  }
}

/// extension لتحويل ProductEntity إلى SuggestionItem بسهولة
extension ProductSuggestionExtension on ProductEntity {
  SuggestionItem toProductSuggestionItem({
    String? Function(double)? formatCurrency,
    String? shelfName,
  }) {
    // حساب حالة المخزون
    final quantity = this.quantity;
    final isOutOfStock = quantity <= 0;
    final isLowStock = quantity > 0 && quantity < minQuantity;

    // تحديد النص الثانوي (السعر + الكمية)
    String subtitle = '';

    // إضافة سعر البيع
    if (formatCurrency != null) {
      try {
        final priceText = formatCurrency(sellingPrice);
        subtitle = priceText ?? sellingPrice.toString();
      } on Exception {
        // في حالة حدوث خطأ، نستخدم السعر مباشرة
        subtitle = sellingPrice.toString();
      }
    } else {
      subtitle = sellingPrice.toString();
    }

    // إضافة الكمية
    String quantityText;
    if (isOutOfStock) {
      quantityText = '0';
    } else {
      quantityText = '${quantity.toInt()}';
    }
    subtitle = '$subtitle • $quantityText';

    return SuggestionItem(
      value: name,
      subtitle: subtitle,
      isExactMatch: false,
      type: SuggestionType.product,
      isOutOfStock: isOutOfStock,
      isLowStock: isLowStock,
      customData: {
        'quantity': quantity,
        'unit': unit,
        'sellingPrice': sellingPrice,
        'shelfName': shelfName,
      },
    );
  }
}

/// ویدجت لعرض قائمة الاقتراحات بشكل موحد
///
/// مثال على الاستخدام:
/// ```dart
/// SuggestionsOverlay.show(
///   context: context,
///   anchorKey: _nameFieldKey,
///   layerLink: _nameLayerLink,
///   suggestions: suggestionsList,
///   onSuggestionSelected: (value) {
///     _nameController.text = value;
///   },
///   maxHeight: 100.h,
/// );
/// ```
class SuggestionsOverlay {
  /// عرض الاقتراحات كـ Overlay
  static OverlayEntry? show({
    required BuildContext context,
    required LayerLink layerLink,
    required GlobalKey anchorKey,
    required List<SuggestionItem> suggestions,
    required Function(String value) onSuggestionSelected,
    Function()? onDismiss,
    double? maxHeight,
    bool showResultsCount = false,
  }) {
    // إخفاء أي overlay سابق
    hide();

    if (suggestions.isEmpty) return null;

    final renderBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final width = renderBox.size.width;
    final overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          hide();
          onDismiss?.call();
        },
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            CompositedTransformFollower(
              link: layerLink,
              offset: Offset(0, renderBox.size.height),
              child: _SuggestionsOverlayContent(
                width: width,
                maxHeight: maxHeight ?? 100.h,
                suggestions: suggestions,
                onSuggestionSelected: (value) {
                  hide();
                  onSuggestionSelected(value);
                },
                showResultsCount: showResultsCount,
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    _currentOverlayEntry = overlayEntry;
    return overlayEntry;
  }

  static OverlayEntry? _currentOverlayEntry;

  /// إخفاء الاقتراحات
  static void hide() {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
  }

  /// التحقق مما إذا كانت الاقتراحات معروضة حالياً
  static bool get isVisible => _currentOverlayEntry != null;
}

/// الويدجت الداخلي لعرض محتوى الاقتراحات
class _SuggestionsOverlayContent extends StatelessWidget {
  final double width;
  final double maxHeight;
  final List<SuggestionItem> suggestions;
  final Function(String value) onSuggestionSelected;
  final bool showResultsCount;

  const _SuggestionsOverlayContent({
    required this.width,
    required this.maxHeight,
    required this.suggestions,
    required this.onSuggestionSelected,
    this.showResultsCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.r)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, thickness: 1, color: Colors.grey[300]),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];

            // تحديد نوع العرض بناءً على النوع
            if (suggestion.type == SuggestionType.product) {
              return _buildProductItem(suggestion);
            } else {
              return _buildCustomerItem(suggestion);
            }
          },
        ),
      ),
    );
  }

  /// بناء عنصر المنتج
  Widget _buildProductItem(SuggestionItem suggestion) {
    // تحديد إذا كان المنتج نفذت كميته أو الكمية قليلة
    final hasWarning = suggestion.isOutOfStock || suggestion.isLowStock;

    // استخراج السعر والرف والكمية من subtitle و customData
    String? priceText;
    String? quantityText;
    final shelfName = suggestion.customData?['shelfName'] as String?;

    if (suggestion.subtitle != null) {
      final parts = suggestion.subtitle!.split(' • ');
      if (parts.isNotEmpty) {
        priceText = parts[0].trim();
        if (parts.length > 1) {
          quantityText = parts[1].trim();
        }
      }
    }

    // تحديد لون الكمية
    Color quantityColor;
    if (suggestion.isOutOfStock) {
      quantityColor = Colors.red;
    } else if (suggestion.isLowStock) {
      quantityColor = Colors.orange;
    } else {
      quantityColor = Colors.green;
    }

    // تحديد لون السعر
    Color priceColor;
    if (hasWarning) {
      priceColor = Colors.red;
    } else {
      priceColor = Colors.blueGrey[700]!;
    }

    // الحصول على الوحدة من البيانات المخصصة
    String unit = suggestion.customData?['unit'] ?? 'قطعة';

    return Container(
      decoration: hasWarning
          ? BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(8.r),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          minLeadingWidth: 20.w,
          leading: Icon(
            suggestion.icon,
            size: 16.sp,
            color: hasWarning ? Colors.red : suggestion.color,
          ),
          title: Text(
            suggestion.value,
            style: TextStyle(
              fontSize: 12.sp,
              color: hasWarning ? Colors.red : Colors.black87,
              fontWeight: hasWarning ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // السعر على اليمين
              if (priceText != null)
                Expanded(
                  flex: 1,
                  child: Text(
                    priceText,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: priceColor,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // الرف في المنتصف (إذا كان موجوداً)
              if (shelfName != null && shelfName.isNotEmpty)
                Expanded(
                  flex: 1,
                  child: Text(
                    shelfName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // الكمية على اليسار
              if (quantityText != null)
                Expanded(
                  flex: 1,
                  child: Text(
                    quantityText,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: quantityColor,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          onTap: () => onSuggestionSelected(suggestion.value),
        ),
      ),
    );
  }

  /// بناء عنصر العميل
  Widget _buildCustomerItem(SuggestionItem suggestion) {
    // تحديد إذا كان يجب عرض تحذير
    final hasWarning = suggestion.isBlocked || suggestion.isExceedingLimit;

    // استخراج الحساب من subtitle
    String? balanceText;
    String? phoneText;
    String? statusText;

    if (suggestion.subtitle != null) {
      final parts = suggestion.subtitle!.split(' • ');
      phoneText = parts.isNotEmpty ? parts[0] : null;
      if (parts.length > 1) {
        // البحث عن الحساب
        for (int i = 1; i < parts.length; i++) {
          final part = parts[i].trim();
          if (part.contains('عليه') || part.contains('له')) {
            balanceText = part;
          } else if (part.contains('محظور') || part.contains('تجاوز')) {
            statusText = part;
          }
        }
      }
    }

    // تحديد لون الحساب
    Color balanceColor;
    if (hasWarning) {
      balanceColor = Colors.red;
    } else if (balanceText != null) {
      if (balanceText.contains('له')) {
        balanceColor = Colors.green;
      } else {
        balanceColor = Colors.red;
      }
    } else {
      balanceColor = Colors.green; // صفر أو لا يوجد
    }

    return Container(
      decoration: hasWarning
          ? BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(8.r),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          minLeadingWidth: 20.w,
          leading: Icon(
            suggestion.icon,
            size: 16.sp,
            color: hasWarning ? Colors.red : suggestion.color,
          ),
          title: Text(
            suggestion.title ?? suggestion.value,
            style: TextStyle(
              fontSize: 12.sp,
              color: hasWarning ? Colors.red : Colors.black87,
              fontWeight: hasWarning ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: phoneText != null
              ? Text(
                  phoneText,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: hasWarning ? Colors.red[700] : Colors.grey[600],
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (balanceText != null)
                Text(
                  balanceText,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: balanceColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (statusText != null)
                Container(
                  margin: EdgeInsets.only(top: 2.h),
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () => onSuggestionSelected(suggestion.value),
        ),
      ),
    );
  }
}

/// Mixin يوفر وظائف مشتركة لإدارة الاقتراحات
///
/// الاستخدام:
/// ```dart
/// class _MyPageState extends State<MyPage> with SuggestionsMixin {
///   @override
///   void initState() {
///     super.initState();
///     initializeSuggestions(
///       layerLink: _nameLayerLink,
///       fieldKey: _nameFieldKey,
///       controller: _nameController,
///       focusNode: _nameFocusNode,
///     );
///   }
/// }
/// ```
mixin SuggestionsMixin<T extends StatefulWidget> on State<T> {
  OverlayEntry? _overlayEntry;
  LayerLink? _layerLink;
  GlobalKey? _fieldKey;
  TextEditingController? _controller;
  FocusNode? _focusNode;

  /// تهيئة نظام الاقتراحات
  void initializeSuggestions({
    required LayerLink layerLink,
    required GlobalKey fieldKey,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    _layerLink = layerLink;
    _fieldKey = fieldKey;
    _controller = controller;
    _focusNode = focusNode;

    _focusNode?.addListener(() {
      if (!_focusNode!.hasFocus) {
        hideSuggestions();
      }
    });
  }

  /// عرض الاقتراحات
  void showSuggestions({
    required List<SuggestionItem> suggestions,
    Function(String value)? onSelected,
    double? maxHeight,
  }) {
    if (suggestions.isEmpty || _controller == null || !mounted) return;

    hideSuggestions();

    final renderBox =
        _fieldKey?.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final width = renderBox.size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: hideSuggestions,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            CompositedTransformFollower(
              link: _layerLink!,
              offset: Offset(0, renderBox.size.height),
              child: _SuggestionsOverlayContent(
                width: width,
                maxHeight: maxHeight ?? 100.h,
                suggestions: suggestions,
                onSuggestionSelected: (value) {
                  hideSuggestions();
                  if (onSelected != null) {
                    onSelected(value);
                  } else if (_controller != null) {
                    _controller!.text = value;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// إخفاء الاقتراحات
  void hideSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// تصفية الاقتراحات محلياً
  List<SuggestionItem> filterSuggestions({
    required List<SuggestionItem> allSuggestions,
    required String query,
    bool ignoreCase = true,
  }) {
    if (query.isEmpty) return [];

    final filtered = allSuggestions.where((item) {
      final itemValue = ignoreCase ? item.value.toLowerCase() : item.value;
      final searchQuery = ignoreCase ? query.toLowerCase() : query;
      return itemValue.contains(searchQuery);
    }).toList();

    return filtered;
  }

  /// إنشاء عنصر اقتراح
  SuggestionItem createSuggestion({
    required String value,
    String? subtitle,
    bool isExactMatch = false,
    SuggestionType type = SuggestionType.person,
    IconData? icon,
    Color? color,
  }) {
    return SuggestionItem(
      value: value,
      subtitle: subtitle,
      isExactMatch: isExactMatch,
      type: type,
      customIcon: icon,
      customColor: color,
    );
  }

  @override
  void dispose() {
    hideSuggestions();
    super.dispose();
  }
}

/// ویدجت جاهز للاستخدام المباشر في الحقول
///
/// مثال:
/// ```dart
/// CompositedTransformTarget(
///   link: _nameLayerLink,
///   child: Container(
///     key: _nameFieldKey,
///     child: TextFormField(
///       controller: _nameController,
///       focusNode: _nameFocusNode,
///       // ...
///     ),
///   ),
/// ),
/// ```
class SuggestionsField extends StatelessWidget {
  final LayerLink layerLink;
  final GlobalKey fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<SuggestionItem> suggestions;
  final Function(String value)? onSuggestionSelected;
  final String labelText;
  final IconData prefixIcon;
  final bool showSuggestions;
  final double? suggestionsMaxHeight;

  const SuggestionsField({
    super.key,
    required this.layerLink,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    this.onSuggestionSelected,
    required this.labelText,
    this.prefixIcon = Icons.person,
    this.showSuggestions = true,
    this.suggestionsMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CompositedTransformTarget(
          link: layerLink,
          child: Container(
            key: fieldKey,
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: labelText,
                prefixIcon: Icon(prefixIcon, size: 20.sp),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20.sp),
                        onPressed: () {
                          controller.clear();
                          SuggestionsOverlay.hide();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
