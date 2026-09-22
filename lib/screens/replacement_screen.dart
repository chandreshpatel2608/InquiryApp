import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/operations_pdf.dart';

class ReplacementScreen extends StatefulWidget {
  final int userId;
  final String businessName;
  final bool canDelete;

  const ReplacementScreen({
    super.key,
    required this.userId,
    required this.businessName,
    this.canDelete = false,
  });

  @override
  State<ReplacementScreen> createState() => _ReplacementScreenState();
}

class _ReplacementScreenState extends State<ReplacementScreen> {
  List<dynamic> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await ApiService.getReplacements(widget.userId);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ReplacementForm(userId: widget.userId, existing: existing),
      ),
    );
    if (saved == true) {
      setState(() => _loading = true);
      await _load();
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete replacement?'),
        content: const Text('This record and its items will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ApiService.deleteReplacement(widget.userId, id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deleted ? 'Replacement deleted.' : 'Delete failed.')));
    if (deleted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Replacement')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('New Replacement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const Center(child: Text('No replacements yet.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                itemCount: _records.length,
                itemBuilder: (_, index) {
                  final record = Map<String, dynamic>.from(_records[index]);
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.swap_horiz),
                      ),
                      title: Text(record['customerName']?.toString() ?? ''),
                      subtitle: Text(
                        'Invoice: ${record['invoiceNo'] ?? ''}\n${record['date'] ?? ''}  |  ${record['totalParcel'] ?? 0} parcel(s)',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Edit Replacement',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openForm(record),
                          ),
                          IconButton(
                            tooltip: 'Print Replacement',
                            icon: const Icon(Icons.print_outlined),
                            onPressed: () => OperationsPdf.printReplacement(record, businessName: widget.businessName),
                          ),
                          if (widget.canDelete)
                            IconButton(
                              tooltip: 'Delete Replacement',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _delete(record['id'] as int),
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

class _ReplacementForm extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? existing;
  const _ReplacementForm({required this.userId, this.existing});

  @override
  State<_ReplacementForm> createState() => _ReplacementFormState();
}

class _ReplacementFormState extends State<_ReplacementForm> {
  final _formKey = GlobalKey<FormState>();
  final _invoice = TextEditingController();
  final _docket = TextEditingController();
  final _packingSize = TextEditingController();
  final _parcels = TextEditingController(text: '1');
  final _rows = <_ReplacementRow>[_ReplacementRow()];
  List<dynamic> _customers = [];
  List<dynamic> _transports = [];
  List<dynamic> _items = [];
  int? _customerId;
  int? _transportId;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _invoice.text = existing['invoiceNo']?.toString() ?? '';
      _docket.text = existing['courierDocketNo']?.toString() ?? '';
      _packingSize.text = existing['packingSize']?.toString() ?? '';
      _parcels.text = existing['totalParcel']?.toString() ?? '1';
      _customerId = existing['customerId'] as int?;
      _transportId = existing['transportId'] as int?;
      final parsedDate = DateTime.tryParse(existing['date']?.toString() ?? '');
      if (parsedDate != null) _date = parsedDate;
      final rows = (existing['items'] as List?) ?? const [];
      for (final item in rows) {
        final row = _ReplacementRow()
          ..itemId = item['itemId'] as int?
          ..itemName = item['item']?.toString() ?? ''
          ..status = item['status']?.toString() ?? 'pending';
        row.qty.text = item['qty']?.toString() ?? '1';
        _rows.add(row);
      }
      _rows.removeAt(0).dispose();
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final values = await Future.wait([
      ApiService.getCustomers(widget.userId),
      ApiService.getTransports(widget.userId),
      ApiService.getItems(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      _customers = values[0];
      _transports = values[1];
      _items = values[2];
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await ApiService.saveReplacement({
      'userId': widget.userId,
      'customerId': _customerId,
      'invoiceNo': _invoice.text.trim(),
      'courierDocketNo': _docket.text.trim(),
      'transportId': _transportId,
      'packingSize': _packingSize.text.trim(),
      'totalParcel': int.tryParse(_parcels.text) ?? 0,
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'items': _rows.map((row) => row.toJson()).toList(),
    }, id: widget.existing?['id'] as int?);
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error']?.toString() ?? 'Failed to save replacement.',
          ),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _invoice.dispose();
    _docket.dispose();
    _packingSize.dispose();
    _parcels.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle(widget.existing == null ? 'New Replacement' : 'Edit Replacement')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: _saving || _loading ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save Replacement'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _customerId,
                    decoration: const InputDecoration(labelText: 'Customer *'),
                    items: _customers
                        .map<DropdownMenuItem<int>>(
                          (customer) => DropdownMenuItem(
                            value: customer['id'] as int,
                            child: Text(customer['name']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _customerId = value),
                    validator: (value) =>
                        value == null ? 'Select a customer' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _invoice,
                    decoration: const InputDecoration(
                      labelText: 'Invoice No. *',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: _date,
                      );
                      if (value != null) setState(() => _date = value);
                    },
                  ),
                  TextFormField(
                    controller: _docket,
                    decoration: const InputDecoration(
                      labelText: 'Courier Docket No.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _transportId,
                    decoration: const InputDecoration(
                      labelText: 'Courier Name',
                    ),
                    items: _transports
                        .map<DropdownMenuItem<int>>(
                          (transport) => DropdownMenuItem(
                            value: transport['id'] as int,
                            child: Text(transport['name']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _transportId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _packingSize,
                    decoration: const InputDecoration(
                      labelText: 'Packing Size',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _parcels,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Parcel *',
                    ),
                    validator: _positive,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _rows.add(_ReplacementRow())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  ...List.generate(_rows.length, _itemCard),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _itemCard(int index) {
    final row = _rows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () =>
                        setState(() => _rows.removeAt(index).dispose()),
                  ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: row.itemId,
              decoration: const InputDecoration(labelText: 'Item *'),
              items: _items
                  .map<DropdownMenuItem<int>>(
                    (item) => DropdownMenuItem(
                      value: item['id'] as int,
                      child: Text(item['itemName']?.toString() ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                final item = _items.firstWhere(
                  (candidate) => candidate['id'] == value,
                );
                setState(() {
                  row.itemId = value;
                  row.itemName = item['itemName']?.toString() ?? '';
                });
              },
              validator: (value) => value == null ? 'Select an item' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: row.qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qty *'),
              validator: _positive,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: row.status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'close', child: Text('Close')),
              ],
              onChanged: (value) =>
                  setState(() => row.status = value ?? 'pending'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Required' : null;

  String? _positive(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number <= 0 ? 'Enter a positive value' : null;
  }
}

class _ReplacementRow {
  int? itemId;
  String itemName = '';
  final qty = TextEditingController(text: '1');
  String status = 'pending';

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'item': itemName,
    'qty': double.tryParse(qty.text) ?? 0,
    'status': status,
  };

  void dispose() => qty.dispose();
}
