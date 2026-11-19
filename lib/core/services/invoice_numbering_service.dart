import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة ترقيم موحد لجميع مستندات التطبيق (فواتير، إيصالات، صيانة، إيجار، إلخ)
/// الصيغة: [رمز القسم]-YYYYMMDD-[رقم تتابعي 4 أرقام]
class InvoiceNumberingService {
  static const Map<String, String> _sectionCodes = {
    'sales': 'INV',
    'purchase': 'PUR',
    'cash': 'CAS',
    'sales_return': 'RET',
    'receipt': 'REC',
    'payment': 'PAY',
    'account_clearance': 'CLR',
    'opening_balance': 'OPN',
    'maintenance': 'MNT',
    'rental': 'RNT',
  };

  String _getSectionCode(String section) =>
      _sectionCodes[section] ?? 'DOC';

  /// توليد رقم مستند تتابعي لليوم الحالي لقسم معين (غير متزامن - يستعلم Firestore)
  Future<String> generateNumber({
    required String section,
    required String organizationEmail,
  }) async {
    final code = _getSectionCode(section);
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefix = '$code-$dateStr-';

    final normalizedEmail = _normalizeEmail(organizationEmail);

    final firestore = FirebaseFirestore.instance;
    final collection = _getCollection(firestore, normalizedEmail, section);

    final snapshot = await collection
        .where('invoiceNumber', isGreaterThanOrEqualTo: prefix)
        .where('invoiceNumber', isLessThanOrEqualTo: '$prefix\uffff')
        .get();

    int maxSeq = 0;
    for (final doc in snapshot.docs) {
      final num = doc['invoiceNumber'] as String?;
      if (num != null && num.startsWith(prefix)) {
        final suffix = num.substring(prefix.length);
        final parsed = int.tryParse(suffix);
        if (parsed != null && parsed > maxSeq) {
          maxSeq = parsed;
        }
      }
    }

    final nextSeq = maxSeq + 1;
    return '$prefix${nextSeq.toString().padLeft(4, '0')}';
  }

  /// توليد رقم مستند متزامن دون استعلام Firestore
  /// يستخدم آخر 4 أرقام من الطابع الزمني كرقم تتابعي تقريبي
  static String generateNumberSync({
    required String section,
  }) {
    final code = _getSectionCodeStatic(section);
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final ms = now.millisecondsSinceEpoch.toString();
    final suffix = ms.length >= 4 ? ms.substring(ms.length - 4) : ms.padLeft(4, '0');
    return '$code-$dateStr-$suffix';
  }

  static String _getSectionCodeStatic(String section) {
    final codes = {
      'sales': 'INV',
      'purchase': 'PUR',
      'cash': 'CAS',
      'sales_return': 'RET',
      'receipt': 'REC',
      'payment': 'PAY',
      'account_clearance': 'CLR',
      'opening_balance': 'OPN',
      'maintenance': 'MNT',
      'rental': 'RNT',
    };
    return codes[section] ?? 'DOC';
  }

  String _normalizeEmail(String email) =>
      email.replaceAll('@', '_at_').replaceAll('.', '_dot_');

  CollectionReference _getCollection(
      FirebaseFirestore firestore, String email, String section) {
    final orgPath = 'organizations_$email';
    switch (section) {
      case 'sales':
      case 'purchase':
      case 'cash':
      case 'sales_return':
        return firestore.collection('$orgPath/invoices');
      case 'receipt':
      case 'payment':
      case 'account_clearance':
      case 'opening_balance':
        return firestore.collection('$orgPath/customer_invoices');
      case 'maintenance':
        return firestore.collection('$orgPath/maintenance_invoices');
      case 'rental':
        return firestore.collection('$orgPath/rental_invoices');
      default:
        return firestore.collection('$orgPath/documents');
    }
  }
}
