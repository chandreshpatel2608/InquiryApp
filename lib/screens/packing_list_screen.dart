import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/operations_pdf.dart';
import '../widgets/searchable_dropdown.dart';

class PackingListScreen extends StatefulWidget {
  final int userId;
  final String businessName;
  final bool canDelete;

  const PackingListScreen({
    super.key,
    required this.userId,
    required this.businessName,
    this.canDelete = false,
  });

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> {
  List<dynamic> _records = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await ApiService.getPackingLists(widget.userId);
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
        builder: (_) =>
            _PackingListForm(userId: widget.userId, existing: existing),
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
        title: const Text('Delete packing list?'),
        content: const Text(
          'This record and its items will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ApiService.deletePackingList(widget.userId, id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'Packing list deleted.' : 'Delete failed.'),
      ),
    );
    if (deleted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Packing List')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('New Packing List'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const Center(child: Text('No packing lists yet.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                itemCount:
                    _records.where((record) {
                      final query = _search.trim().toLowerCase();
                      if (query.isEmpty) return true;
                      final value =
                          '${record['number'] ?? ''} ${record['lrNumber'] ?? ''}'
                              .toLowerCase();
                      return value.contains(query);
                    }).length +
                    1,
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Find by packing list or LR number',
                        ),
                        onChanged: (value) => setState(() => _search = value),
                      ),
                    );
                  }
                  final visible = _records.where((record) {
                    final query = _search.trim().toLowerCase();
                    if (query.isEmpty) return true;
                    return '${record['number'] ?? ''} ${record['lrNumber'] ?? ''}'
                        .toLowerCase()
                        .contains(query);
                  }).toList();
                  final record = Map<String, dynamic>.from(visible[index - 1]);
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.inventory)),
                      title: Text(record['customerName']?.toString() ?? ''),
                      subtitle: Text(
                        '${record['number'] ?? ''}  |  ${record['date'] ?? ''}\nLR: ${record['lrNumber'] ?? '-'}  |  ${(record['items'] as List?)?.length ?? 0} item(s)',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Edit Packing List',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openForm(record),
                          ),
                          IconButton(
                            tooltip: 'Print PDF',
                            icon: const Icon(Icons.print_outlined),
                            onPressed: () => _printPackingList(record),
                          ),
                          IconButton(
                            tooltip: 'Send PDF to WhatsApp',
                            icon: const Icon(
                              Icons.share_outlined,
                              color: Colors.green,
                            ),
                            onPressed: () => OperationsPdf.sharePackingList(
                              record,
                              businessName: widget.businessName,
                            ),
                          ),
                          if (widget.canDelete)
                            IconButton(
                              tooltip: 'Delete Packing List',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
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

  Future<void> _printPackingList(Map<String, dynamic> record) async {
    final boxNumbers =
        ((record['items'] as List?) ?? const [])
            .map((item) => (item['boxNo'] ?? '').toString().trim())
            .where((box) => box.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));

    String? selectedBox;
    if (boxNumbers.isNotEmpty) {
      selectedBox = await showDialog<String?>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Print packing list'),
          content: DropdownButtonFormField<String?>(
            initialValue: null,
            decoration: const InputDecoration(labelText: 'Box number'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Boxes'),
              ),
              ...boxNumbers.map(
                (box) => DropdownMenuItem<String?>(
                  value: box,
                  child: Text('Box $box'),
                ),
              ),
            ],
            onChanged: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, '__cancel__'),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selectedBox == '__cancel__') return;
    }

    await OperationsPdf.printPackingList(
      record,
      businessName: widget.businessName,
      boxNo: selectedBox,
    );
  }
}

class _PackingListForm extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? existing;
  const _PackingListForm({required this.userId, this.existing});

  @override
  State<_PackingListForm> createState() => _PackingListFormState();
}

