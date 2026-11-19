import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/utils/smart_number_formatter.dart';

/// Widget لاختبار تنسيق الأرقام الذكي
class SmartNumberTestWidget extends StatefulWidget {

  const SmartNumberTestWidget({
    required this.decimalSeparator, required this.thousandsSeparator, required this.decimalPlaces, required this.showThousandsSeparator, required this.showLeadingZero, required this.smartDecimalSeparator, required this.autoThousandsSeparator, required this.numberFormat, super.key,
  });
  final String decimalSeparator;
  final String thousandsSeparator;
  final int decimalPlaces;
  final bool showThousandsSeparator;
  final bool showLeadingZero;
  final bool smartDecimalSeparator;
  final bool autoThousandsSeparator;
  final String numberFormat;

  @override
  State<SmartNumberTestWidget> createState() => _SmartNumberTestWidgetState();
}

class _SmartNumberTestWidgetState extends State<SmartNumberTestWidget> {
  final TextEditingController _controller = TextEditingController();
  String _formattedResult = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFormattedResult);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateFormattedResult() {
    if (_controller.text.isNotEmpty) {
      try {
        // تحويل النص إلى رقم
        var cleanText = _controller.text
            .replaceAll(widget.thousandsSeparator, '')
            .replaceAll(widget.decimalSeparator, '.');

        // تحويل الأرقام العربية إلى إنجليزية
        cleanText = SmartNumberFormatter.convertToEnglishNumbers(cleanText);

        var number = double.parse(cleanText);

        setState(() {
          _formattedResult = SmartNumberFormatter.format(
            number,
            decimalSeparator: widget.decimalSeparator,
            thousandsSeparator: widget.thousandsSeparator,
            decimalPlaces: widget.decimalPlaces,
            showThousandsSeparator: widget.showThousandsSeparator,
            showLeadingZero: widget.showLeadingZero,
            smartDecimalSeparator: widget.smartDecimalSeparator,
            numberFormat: widget.numberFormat,
          );
        });
      } on Exception catch (_) {
        setState(() {
          _formattedResult = 'رقم غير صحيح';
        });
      }
    } else {
      setState(() {
        _formattedResult = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science,
                color: Colors.blue,
                size: 16.sp,
              ),
              const SizedBox(width: 8),
              Text(
                'اختبار التنسيق الذكي',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: widget.autoThousandsSeparator
                ? [
                    SmartNumberInputFormatter(
                      decimalSeparator: widget.decimalSeparator,
                      thousandsSeparator: widget.thousandsSeparator,
                      decimalPlaces: widget.decimalPlaces,
                      showThousandsSeparator: widget.showThousandsSeparator,
                      autoThousandsSeparator: widget.autoThousandsSeparator,
                      numberFormat: widget.numberFormat,
                    ),
                  ]
                : null,
            decoration: InputDecoration(
              labelText: 'اكتب رقماً لاختبار التنسيق',
              hintText: 'مثال: 1234567.89',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          if (_formattedResult.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'النتيجة المنسقة:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formattedResult,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'الميزات النشطة:',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (widget.autoThousandsSeparator)
                _buildFeatureChip('تنسيق تلقائي', Colors.blue),
              if (widget.smartDecimalSeparator)
                _buildFeatureChip('فاصلة ذكية', Colors.green),
              if (widget.showThousandsSeparator)
                _buildFeatureChip('فاصل الآلاف', Colors.orange),
              if (widget.numberFormat == 'ar')
                _buildFeatureChip('أرقام عربية', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
