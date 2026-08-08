import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Supplier Master — add / edit / delete / list suppliers.
class SupplierMasterScreen extends StatefulWidget {
  final int userId;
  const SupplierMasterScreen({super.key, required this.userId});

  @override
  State<SupplierMasterScreen> createState() => _SupplierMasterScreenState();
}

class _SupplierMasterScreenState extends State<SupplierMasterScreen> {
  List<dynamic> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getSuppliers(widget.userId);
    if (mounted) {
      setState(() {
        _suppliers = data;
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
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final mobileCtrl = TextEditingController(text: existing?['mobile'] ?? '');
    final addrCtrl = TextEditingController(text: existing?['address'] ?? '');
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
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
                    Text(existing == null ? 'Add Supplier' : 'Edit Supplier',
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
                      labelText: 'Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Mobile', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Address', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Supplier'),
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              _snack('Supplier name is required', error: true);
                              return;
                            }
                            setModal(() => saving = true);
                            final navigator = Navigator.of(ctx);
                            final result = await ApiService.saveSupplier(
                              {
                                'userId': widget.userId,
                                'name': nameCtrl.text.trim(),
                                'mobile': mobileCtrl.text.trim(),
                                'address': addrCtrl.text.trim(),
                              },
                              id: existing?['id'],
                            );
                            if (!mounted) return;
                            if (result['success'] == true) {
                              navigator.pop();
                              _snack(existing == null ? 'Supplier added!' : 'Supplier updated!');
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
        title: const Text('Delete Supplier'),
        content: const Text('Are you sure you want to delete this supplier?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      final success = await ApiService.deleteSupplier(widget.userId, id);
      _snack(success ? 'Supplier deleted' : 'Failed to delete', error: !success);
      if (success) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Supplier Master')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Supplier'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? const Center(child: Text('No suppliers yet. Tap "Add Supplier".'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _suppliers.length,
                    itemBuilder: (ctx, i) {
                      final s = _suppliers[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.withAlpha(30),
                            child: const Icon(Icons.business, color: Colors.indigo),
                          ),
                          title: Text(s['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            if ((s['mobile'] ?? '').toString().isNotEmpty) '📞 ${s['mobile']}',
                            if ((s['address'] ?? '').toString().isNotEmpty) s['address'],
                          ].join('\n')),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _form(existing: s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(s['id']),
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
