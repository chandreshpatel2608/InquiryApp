import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds & prints a PDF ledger statement from a list of ledger entries.
class LedgerPdf {
  static Future<void> printLedger(
    List<dynamic> entries, {
    String businessName = 'Ledger',
    String? partyName,
    String? fromDate,
    String? toDate,
  }) async {
    final doc = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

    double totalReceived = 0;
    double totalAmount = 0;
    for (final e in entries) {
      totalReceived += (e['receivedAmount'] ?? 0).toDouble();
      totalAmount += (e['amount'] ?? 0).toDouble();
    }
    final finalPending = entries.isNotEmpty ? (entries.first['finalPending'] ?? 0).toDouble() : 0.0;

    final subtitle = <String>[];
    if (partyName != null && partyName.isNotEmpty) subtitle.add('Party: $partyName');
    if (fromDate != null && fromDate.isNotEmpty) subtitle.add('From: $fromDate');
    if (toDate != null && toDate.isNotEmpty) subtitle.add('To: $toDate');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(businessName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('LEDGER STATEMENT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(subtitle.join('    |    '), style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.Divider(),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            headers: ['Date', 'Party', 'Amount', 'Total Pending', 'Received', 'Final Pending'],
            data: entries.map<List<String>>((e) => [
              (e['entryDate'] ?? '').toString(),
              (e['partyName'] ?? '').toString(),
              currency.format((e['amount'] ?? 0).toDouble()),
              currency.format((e['totalPending'] ?? 0).toDouble()),
              currency.format((e['receivedAmount'] ?? 0).toDouble()),
              currency.format((e['finalPending'] ?? 0).toDouble()),
            ]).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Charges: ${currency.format(totalAmount)}',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Total Received: ${currency.format(totalReceived)}',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 2),
                  if (partyName != null && partyName.isNotEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text('Current Pending: ${currency.format(finalPending)}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Ledger_${partyName ?? 'All'}.pdf',
    );
  }
}
