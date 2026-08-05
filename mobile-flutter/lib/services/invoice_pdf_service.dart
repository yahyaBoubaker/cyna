import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<Uint8List> buildInvoicePdf(Map<String, dynamic> data) async {
  final invoice = _map(data['invoice']);
  final order = _map(data['order']);
  final user = _map(data['user']);
  final address = _map(data['address']);
  final payment = _map(data['payment']);
  final items = (order['items'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final document = pw.Document();
  const navy = PdfColor.fromInt(0xff0b3a75);
  const cyan = PdfColor.fromInt(0xff18a4bc);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: cyan, width: 2)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CYNA',
              style: const pw.TextStyle(
                color: navy,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'FACTURE',
              style: const pw.TextStyle(
                color: navy,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _section(
                'Facture',
                [
                  'Numero : ${invoice['number'] ?? '-'}',
                  'Date : ${invoice['issued_at'] ?? order['created_at'] ?? '-'}',
                  'Commande : #${order['id'] ?? '-'}',
                  'Statut : ${order['status'] ?? '-'}',
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: _section(
                'Client',
                [
                  '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
                  '${user['email'] ?? ''}',
                  '${address['company'] ?? ''}',
                  '${address['line1'] ?? ''}',
                  '${address['line2'] ?? ''}',
                  '${address['postal_code'] ?? ''} ${address['city'] ?? ''}'.trim(),
                  '${address['country'] ?? ''}',
                ].where((line) => line.isNotEmpty).toList(),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Services',
          style: const pw.TextStyle(
            color: navy,
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        _invoiceHeader(),
        ...items.map(_invoiceItem),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 220,
            padding: const pw.EdgeInsets.all(12),
            color: navy,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: const pw.TextStyle(color: PdfColors.white)),
                pw.Text(
                  '${invoice['total'] ?? order['total'] ?? '0.00'} EUR',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 24),
        _section(
          'Paiement securise',
          [
            'Porteur : ${payment['card_name'] ?? '-'}',
            'Carte : **** **** **** ${payment['card_last4'] ?? '----'}',
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Le numero complet de carte et le cryptogramme ne sont jamais stockes.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return document.save();
}

Future<void> shareInvoicePdf(Map<String, dynamic> data) async {
  final invoice = _map(data['invoice']);
  final order = _map(data['order']);
  final number = '${invoice['number'] ?? 'CYNA-${order['id'] ?? 'facture'}'}';
  final safeName = number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  await Printing.sharePdf(
    bytes: await buildInvoicePdf(data),
    filename: 'facture_$safeName.pdf',
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

pw.Widget _section(String title, List<String> lines) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xff0b3a75),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        ...lines.map((line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
            )),
      ],
    );

pw.Widget _invoiceHeader() => pw.Container(
      color: const PdfColor.fromInt(0xff0b3a75),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Row(
        children: [
          _cell('Service', flex: 4, color: PdfColors.white),
          _cell('Duree', color: PdfColors.white),
          _cell('Qte', color: PdfColors.white),
          _cell('Total', flex: 2, color: PdfColors.white, alignRight: true),
        ],
      ),
    );

pw.Widget _invoiceItem(Map<String, dynamic> item) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        children: [
          _cell('${item['product_name'] ?? 'Service CYNA'}', flex: 4),
          _cell('${item['duration_months'] ?? '-'} mois'),
          _cell('${item['quantity'] ?? '-'}'),
          _cell('${item['line_total'] ?? '0.00'} EUR', flex: 2, alignRight: true),
        ],
      ),
    );

pw.Widget _cell(
  String text, {
  int flex = 1,
  PdfColor color = PdfColors.black,
  bool alignRight = false,
}) =>
    pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 9, color: color),
      ),
    );
