import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/assyrian_theme.dart';

/// Widget لإدارة قائمة الميزات
class FeaturesListWidget extends StatefulWidget {

  const FeaturesListWidget({
    required this.features, required this.onFeaturesChanged, super.key,
  });
  final List<String> features;
  final Function(List<String>) onFeaturesChanged;

  @override
  State<FeaturesListWidget> createState() => _FeaturesListWidgetState();
}

class _FeaturesListWidgetState extends State<FeaturesListWidget> {
  final TextEditingController _featureController = TextEditingController();
  late List<String> _features;

  @override
  void initState() {
    super.initState();
    _features = List.from(widget.features);
  }

  @override
  void dispose() {
    _featureController.dispose();
    super.dispose();
  }

  void _addFeature() {
    final feature = _featureController.text.trim();
    if (feature.isNotEmpty && !_features.contains(feature)) {
      setState(() {
        _features.add(feature);
        _featureController.clear();
      });
      widget.onFeaturesChanged(_features);
    }
  }

  void _removeFeature(int index) {
    setState(() {
      _features.removeAt(index);
    });
    widget.onFeaturesChanged(_features);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الميزات',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        SizedBox(height: 8.h),

        // حقل إضافة ميزة جديدة
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _featureController,
                decoration: InputDecoration(
                  hintText: 'أضف ميزة جديدة',
                  prefixIcon: Icon(
                    Icons.star_outline,
                    size: 20.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                ),
                onSubmitted: (_) => _addFeature(),
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: _addFeature,
              style: ElevatedButton.styleFrom(
                backgroundColor: AssyrianTheme.primaryGold,
                foregroundColor: AssyrianTheme.deepBlue,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Icon(Icons.add, size: 24.sp),
            ),
          ],
        ),

        SizedBox(height: 12.h),

        // قائمة الميزات
        if (_features.isEmpty)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20.sp, color: Colors.grey[600]),
                SizedBox(width: 8.w),
                Text(
                  'لم يتم إضافة أي ميزات بعد',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _features.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  leading: Icon(
                    Icons.check_circle,
                    size: 20.sp,
                    color: Colors.green,
                  ),
                  title: Text(
                    _features[index],
                    style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20.sp,
                      color: Colors.red,
                    ),
                    onPressed: () => _removeFeature(index),
                  ),
                );
              },
            ),
          ),

        SizedBox(height: 8.h),

        // عداد الميزات
        Text(
          'عدد الميزات: ${_features.length}',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
