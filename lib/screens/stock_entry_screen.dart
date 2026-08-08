import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Stock Entry — default shows all items with current stock, searchable by item
/// name. Add a purchase entry (item, qty, purchase date). List / delete entries.
class StockEntryScreen extends StatefulWidget {
  final int userId;
  const StockEntryScreen({super.key, required this.userId});

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _search = '';

  List<dynamic> _summary = [];
  List<dynamic> _entries = [];
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await ApiService.getStockSummary(widget.userId, search: _search);
    final entries = await ApiService.getStockEntries(widget.userId, search: _search);
    final items = await ApiService.getItems(widget.userId);
    if (mounted) {
      setState(() {
        _summary = summary;
        _entries = entries;
        _items = items;
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

  Future<void> _addStockForm() async {
    if (_items.isEmpty) {
      _snack('Please add items in Item Master first', error: true);
      return;
    }
    int? itemId;
    final qtyCtrl = TextEditingController();
    DateTime purchaseDate = DateTime.now();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
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
                    const Text('Add Stock Entry',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: itemId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Item *', border: OutlineInputBorder()),
                  items: _items
                      .map<DropdownMenuItem<int>>((it) => DropdownMenuItem<int>(
                            value: it['id'],
                            child: Text(it['itemName'] ?? '', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setModal(() => itemId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Quantity *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: purchaseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setModal(() => purchaseDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Purchase Date', border: OutlineInputBorder()),
                    child: Text(DateFormat('dd MMM yyyy').format(purchaseDate)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Stock'),
                    onPressed: saving ? null : () async {
                      if (itemId == null) {
                        _snack('Please select an item', error: true);
                        return;
                      }
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      if (qty <= 0) {
                        _snack('Enter a valid quantity', error: true);
                        return;
                      }
                      setModal(() => saving = true);
                      final navigator = Navigator.of(ctx);
                      final result = await ApiService.addStock({
                        'userId': widget.userId,
                        'itemId': itemId,
                        'quantity': qty,
                        'purchaseDate': purchaseDate.toIso8601String(),
                      });
                      if (!mounted) return;
                      if (result['success'] == true) {
                        navigator.pop();
                        _snack('Stock added!');
                        _load();
                      } else {
                        setModal(() => saving = false);
                        _snack(result['error'] ?? 'Failed to add stock', error: true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEntry(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stock Entry'),
        content: const Text('Delete this purchase entry? Current stock will be recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      final success = await ApiService.deleteStock(widget.userId, id);
      _snack(success ? 'Entry deleted' : 'Failed to delete', error: !success);
      if (success) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Stock Entry'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Current Stock'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Purchase Entries'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStockForm,
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by item name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _load();
                        }),
              ),
              onChanged: (v) => setState(() => _search = v),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [_buildSummary(), _buildEntries()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_summary.isEmpty) {
      return const Center(child: Text('No items found.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _summary.length,
        itemBuilder: (ctx, i) {
          final s = _summary[i];
          final stock = s['currentStock'] ?? 0;
          final low = stock <= 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (low ? Colors.red : Colors.green).withAlpha(30),
                child: Icon(Icons.inventory, color: low ? Colors.red : Colors.green),
              ),
              title: Text(s['itemName'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Purchased: ${s['totalPurchased']}  •  Sold: ${s['totalSold']}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$stock',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: low ? Colors.red : Colors.green)),
                  const Text('in stock', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntries() {
    if (_entries.isEmpty) {
      return const Center(child: Text('No purchase entries yet.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _entries.length,
        itemBuilder: (ctx, i) {
          final e = _entries[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withAlpha(30),
                child: const Icon(Icons.add_box, color: Colors.blue),
              ),
              title: Text(e['itemName'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Qty: ${e['quantity']}  •  ${e['purchaseDate']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDeleteEntry(e['id']),
              ),
            ),
          );
        },
      ),
    );
  }
}
