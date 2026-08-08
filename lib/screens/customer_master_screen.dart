import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Customer Master — add / edit / delete / list customers.
class CustomerMasterScreen extends StatefulWidget {
  final int userId;
  const CustomerMasterScreen({super.key, required this.userId});

  @override
  State<CustomerMasterScreen> createState() => _CustomerMasterScreenState();
}

class _CustomerMasterScreenState extends State<CustomerMasterScreen> {
  List<dynamic> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getCustomers(widget.userId);
    if (mounted) setState(() { _customers = data; _loading = false; });
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
    final gstCtrl = TextEditingController(text: existing?['gstNumber'] ?? '');
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
                    Text(existing == null ? 'Add Customer' : 'Edit Customer',
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
                  controller: gstCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'GST Number', border: OutlineInputBorder()),
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
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Customer'),
                    onPressed: saving ? null : () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        _snack('Customer name is required', error: true);
                        return;
                      }
                      setModal(() => saving = true);
                      final navigator = Navigator.of(ctx);
                      final result = await ApiService.saveCustomer({
                        'userId': widget.userId,
                        'name': nameCtrl.text.trim(),
                        'mobile': mobileCtrl.text.trim(),
                        'gstNumber': gstCtrl.text.trim(),
                        'address': addrCtrl.text.trim(),
                      }, id: existing?['id']);
                      if (!mounted) return;
                      if (result['success'] == true) {
                        navigator.pop();
                        _snack(existing == null ? 'Customer added!' : 'Customer updated!');
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
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      final success = await ApiService.deleteCustomer(widget.userId, id);
      _snack(success ? 'Customer deleted' : 'Failed to delete', error: !success);
      if (success) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Customer Master')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(child: Text('No customers yet. Tap "Add Customer".'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _customers.length,
                    itemBuilder: (ctx, i) {
                      final c = _customers[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.withAlpha(30),
                            child: const Icon(Icons.person, color: Colors.teal),
                          ),
                          title: Text(c['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([
                            if ((c['mobile'] ?? '').toString().isNotEmpty) '📞 ${c['mobile']}',
                            if ((c['gstNumber'] ?? '').toString().isNotEmpty) 'GST: ${c['gstNumber']}',
                            if ((c['address'] ?? '').toString().isNotEmpty) c['address'],
                          ].join('\n')),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _form(existing: c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(c['id']),
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
