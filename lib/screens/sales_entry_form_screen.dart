import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../config.dart';

class _SaleLine {
  int? itemId;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  _SaleLine({this.itemId, String qty = '1', String rate = ''})
      : qtyCtrl = TextEditingController(text: qty),
        rateCtrl = TextEditingController(text: rate);

  double get amount {
    final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    final r = double.tryParse(rateCtrl.text.trim()) ?? 0;
    return q * r;
  }

  void dispose() {
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

/// Add / Edit a Sales entry (invoice) with a multi-item grid.
class SalesEntryFormScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? existing; // sale detail for edit
  const SalesEntryFormScreen({super.key, required this.userId, this.existing});

  @override
  State<SalesEntryFormScreen> createState() => _SalesEntryFormScreenState();
}

class _SalesEntryFormScreenState extends State<SalesEntryFormScreen> {
  List<dynamic> _customers = [];
  List<dynamic> _items = [];
  bool _loading = true;
  bool _saving = false;

  int? _customerId;
  DateTime _invoiceDate = DateTime.now();
  final _invoiceNumberCtrl = TextEditingController();
  String _salesType = 'Retail';
  final List<_SaleLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _invoiceNumberCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final customers = await ApiService.getCustomers(widget.userId);
    final items = await ApiService.getItems(widget.userId);
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _items = items;
      _loading = false;
    });

    final e = widget.existing;
    if (e != null) {
      _customerId = e['customerId'];
      _invoiceNumberCtrl.text = e['invoiceNumber'] ?? '';
      _salesType = (e['salesType'] ?? 'Retail').toString();
      try { _invoiceDate = DateTime.parse(e['invoiceDate']); } catch (_) {}
      for (final it in (e['items'] as List? ?? [])) {
        _lines.add(_SaleLine(
          itemId: it['itemId'],
          qty: (it['qty'] ?? 1).toString(),
          rate: (it['rate'] ?? 0).toString(),
        ));
      }
      setState(() {});
    }
    if (_lines.isEmpty) _addLine();
  }

  void _addLine() => setState(() => _lines.add(_SaleLine()));

  void _removeLine(int i) => setState(() {
        _lines[i].dispose();
        _lines.removeAt(i);
      });

  double get _grandTotal => _lines.fold(0.0, (sum, l) => sum + l.amount);

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _save() async {
    if (_customerId == null) {
      _snack('Please select a customer', error: true);
      return;
    }
    if (_invoiceNumberCtrl.text.trim().isEmpty) {
      _snack('Invoice number is required', error: true);
      return;
    }
    final validLines = _lines.where((l) => l.itemId != null && l.amount > 0).toList();
    if (validLines.isEmpty) {
      _snack('Add at least one item with quantity and rate', error: true);
      return;
    }

    setState(() => _saving = true);
    final data = {
      'userId': widget.userId,
      'customerId': _customerId,
      'invoiceDate': _invoiceDate.toIso8601String(),
      'invoiceNumber': _invoiceNumberCtrl.text.trim(),
      'salesType': _salesType,
      'items': validLines.map((l) => {
            'itemId': l.itemId,
            'qty': int.tryParse(l.qtyCtrl.text.trim()) ?? 0,
            'rate': double.tryParse(l.rateCtrl.text.trim()) ?? 0,
            'amount': l.amount,
          }).toList(),
    };

    final result = await ApiService.saveSale(data, id: widget.existing?['id']);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      _snack(widget.existing == null ? 'Sale saved!' : 'Sale updated!');
      Navigator.pop(context, true);
    } else {
      _snack(result['error'] ?? 'Failed to save sale', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle(widget.existing == null ? 'New Sale' : 'Edit Sale'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_customers.isEmpty || _items.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _customers.isEmpty
                          ? 'Please add customers in Customer Master first.'
                          : 'Please add items in Item Master first.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _customerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Customer *', border: OutlineInputBorder()),
                      items: _customers
                          .map<DropdownMenuItem<int>>((c) => DropdownMenuItem<int>(
                                value: c['id'],
                                child: Text(c['name'] ?? '', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _customerId = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _invoiceNumberCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Invoice No *', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _invoiceDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _invoiceDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Invoice Date', border: OutlineInputBorder()),
                              child: Text(DateFormat('dd MMM yyyy').format(_invoiceDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _salesType,
                      decoration: const InputDecoration(
                          labelText: 'Sales Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Retail', child: Text('Retail')),
                        DropdownMenuItem(value: 'GST', child: Text('GST')),
                      ],
                      onChanged: (v) => setState(() => _salesType = v ?? 'Retail'),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._lines.asMap().entries.map((entry) => _buildLine(entry.key, entry.value)),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.teal.withAlpha(20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(currency.format(_grandTotal),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Sale'),
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _buildLine(int index, _SaleLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: line.itemId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Item', border: OutlineInputBorder(), isDense: true),
                    items: _items
                        .map<DropdownMenuItem<int>>((it) => DropdownMenuItem<int>(
                              value: it['id'],
                              child: Text(it['itemName'] ?? '', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => line.itemId = v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _lines.length > 1 ? () => _removeLine(index) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Rate', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Amount', border: OutlineInputBorder(), isDense: true),
                    child: Text(line.amount.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
