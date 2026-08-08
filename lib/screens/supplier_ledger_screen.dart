import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Supplier Ledger — party-wise tracking for suppliers with jama/udhaar style entry.
class SupplierLedgerScreen extends StatefulWidget {
  final int userId;
  final String? businessName;
  const SupplierLedgerScreen({super.key, required this.userId, this.businessName});

  @override
  State<SupplierLedgerScreen> createState() => _SupplierLedgerScreenState();
}

class _SupplierLedgerScreenState extends State<SupplierLedgerScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _dispFmt = DateFormat('dd MMM yyyy');

  List<dynamic> _entries = [];
  List<dynamic> _suppliers = [];
  bool _loading = true;

  int? _filterSupplierId;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _suppliers = await ApiService.getSuppliers(widget.userId);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getSupplierLedger(
      widget.userId,
      supplierId: _filterSupplierId,
      fromDate: _fromDate != null ? _dateFmt.format(_fromDate!) : null,
      toDate: _toDate != null ? _dateFmt.format(_toDate!) : null,
    );
    if (mounted) {
      setState(() {
        _entries = data;
        _loading = false;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _form({Map<String, dynamic>? existing}) async {
    if (_suppliers.isEmpty) {
      _snack('Please add suppliers in Supplier Master first', error: true);
      return;
    }

    int? supplierId = existing?['supplierId'];
    DateTime entryDate = existing != null
        ? (DateTime.tryParse(existing['entryDate'] ?? '') ?? DateTime.now())
        : DateTime.now();
    final jamaCtrl = TextEditingController(
        text: existing != null ? (existing['amount'] ?? 0).toString() : '0');
    final udhaarCtrl = TextEditingController(
        text: existing != null ? (existing['receivedAmount'] ?? 0).toString() : '0');
    final remarksCtrl = TextEditingController(text: existing?['remarks'] ?? '');

    double totalPending = existing != null ? (existing['totalPending'] ?? 0).toDouble() : 0;
    bool saving = false;
    bool loadingPending = false;

    double computeFinal() {
      final jama = double.tryParse(jamaCtrl.text.trim()) ?? 0;
      final udhaar = double.tryParse(udhaarCtrl.text.trim()) ?? 0;
      return totalPending + jama - udhaar;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> refreshPending() async {
            if (supplierId == null) return;
            setModal(() => loadingPending = true);
            if (existing == null) {
              totalPending = await ApiService.getSupplierPartyPending(widget.userId, supplierId!);
            }
            setModal(() => loadingPending = false);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(existing == null ? 'Add Supplier Ledger' : 'Edit Supplier Ledger',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: supplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Supplier *', border: OutlineInputBorder()),
                    items: _suppliers
                        .map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(
                              value: s['id'],
                              child: Text(s['name'] ?? '', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      setModal(() => supplierId = v);
                      await refreshPending();
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: entryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setModal(() => entryDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Date', border: OutlineInputBorder()),
                      child: Text(_dispFmt.format(entryDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Pending',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        loadingPending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_currency.format(totalPending),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: jamaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Jama Amount (add pending)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder()),
                    onChanged: (_) => setModal(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: udhaarCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Udhaar / Paid Amount (reduce pending)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder()),
                    onChanged: (_) => setModal(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Final Pending',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(_currency.format(computeFinal()),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Remarks (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(saving ? 'Saving...' : 'Save Entry'),
                      onPressed: saving
                          ? null
                          : () async {
                              if (supplierId == null) {
                                _snack('Please select a supplier', error: true);
                                return;
                              }
                              setModal(() => saving = true);
                              final navigator = Navigator.of(ctx);
                              final result = await ApiService.saveSupplierLedger(
                                {
                                  'userId': widget.userId,
                                  'supplierId': supplierId,
                                  'entryDate': entryDate.toIso8601String(),
                                  'amount': double.tryParse(jamaCtrl.text.trim()) ?? 0,
                                  'receivedAmount': double.tryParse(udhaarCtrl.text.trim()) ?? 0,
                                  'remarks': remarksCtrl.text.trim(),
                                },
                                id: existing?['id'],
                              );
                              if (!mounted) return;
                              if (result['success'] == true) {
                                navigator.pop();
                                _snack(existing == null ? 'Entry added!' : 'Entry updated!');
                                _load();
                              } else {
                                setModal(() => saving = false);
                                _snack(result['error'] ?? 'Failed to save', error: true);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this supplier ledger entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      final success = await ApiService.deleteSupplierLedger(widget.userId, id);
      _snack(success ? 'Entry deleted' : 'Failed to delete', error: !success);
      if (success) _load();
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Supplier Ledger')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(child: Text('No supplier ledger entries found.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _entries.length,
                          itemBuilder: (ctx, i) => _buildEntryCard(_entries[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          DropdownButtonFormField<int?>(
            initialValue: _filterSupplierId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Supplier',
              prefixIcon: const Icon(Icons.person_search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All Suppliers')),
              ..._suppliers.map<DropdownMenuItem<int?>>((s) => DropdownMenuItem<int?>(
                    value: s['id'],
                    child: Text(s['name'] ?? '', overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) {
              setState(() => _filterSupplierId = v);
              _load();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_fromDate != null ? _dispFmt.format(_fromDate!) : 'From Date',
                      overflow: TextOverflow.ellipsis),
                  onPressed: () => _pickDate(isFrom: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_toDate != null ? _dispFmt.format(_toDate!) : 'To Date',
                      overflow: TextOverflow.ellipsis),
                  onPressed: () => _pickDate(isFrom: false),
                ),
              ),
              if (_fromDate != null || _toDate != null || _filterSupplierId != null)
                IconButton(
                  tooltip: 'Clear filters',
                  icon: const Icon(Icons.filter_alt_off, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _fromDate = null;
                      _toDate = null;
                      _filterSupplierId = null;
                    });
                    _load();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> e) {
    final finalPending = (e['finalPending'] ?? 0).toDouble();
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
                      Text(e['partyName'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(e['entryDate'] ?? '',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Final Pending', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      _currency.format(finalPending),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: finalPending > 0 ? Colors.deepOrange : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                _chip('Jama', _currency.format((e['amount'] ?? 0).toDouble()), Colors.blueGrey),
                _chip('Total Pending', _currency.format((e['totalPending'] ?? 0).toDouble()), Colors.orange),
                _chip('Udhaar/Paid', _currency.format((e['receivedAmount'] ?? 0).toDouble()), Colors.green),
              ],
            ),
            if ((e['remarks'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Note: ${e['remarks']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic)),
            ],
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _form(existing: e),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(e['id']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
