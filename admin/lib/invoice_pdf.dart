import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds the invoice document from an `invoices/{id}` Firestore map.
///
/// Nothing is uploaded anywhere: the project is on Spark (no Storage), so
/// the PDF is generated in the browser every time it's printed or
/// downloaded, from the snapshot of the order stored on the invoice doc.
/// That also means a re-download years later produces the same document.
///
/// Seller details are placeholders until the client confirms them (trading
/// name, physical address, tax/BP number) — see CLAUDE.md's Placeholders.
const _sellerName = 'Dellinoo';
const _sellerLines = ['Harare, Zimbabwe', 'WhatsApp +86 131 6295 2997'];

/// Brand colours, hand-copied from admin/lib/theme.dart (the PDF package has
/// its own colour type, so they can't be shared directly).
const _violet = PdfColor.fromInt(0xFF5B21D6);
const _orange = PdfColor.fromInt(0xFFFF8A00);
const _ink = PdfColor.fromInt(0xFF101828);
const _muted = PdfColor.fromInt(0xFF667085);
const _line = PdfColor.fromInt(0xFFE4E7EC);
const _tint = PdfColor.fromInt(0xFFF6F3FF);

final _money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
final _date = DateFormat.yMMMMd();

String money(num? v) => _money.format((v ?? 0).toDouble());

DateTime? _at(Object? v) => v is Timestamp ? v.toDate() : null;

/// A filename that sorts and searches well in a downloads folder.
String invoiceFileName(Map<String, dynamic> inv) => '${inv['number'] ?? 'invoice'}-${inv['orderId'] ?? ''}.pdf';

Future<void> printInvoice(Map<String, dynamic> inv) async {
  final bytes = await buildInvoicePdf(inv);
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: invoiceFileName(inv));
}

Future<void> downloadInvoice(Map<String, dynamic> inv) async {
  final bytes = await buildInvoicePdf(inv);
  await Printing.sharePdf(bytes: bytes, filename: invoiceFileName(inv));
}

Future<Uint8List> buildInvoicePdf(Map<String, dynamic> inv) async {
  final logo = pw.MemoryImage((await rootBundle.load('assets/images/logo_full.png')).buffer.asUint8List());
  final items = List<Map<String, dynamic>>.from(inv['items'] as List? ?? const []);
  final billTo = Map<String, dynamic>.from(inv['billTo'] as Map? ?? const {});
  final discount = (inv['discount'] as num?)?.toDouble() ?? 0;
  final paid = inv['paid'] == true;

  final doc = pw.Document(title: '${inv['number']}', author: _sellerName);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      theme: pw.ThemeData.withFont().copyWith(defaultTextStyle: pw.TextStyle(fontSize: 10, color: _ink)),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(logo, inv, paid),
          pw.SizedBox(height: 26),
          _parties(inv, billTo),
          pw.SizedBox(height: 22),
          _itemsTable(items),
          pw.SizedBox(height: 14),
          _totals(inv, discount),
          pw.Spacer(),
          _footer(inv),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _header(pw.ImageProvider logo, Map<String, dynamic> inv, bool paid) {
  final issued = _at(inv['issuedAt']);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Image(logo, height: 30),
          pw.SizedBox(height: 10),
          for (final l in _sellerLines) pw.Text(l, style: const pw.TextStyle(color: _muted, fontSize: 9)),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'INVOICE',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _violet),
          ),
          pw.SizedBox(height: 2),
          pw.Text('${inv['number']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          if (issued != null)
            pw.Text('Issued ${_date.format(issued)}', style: const pw.TextStyle(color: _muted, fontSize: 9)),
          pw.SizedBox(height: 8),
          // Whether the money has actually arrived — an unpaid invoice is a
          // request for payment, a paid one is a receipt, and the customer
          // needs to be able to tell which they were handed.
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: paid ? const PdfColor.fromInt(0xFFE7F7EE) : const PdfColor.fromInt(0xFFFFF1DF),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Text(
              paid ? 'PAID' : 'UNPAID',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: paid ? const PdfColor.fromInt(0xFF12805C) : _orange,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _parties(Map<String, dynamic> inv, Map<String, dynamic> billTo) {
  final ordered = _at(inv['orderedAt']);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _block('Bill to', [
          '${billTo['name'] ?? inv['customerName'] ?? ''}',
          if ((billTo['address'] as String?)?.isNotEmpty ?? false) '${billTo['address']}',
          if ((billTo['taxNumber'] as String?)?.isNotEmpty ?? false) 'TIN / BP: ${billTo['taxNumber']}',
          if ((inv['customerEmail'] as String?)?.isNotEmpty ?? false) '${inv['customerEmail']}',
          if ((inv['customerPhone'] as String?)?.isNotEmpty ?? false) '${inv['customerPhone']}',
        ]),
      ),
      pw.SizedBox(width: 20),
      pw.Expanded(
        child: _block('Order', [
          'Order ${inv['orderId'] ?? ''}',
          if (ordered != null) 'Placed ${_date.format(ordered)}',
          if ((inv['payment'] as String?)?.isNotEmpty ?? false) 'Payment: ${_paymentLabel(inv['payment'] as String)}',
          if ((inv['deliveryArea'] as String?)?.isNotEmpty ?? false) 'Delivery: ${inv['deliveryArea']}',
        ]),
      ),
    ],
  );
}