class _PackingListFormState extends State<_PackingListForm> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _lrNumber = TextEditingController();
  final _notes = TextEditingController();
  final _rows = <_PackingRow>[_PackingRow()];
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
      _number.text = existing['number']?.toString() ?? '';
      _lrNumber.text = existing['lrNumber']?.toString() ?? '';
      _notes.text = existing['notes']?.toString() ?? '';
      _customerId = existing['customerId'] as int?;
      _transportId = existing['transportId'] as int?;
      final parsedDate = DateTime.tryParse(existing['date']?.toString() ?? '');
      if (parsedDate != null) _date = parsedDate;
      final rows = (existing['items'] as List?) ?? const [];
      for (final item in rows) {
        final row = _PackingRow()..itemId = item['itemId'] as int?;
        row.item.text = item['item']?.toString() ?? '';
        row.qty.text = item['qty']?.toString() ?? '1';
        row.box.text = item['boxNo']?.toString() ?? '';
        row.height.text = item['height']?.toString() ?? '';
        row.weight.text = item['weight']?.toString() ?? '';
        row.length.text = item['length']?.toString() ?? '';
        row.uploadPath = item['uploadItemPath']?.toString();
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
    for (final row in _rows) {
      if (row.image != null) {
        row.uploadPath = await ApiService.uploadPackingItem(
          widget.userId,
          row.image!,
        );
        if (row.uploadPath == null) {
          _message('Unable to upload an item image.');
          setState(() => _saving = false);
          return;
        }
      }
    }
    final result = await ApiService.savePackingList({
      'userId': widget.userId,
      'customerId': _customerId,
      'transportId': _transportId,
      'lrNumber': _lrNumber.text.trim(),
      'number': _number.text.trim(),
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'notes': _notes.text.trim(),
      'items': _rows.map((row) => row.toJson()).toList(),
    }, id: widget.existing?['id'] as int?);
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      _message(result['error']?.toString() ?? 'Failed to save packing list.');
      setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _number.dispose();
    _lrNumber.dispose();
    _notes.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle(
          widget.existing == null ? 'New Packing List' : 'Edit Packing List',
        ),
      ),
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
          label: Text(_saving ? 'Saving...' : 'Save Packing List'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SearchableDropdown<Map<String, dynamic>>(
                    items: _customers
                        .map<Map<String, dynamic>>(
                          (customer) => Map<String, dynamic>.from(customer),
                        )
                        .toList(),
                    initialValue: _customerId == null
                        ? null
                        : _customers.firstWhere(
                            (customer) => customer['id'] == _customerId,
                            orElse: () => null,
                          ),
                    itemLabel: (customer) => customer['name']?.toString() ?? '',
                    labelText: 'Customer *',
                    onChanged: (customer) =>
                        setState(() => _customerId = customer?['id'] as int?),
                    validator: (value) =>
                        value == null ? 'Select a customer' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _number,
                    decoration: const InputDecoration(
                      labelText: 'Packing List No. *',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Enter a number' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lrNumber,
                    decoration: const InputDecoration(labelText: 'LR Number'),
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
                  SearchableDropdown<Map<String, dynamic>>(
                    items: _transports
                        .map<Map<String, dynamic>>(
                          (transport) => Map<String, dynamic>.from(transport),
                        )
                        .toList(),
                    initialValue: _transportId == null
                        ? null
                        : _transports.firstWhere(
                            (transport) => transport['id'] == _transportId,
                            orElse: () => null,
                          ),
                    itemLabel: (transport) =>
                        transport['name']?.toString() ?? '',
                    labelText: 'Transport',
                    onChanged: (transport) =>
                        setState(() => _transportId = transport?['id'] as int?),
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
                            setState(() => _rows.add(_PackingRow())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  ...List.generate(_rows.length, (index) => _itemCard(index)),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
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
            SearchableDropdown<Map<String, dynamic>>(
              items: _items
                  .map<Map<String, dynamic>>(
                    (item) => Map<String, dynamic>.from(item),
                  )
                  .toList(),
              initialValue: row.itemId == null
                  ? null
                  : _items.firstWhere(
                      (item) => item['id'] == row.itemId,
                      orElse: () => null,
                    ),
              itemLabel: (item) => item['itemName']?.toString() ?? '',
              labelText: 'Item *',
              onChanged: (item) {
                setState(() {
                  row.itemId = item?['id'] as int?;
                  row.item.text = item?['itemName']?.toString() ?? '';
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
            TextFormField(
              controller: row.box,
              decoration: const InputDecoration(labelText: 'Box No.'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: row.height,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: row.weight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: row.length,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Length'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: Icon(
                  row.image == null ? Icons.upload_file : Icons.check_circle,
                  color: row.image == null ? null : Colors.green,
                ),
                label: Text(
                  row.image == null ? 'Upload Item' : 'Image Selected',
                ),
                onPressed: () async {
                  final source = await showModalBottomSheet<ImageSource>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera_alt),
                            title: const Text('Take photo'),
                            onTap: () =>
                                Navigator.pop(sheetContext, ImageSource.camera),
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Choose from gallery'),
                            onTap: () => Navigator.pop(
                              sheetContext,
                              ImageSource.gallery,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (source == null) return;
                  final image = await ImagePicker().pickImage(
                    source: source,
                    imageQuality: 82,
                  );
                  if (image != null) {
                    setState(() => row.image = File(image.path));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _positive(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number <= 0 ? 'Enter a positive value' : null;
  }
}

class _PackingRow {
  int? itemId;
  final item = TextEditingController();
  final qty = TextEditingController(text: '1');
  final box = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final length = TextEditingController();
  File? image;
  String? uploadPath;

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'item': item.text.trim(),
    'qty': double.tryParse(qty.text) ?? 0,
    'boxNo': box.text.trim(),
    'height': double.tryParse(height.text),
    'weight': double.tryParse(weight.text),
    'length': double.tryParse(length.text),
    'uploadItemPath': uploadPath,
  };

  void dispose() {
    item.dispose();
    qty.dispose();
    box.dispose();
    height.dispose();
    weight.dispose();
    length.dispose();
  }
}
