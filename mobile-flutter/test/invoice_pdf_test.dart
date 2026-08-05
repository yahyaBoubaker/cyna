import 'package:cyna_mobile/services/invoice_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildInvoicePdf genere un document PDF', () async {
    final bytes = await buildInvoicePdf({
      'invoice': {
        'number': 'CYNA-2026-00001',
        'total': '150.00',
        'issued_at': '2026-08-05 10:00:00',
      },
      'order': {
        'id': 1,
        'status': 'paid',
        'total': '150.00',
        'items': [
          {
            'product_name': 'CYNA SOC',
            'duration_months': 12,
            'quantity': 1,
            'line_total': '150.00',
          },
        ],
      },
      'user': {
        'firstName': 'Test',
        'lastName': 'CYNA',
        'email': 'test@example.com',
      },
      'address': {
        'line1': '1 rue de la Securite',
        'postal_code': '75000',
        'city': 'Paris',
        'country': 'France',
      },
      'payment': {'card_name': 'Test CYNA', 'card_last4': '4242'},
    });

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
