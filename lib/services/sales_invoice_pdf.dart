import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds & prints a PDF invoice for a sales entry.
/// [sale] is the detail map returned by `ApiService.getSaleDetail`.
class SalesInvoicePdf {
  static Future<void> printInvoice(
    Map<String, dynamic> sale, {
    String businessName = 'Invoice',
    String? businessPhone,
  }) async {
    final doc = pw.Document();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

    final items = (sale['items'] as List?) ?? [];
    final total = (sale['totalAmount'] ?? 0).toDouble();
    final isGst = (sale['salesType'] ?? 'Retail').toString().toLowerCase() == 'gst';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(businessName,
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  if (businessPhone != null && businessPhone.isNotEmpty)
                    pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(isGst ? 'TAX INVOICE' : 'INVOICE',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('No: ${sale['invoiceNumber'] ?? ''}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: ${_fmtDate(sale['invoiceDate'])}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Type: ${sale['salesType'] ?? 'Retail'}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.Divider(),
          // Bill to
          pw.Text('Bill To:',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(sale['customerName'] ?? '', style: const pw.TextStyle(fontSize: 12)),
          if ((sale['customerMobile'] ?? '').toString().isNotEmpty)
            pw.Text('Mobile: ${sale['customerMobile']}', style: const pw.TextStyle(fontSize: 10)),
          if ((sale['customerGst'] ?? '').toString().isNotEmpty)
            pw.Text('GST: ${sale['customerGst']}', style: const pw.TextStyle(fontSize: 10)),
          if ((sale['customerAddress'] ?? '').toString().isNotEmpty)
            pw.Text(sale['customerAddress'], style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          // Items table
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            headers: isGst
                ? ['Item', 'HSN', 'Qty', 'Rate', 'Amount']
                : ['Item', 'Qty', 'Rate', 'Amount'],
            data: items.map<List<String>>((it) {
              final row = <String>[it['itemName'] ?? ''];
              if (isGst) row.add((it['hsnNumber'] ?? '').toString());
              row.add((it['qty'] ?? 0).toString());
              row.add(currency.format((it['rate'] ?? 0).toDouble()));
              row.add(currency.format((it['amount'] ?? 0).toDouble()));
              return row;
            }).toList(),
          ),
          pw.SizedBox(height: 10),
          // Total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text('Grand Total: ${currency.format(total)}',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Text('Thank you for your business!',
              style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Invoice_${sale['invoiceNumber'] ?? ''}.pdf',
    );
  }

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString());
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return raw.toString();
    }
  }
}
