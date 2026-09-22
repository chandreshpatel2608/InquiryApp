import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';

class TransporterMasterScreen extends StatefulWidget {
  final int userId;
  const TransporterMasterScreen({super.key, required this.userId});

  @override
  State<TransporterMasterScreen> createState() => _TransporterMasterScreenState();
}

class _TransporterMasterScreenState extends State<TransporterMasterScreen> {
  List<dynamic> _transports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.getTransports(widget.userId);
    if (!mounted) return;
    setState(() {
      _transports = result;
      _loading = false;
    });
  }

  Future<void> _edit({Map<String, dynamic>? transport}) async {
    final controller = TextEditingController(text: transport?['name']?.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(transport == null ? 'Add Transporter' : 'Edit Transporter'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Transporter name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final result = await ApiService.saveTransport(widget.userId, controller.text, id: transport?['id'] as int?);
              if (!mounted) return;
              if (result['success'] == true) {
                Navigator.pop(dialogContext, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error']?.toString() ?? 'Unable to save transporter')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> transport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transporter?'),
        content: Text('Remove ${transport['name']} from the master?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ApiService.deleteTransport(widget.userId, transport['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Transporter deleted' : 'Unable to delete transporter')));
    if (success) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Transporter Master')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Transporter'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _transports.isEmpty
                  ? ListView(children: const [SizedBox(height: 220), Center(child: Text('No transporters yet.'))])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _transports.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final transport = Map<String, dynamic>.from(_transports[index]);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(Icons.local_shipping, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(transport['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Wrap(children: [
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(transport: transport)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(transport)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