pw.Widget _block(String title, List<String> lines) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(fontSize: 8, color: _muted, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    for (final l in lines)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.Text(l, style: const pw.TextStyle(fontSize: 10)),
      ),
  ],
);

/// Matches PaymentMethod in the customer app's lib/data/models.dart — kept in
/// sync by hand, same as the status labels in orders_screen.dart.
String _paymentLabel(String p) => switch (p) {
  'ecocash' => 'EcoCash',
  'onemoney' => 'OneMoney',
  'innbucks' => 'InnBucks',
  'card' => 'Visa / Mastercard',
  'manual' => 'Manual transfer',
  _ => p,
};

pw.Widget _itemsTable(List<Map<String, dynamic>> items) {
  pw.Widget cell(String text, {bool right = false, bool bold = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 9.5,
        color: color ?? _ink,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  return pw.Table(
    border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
    columnWidths: const {
      0: pw.FlexColumnWidth(5),
      1: pw.FlexColumnWidth(1.1),
      2: pw.FlexColumnWidth(1.6),
      3: pw.FlexColumnWidth(1.8),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _tint),
        children: [
          cell('Item', bold: true, color: _violet),
          cell('Qty', right: true, bold: true, color: _violet),
          cell('Unit price', right: true, bold: true, color: _violet),
          cell('Amount', right: true, bold: true, color: _violet),
        ],
      ),
      for (final i in items)
        pw.TableRow(
          children: [
            cell(['${i['name'] ?? ''}', if (_options(i).isNotEmpty) '(${_options(i)})'].join('  ')),
            cell('${(i['quantity'] as num?)?.toInt() ?? 1}', right: true),
            cell(money(i['price'] as num?), right: true),
            cell(money(((i['price'] as num?) ?? 0) * ((i['quantity'] as num?) ?? 1)), right: true),
          ],
        ),
    ],
  );
}

String _options(Map<String, dynamic> item) {
  final options = Map<String, dynamic>.from(item['options'] as Map? ?? const {});
  return options.values.join(', ');
}

pw.Widget _totals(Map<String, dynamic> inv, double discount) {
  pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: bold ? 11 : 9.5, fontWeight: bold ? pw.FontWeight.bold : null),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: bold ? 11 : 9.5, fontWeight: bold ? pw.FontWeight.bold : null),
        ),
      ],
    ),
  );

  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      width: 220,
      child: pw.Column(
        children: [
          row('Subtotal', money(inv['subtotal'] as num?)),
          if (discount > 0) row('Promo ${inv['couponCode'] ?? ''}', '-${money(discount)}'),
          row('Delivery', (inv['deliveryFee'] as num?) == 0 ? 'FREE' : money(inv['deliveryFee'] as num?)),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Divider(color: _line, height: 1, thickness: 0.5),
          ),
          row('Total (USD)', money(inv['total'] as num?), bold: true),
        ],
      ),
    ),
  );
}

pw.Widget _footer(Map<String, dynamic> inv) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    if ((inv['notes'] as String?)?.isNotEmpty ?? false) ...[
      pw.Text('${inv['notes']}', style: const pw.TextStyle(fontSize: 9, color: _muted)),
      pw.SizedBox(height: 8),
    ],
    pw.Divider(color: _line, height: 1, thickness: 0.5),
    pw.SizedBox(height: 6),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Thank you for shopping with $_sellerName.', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        if ((inv['issuedBy'] as String?)?.isNotEmpty ?? false)
          pw.Text('Issued by ${inv['issuedBy']}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
      ],
    ),
  ],
);
