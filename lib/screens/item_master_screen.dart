import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Item Master — add / edit / delete / list items (name + HSN number).
class ItemMasterScreen extends StatefulWidget {
  final int userId;
  const ItemMasterScreen({super.key, required this.userId});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getItems(widget.userId);
    if (mounted) setState(() { _items = data; _loading = false; });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _form({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['itemName'] ?? '');
    final hsnCtrl = TextEditingController(text: existing?['hsnNumber'] ?? '');
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
                    Text(existing == null ? 'Add Item' : 'Edit Item',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Item Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hsnCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'HSN Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Item'),
                    onPressed: saving ? null : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        _snack('Item name is required', error: true);
                        return;
                      }
                      setModal(() => saving = true);
                      final navigator = Navigator.of(ctx);
                      final result = await ApiService.saveItem({
                        'userId': widget.userId,
                        'itemName': nameCtrl.text.trim(),
                        'hsnNumber': hsnCtrl.text.trim(),
                      }, id: existing?['id']);
                      if (!mounted) return;
                      if (result['success'] == true) {
                        navigator.pop();
                        _snack(existing == null ? 'Item added!' : 'Item updated!');
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
        ),
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      final success = await ApiService.deleteItem(widget.userId, id);
      _snack(success ? 'Item deleted' : 'Failed to delete', error: !success);
      if (success) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Item Master')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No items yet. Tap "Add Item".'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final it = _items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.withAlpha(30),
                            child: const Icon(Icons.inventory_2, color: Colors.deepPurple),
                          ),
                          title: Text(it['itemName'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: (it['hsnNumber'] ?? '').toString().isNotEmpty
                              ? Text('HSN: ${it['hsnNumber']}')
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _form(existing: it),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(it['id']),
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
