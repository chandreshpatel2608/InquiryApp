import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/sales_invoice_pdf.dart';
import '../config.dart';
import 'sales_entry_form_screen.dart';

/// Sales Entry — list of invoices with add / edit / delete / print (PDF).
class SalesEntryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const SalesEntryScreen({super.key, required this.userData});

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  int get _userId => widget.userData['userId'];
  String get _businessName => widget.userData['businessName'] ?? 'Invoice';
  String? get _businessPhone => widget.userData['whatsApp'] as String?;

  List<dynamic> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getSales(_userId);
    if (mounted) setState(() { _sales = data; _loading = false; });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    Map<String, dynamic>? detail;
    if (existing != null) {
      detail = await ApiService.getSaleDetail(_userId, existing['id']);
      if (detail == null) {
        _snack('Could not load sale', error: true);
        return;
      }
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SalesEntryFormScreen(userId: _userId, existing: detail),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _print(int id) async {
    _snack('Preparing invoice...');
    final detail = await ApiService.getSaleDetail(_userId, id);
    if (detail == null) {
      _snack('Could not load sale', error: true);
      return;
    }
    await SalesInvoicePdf.printInvoice(
      detail,
      businessName: _businessName,
      businessPhone: _businessPhone,
    );
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      final success = await ApiService.deleteSale(_userId, id);
      _snack(success ? 'Sale deleted' : 'Failed to delete', error: !success);
      if (success) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Sales Entry')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? const Center(child: Text('No sales yet. Tap "New Sale".'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sales.length,
                    itemBuilder: (ctx, i) {
                      final s = _sales[i];
                      final isGst = (s['salesType'] ?? '').toString().toLowerCase() == 'gst';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('#${s['invoiceNumber'] ?? ''}  •  ${s['customerName'] ?? ''}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text('${s['invoiceDate'] ?? ''}  •  ${s['itemCount'] ?? 0} item(s)',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(currency.format((s['totalAmount'] ?? 0).toDouble()),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal)),
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: (isGst ? Colors.indigo : Colors.orange).withAlpha(30),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(s['salesType'] ?? 'Retail',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isGst ? Colors.indigo : Colors.orange[800])),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Print PDF',
                                    icon: const Icon(Icons.print, color: Colors.teal),
                                    onPressed: () => _print(s['id']),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _openForm(existing: s),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _confirmDelete(s['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
