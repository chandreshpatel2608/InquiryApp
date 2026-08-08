import 'package:flutter/material.dart';
import '../config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';

class AutoStatusSchedulerScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AutoStatusSchedulerScreen({super.key, required this.userData});

  @override
  State<AutoStatusSchedulerScreen> createState() =>
      _AutoStatusSchedulerScreenState();
}

class _AutoStatusSchedulerScreenState extends State<AutoStatusSchedulerScreen> {
  int get _userId => widget.userData['userId'];
  List<dynamic> _statuses = [];
  bool _loading = true;

  // For creating new schedule
  final List<_StatusDraft> _drafts = [];
  bool _saving = false;

  final _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  final _timeSlots = ['08:00', '13:00', '20:00'];

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getScheduledStatuses(_userId);
      if (mounted) setState(() { _statuses = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addDraft() {
    setState(() {
      _drafts.add(_StatusDraft());
    });
  }

  void _removeDraft(int index) {
    setState(() => _drafts.removeAt(index));
  }

  Future<void> _pickImageForDraft(int index) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080);
    if (picked != null) {
      setState(() => _drafts[index].imageFile = File(picked.path));
    }
  }

  Future<void> _saveAllDrafts() async {
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one status')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Upload images first, then create statuses
      for (final draft in _drafts) {
        String imagePath = '';
        if (draft.imageFile != null) {
          final uploaded =
              await ApiService.uploadPostImage(draft.imageFile!, _userId);
          imagePath = uploaded ?? '';
        }
        await ApiService.createScheduledStatus({
          'userId': _userId,
          'imagePath': imagePath,
          'caption': draft.caption,
          'hashtags': draft.hashtags,
          'scheduledDay': draft.day,
          'scheduledTime': draft.time,
        });
      }

      if (mounted) {
        setState(() => _drafts.clear());
        _loadStatuses();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Statuses scheduled!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteStatus(int id) async {
    try {
      await ApiService.deleteScheduledStatus(id, _userId);
      _loadStatuses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Auto Status Scheduler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatuses,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              elevation: 0,
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Create 7 statuses on Sunday → App auto posts daily at 8AM, 1PM, 8PM',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Create new schedule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Create Weekly Schedule',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                FilledButton.tonalIcon(
                  onPressed: _addDraft,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Status'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Drafts
            ..._drafts.asMap().entries.map((entry) {
              final i = entry.key;
              final draft = entry.value;
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status #${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red[400]),
                            onPressed: () => _removeDraft(i),
                            iconSize: 20,
                          ),
                        ],
                      ),
                      // Image picker
                      GestureDetector(
                        onTap: () => _pickImageForDraft(i),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: draft.imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(draft.imageFile!,
                                      fit: BoxFit.cover,
                                      width: double.infinity),
                                )
                              : const Center(
                                  child: Icon(Icons.add_photo_alternate,
                                      color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Caption
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Caption',
                          isDense: true,
                        ),
                        onChanged: (v) => draft.caption = v,
                      ),
                      const SizedBox(height: 8),
                      // Day & Time
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: draft.day,
                              decoration: const InputDecoration(
                                labelText: 'Day',
                                isDense: true,
                              ),
                              items: _days.asMap().entries.map((e) {
                                return DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value,
                                      style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => draft.day = v ?? 0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: draft.time,
                              decoration: const InputDecoration(
                                labelText: 'Time',
                                isDense: true,
                              ),
                              items: _timeSlots
                                  .map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t == '08:00'
                                            ? '8:00 AM'
                                            : t == '13:00'
                                                ? '1:00 PM'
                                                : '8:00 PM'),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => draft.time = v ?? '08:00'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (_drafts.isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _saving ? null : _saveAllDrafts,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text('Save All ${_drafts.length} Statuses'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Existing scheduled statuses
            const Text('Scheduled Statuses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_statuses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('No scheduled statuses yet',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._statuses.map((s) => Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: s['isPosted'] == true
                            ? Colors.green[100]
                            : Colors.orange[100],
                        child: Icon(
                          s['isPosted'] == true
                              ? Icons.check_circle
                              : Icons.schedule,
                          color: s['isPosted'] == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      title: Text(
                        '${_days[s['scheduledDay'] ?? 0]} at ${s['scheduledTime']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        s['caption'] ?? 'No caption',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red[400]),
                        onPressed: () => _deleteStatus(s['id']),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _StatusDraft {
  File? imageFile;
  String caption = '';
  String hashtags = '';
  int day = 0; // Sunday
  String time = '08:00';
}
