import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dellinoo_admin/invoice_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// The invoice PDF is built from whatever the `invoices` doc happens to
/// hold, so this walks the real shape through buildInvoicePdf() — a layout
/// mistake only shows up when the document is actually rendered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invoice = <String, dynamic>{
    'number': 'INV-00001',
    'orderId': 'DL10313',
    'customerName': 'Brian Mahove',
    'customerEmail': 'brian@example.com',
    'customerPhone': '0771111111',
    'billTo': {'name': 'Brian Mahove', 'address': '12 Samora Machel Ave, Harare', 'taxNumber': '1234567'},
    'items': [
      {
        'name': 'Apple MacBook Pro 14',
        'options': {'Colour': 'Space grey'},
        'price': 849.99,
        'quantity': 1,
      },
      {'name': 'Phone case', 'options': <String, dynamic>{}, 'price': 25.0, 'quantity': 2},
    ],
    'subtotal': 899.99,
    'discount': 0,
    'deliveryFee': 0,
    'deliveryArea': 'Harare CBD',
    'total': 899.99,
    'payment': 'ecocash',
    'paid': true,
    'orderedAt': Timestamp.now(),
    'issuedAt': Timestamp.now(),
    'issuedBy': 'mahovebrian@gmail.com',
    'notes': '',
  };

  test('builds a PDF from an issued invoice', () async {
    final bytes = await buildInvoicePdf(invoice);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('builds a PDF for an unpaid, discounted invoice with no bill-to extras', () async {
    final bytes = await buildInvoicePdf({
      ...invoice,
      'paid': false,
      'discount': 50.0,
      'couponCode': 'WELCOME10',
      'deliveryFee': 5.0,
      'billTo': {'name': '', 'address': '', 'taxNumber': ''},
    });
    expect(bytes.length, greaterThan(1000));
  });
}
