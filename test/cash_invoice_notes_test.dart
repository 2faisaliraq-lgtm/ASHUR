import 'package:ashur/features/invoices/data/models/invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InvoiceModel invoice({String? notes, String? cashUserNote}) {
    return InvoiceModel.fromJson({
      'type': 'cash',
      'notes': notes,
      'cashUserNote': ?cashUserNote,
    });
  }

  test('preserves the exact user note through persistence and copying', () {
    const note = 'بمبلغ متفق عليه\nملاحظة: التسليم يوم الخميس';
    for (final description in [
      'إيصال نقدي - إعطاء مبلغ نقدي للعميل بمبلغ 100',
      'إيصال نقدي - استلام مبلغ نقدي من العميل بمبلغ 100',
    ]) {
      final original = invoice(notes: description, cashUserNote: note);
      final stored = InvoiceModel.fromEntity(original.copyWith()).toFirestore();
      final loaded = InvoiceModel.fromJson(stored);
      expect(stored['cashUserNote'], note);
      expect(loaded.displayNotes, note);
      expect(loaded.notes, description);
    }
  });

  test('reads the entire legacy note including embedded note markers', () {
    const note = 'بمبلغ متفق عليه\nملاحظة: التسليم يوم الخميس';
    expect(
      invoice(
        notes:
            'إيصال نقدي - استلام مبلغ نقدي من العميل بمبلغ 100\nملاحظة: $note',
      ).displayNotes,
      note,
    );
  });

  test('reads notes from the invoice creation format', () {
    expect(
      invoice(notes: 'إعطاء مبلغ نقدي للعميل - تسوية شهرية').displayNotes,
      'تسوية شهرية',
    );
  });

  test('does not show the generated receipt description as a user note', () {
    expect(
      invoice(
        notes: 'إيصال نقدي - استلام مبلغ نقدي من العميل بمبلغ 100',
      ).displayNotes,
      isNull,
    );
  });

  test('an explicitly cleared user note overrides old combined notes', () {
    expect(
      invoice(
        notes: 'استلام مبلغ نقدي من العميل - ملاحظة قديمة',
        cashUserNote: '',
      ).displayNotes,
      '',
    );
  });
}
