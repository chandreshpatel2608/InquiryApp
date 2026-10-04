import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OperationsPdf {
  static Future<void> printPackingList(
    Map<String, dynamic> packingList, {
    required String businessName,
    String? boxNo,
  }) async {
    final bytes = await _buildPackingList(
      packingList,
      businessName,
      boxNo: boxNo,
    );
    await Printing.layoutPdf(
      name:
          'Packing_List_${packingList['number'] ?? packingList['id']}${boxNo == null ? '' : '_Box_$boxNo'}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> sharePackingList(
    Map<String, dynamic> packingList, {
    required String businessName,
    String? boxNo,
  }) async {
    final bytes = await _buildPackingList(
      packingList,
      businessName,
      boxNo: boxNo,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Packing_List_${packingList['number'] ?? packingList['id']}${boxNo == null ? '' : '_Box_$boxNo'}.pdf',
    );
  }

  static Future<void> shareBoxPackingList(
    Map<String, dynamic> packingList, {
    required String businessName,
    required String boxNo,
  }) async {
    final bytes = await _buildPackingList(
      packingList,
      businessName,
      boxNo: boxNo,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Packing_List_${packingList['number'] ?? packingList['id']}_Box_$boxNo.pdf',
    );
  }

  static Future<void> shareOrder(
    Map<String, dynamic> order, {
    required String businessName,
  }) async {
    final document = pw.Document();
    final items = List<dynamic>.from(order['items'] ?? const []);
    final subTotal = (order['subTotal'] ?? items.fold<double>(0, (sum, item) => sum + (double.tryParse('${item['qty']}') ?? 0) * (double.tryParse('${item['price']}') ?? 0))).toDouble();
    final cgst = (order['cgstAmount'] ?? 0).toDouble();
    final sgst = (order['sgstAmount'] ?? 0).toDouble();
    final igst = (order['igstAmount'] ?? 0).toDouble();
    final interState = order['isInterState'] == true;
    final tax = interState ? igst : cgst + sgst;
    final total = (order['totalAmount'] ?? (subTotal + tax)).toDouble();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            color: PdfColors.teal700,
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(businessName, style: pw.TextStyle(fontSize: 20, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                if ((order['businessAddress'] ?? '').toString().trim().isNotEmpty)
                  pw.Text(order['businessAddress'].toString(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
              ]),
              pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 15, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            data: [
              ['Order ID', order['orderNumber'] ?? ''],
              ['Order Date', _date(order['orderDate'])],
              ['Customer', order['customerName'] ?? ''],
              ['Contact', order['contactNumber'] ?? ''],
              ['Address', order['address'] ?? ''],
              ['Payment', order['paymentOption'] ?? 'Cash'],
              if ((order['transportName'] ?? '').toString().trim().isNotEmpty)
                ['Transport', order['transportName'] ?? ''],
              if ((order['lrNumber'] ?? '').toString().trim().isNotEmpty)
                ['LR Number', order['lrNumber'] ?? ''],
              if ((order['businessAddress'] ?? '').toString().trim().isNotEmpty)
                ['Business Address', order['businessAddress'] ?? ''],
              if ((order['remark'] ?? '').toString().trim().isNotEmpty)
                ['Remark', order['remark'] ?? ''],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'HSN', 'Qty', 'Rate', 'GST', 'Amount'],
            data: items.map((item) {
              final qty = double.tryParse('${item['qty']}') ?? 0;
              final price = double.tryParse('${item['price']}') ?? 0;
              final gstRate = double.tryParse('${item['gstRate'] ?? 0}') ?? 0;
              final lineTax = qty * price * gstRate / 100;
              return [item['item']?.toString() ?? '', item['hsnNumber']?.toString() ?? '', '$qty', 'Rs. ${price.toStringAsFixed(2)}', '${gstRate.toStringAsFixed(0)}% / Rs. ${lineTax.toStringAsFixed(2)}', 'Rs. ${(qty * price + lineTax).toStringAsFixed(2)}'];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Container(
            width: 230,
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.grey200,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Text('Sub Total: Rs. ${subTotal.toStringAsFixed(2)}'),
              pw.Text(interState ? 'IGST: Rs. ${igst.toStringAsFixed(2)}' : 'CGST: Rs. ${cgst.toStringAsFixed(2)}'),
              if (!interState) pw.Text('SGST: Rs. ${sgst.toStringAsFixed(2)}'),
              pw.Divider(),
              pw.Text('Grand Total: Rs. ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            ]),
          )),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'Order_${order['orderNumber'] ?? order['id']}.pdf',
    );
  }

  static Future<void> printReplacement(
    Map<String, dynamic> replacement, {
    required String businessName,
  }) async {
    final bytes = await _buildReplacement(replacement, businessName);
    await Printing.layoutPdf(
      name: 'Replacement_${replacement['invoiceNo'] ?? replacement['id']}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareReplacement(
    Map<String, dynamic> replacement, {
    required String businessName,
  }) async {
    final bytes = await _buildReplacement(replacement, businessName);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Replacement_${replacement['invoiceNo'] ?? replacement['id']}.pdf',
    );
  }

  static Future<Uint8List> _buildPackingList(
    Map<String, dynamic> data,
    String businessName, {
    String? boxNo,
  }) async {
    final items = List<dynamic>.from(data['items'] ?? const [])
        .where(
          (item) => boxNo == null || item['boxNo']?.toString().trim() == boxNo,
        )
        .toList();
    return _buildDocument(
      businessName: businessName,
      title: 'PACKING LIST',
      details: [
        ['Number', data['number'] ?? ''],
        ['Date', _date(data['date'])],
        ['Party', data['customerName'] ?? ''],
        ['Transporter', data['transportName'] ?? ''],
        ['LR No.', data['lrNumber'] ?? ''],
        if (boxNo != null) ['Box No.', boxNo],
      ],
      headers: const ['Item', 'Qty', 'Box', 'Height', 'Weight', 'Length'],
      rows: items
          .map<List<String>>(
            (item) => [
              item['item']?.toString() ?? '',
              item['qty']?.toString() ?? '',
              item['boxNo']?.toString() ?? '',
              item['height']?.toString() ?? '',
              item['weight']?.toString() ?? '',
              item['length']?.toString() ?? '',
            ],
          )
          .toList(),
      notes: data['notes']?.toString(),
      pageFormat: PdfPageFormat(4 * PdfPageFormat.inch, 6 * PdfPageFormat.inch),
      compact: true,
    );
  }

  static Future<Uint8List> _buildReplacement(
    Map<String, dynamic> data,
    String businessName,
  ) async {
    final items = List<dynamic>.from(data['items'] ?? const []);
    return _buildDocument(
      businessName: businessName,
      title: 'REPLACEMENT',
      details: [
        ['Invoice No.', data['invoiceNo'] ?? ''],
        ['Date', _date(data['date'])],
        ['Customer', data['customerName'] ?? ''],
        ['Courier', data['transportName'] ?? ''],
        ['Docket No.', data['courierDocketNo'] ?? ''],
        [
          'Packing / Parcels',
          '${data['packingSize'] ?? ''} / ${data['totalParcel'] ?? 0}',
        ],
      ],
      headers: const ['Item', 'Qty', 'Status'],
      rows: items
          .map<List<String>>(
            (item) => [
              item['item']?.toString() ?? '',
              item['qty']?.toString() ?? '',
              item['status']?.toString().toUpperCase() ?? '',
            ],
          )
          .toList(),
      pageFormat: PdfPageFormat.a4,
    );
  }

  static Future<Uint8List> _buildDocument({
    required String businessName,
    required String title,
    required List<List<dynamic>> details,
    required List<String> headers,
    required List<List<String>> rows,
    required PdfPageFormat pageFormat,
    String? notes,
    bool compact = false,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(compact ? 14 : 28),
        build: (_) => [
          pw.Text(
            businessName,
            style: pw.TextStyle(
              fontSize: compact ? 13 : 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: compact ? 10 : 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: compact ? 5 : 10),
          pw.TableHelper.fromTextArray(
            border: null,
            cellPadding: pw.EdgeInsets.symmetric(vertical: compact ? 1 : 2),
            data: details,
            cellStyle: pw.TextStyle(fontSize: compact ? 7 : 10),
            columnWidths: {
              0: pw.FixedColumnWidth(compact ? 54 : 90),
              1: const pw.FlexColumnWidth(),
            },
          ),
          pw.SizedBox(height: compact ? 7 : 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(
              fontSize: compact ? 6 : 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: compact ? 6 : 9),
            cellPadding: pw.EdgeInsets.symmetric(
              horizontal: compact ? 2 : 4,
              vertical: compact ? 2 : 4,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
          ),
          if (notes != null && notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: compact ? 6 : 12),
            pw.Text(
              'Notes: $notes',
              style: pw.TextStyle(fontSize: compact ? 7 : 10),
            ),
          ],
        ],
      ),
    );
    return document.save();
  }

  static String _date(dynamic raw) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw?.toString() ?? '';
    }
  }
}
