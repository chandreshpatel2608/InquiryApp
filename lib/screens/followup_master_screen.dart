import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';

class FollowupMasterScreen extends StatefulWidget {
  final int userId;

  const FollowupMasterScreen({super.key, required this.userId});

  @override
  State<FollowupMasterScreen> createState() => _FollowupMasterScreenState();
}

class _FollowupMasterScreenState extends State<FollowupMasterScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  List<dynamic> _inquiries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Default to today's data; the user can widen the range with the pickers.
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await ApiService.getFollowupInquiries(
      widget.userId,
      fromDate: _fromDate?.toIso8601String().split('T')[0],
      toDate: _toDate?.toIso8601String().split('T')[0],
    );
    if (mounted) {
      setState(() {
        _inquiries = data;
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _loadData();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Followup Master'),
      ),
      body: Column(
        children: [
          // Filter Row
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[50],
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'From',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _fromDate != null ? _formatDate(_fromDate!.toIso8601String()) : 'All',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'To',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _toDate != null ? _formatDate(_toDate!.toIso8601String()) : 'All',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.today, color: Colors.blue),
                  tooltip: 'Reset to today',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() {
                      _fromDate = DateTime(now.year, now.month, now.day);
                      _toDate = DateTime(now.year, now.month, now.day);
                    });
                    _loadData();
                  },
                ),
              ],
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Pending: ${_inquiries.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                const Icon(Icons.hourglass_empty, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                const Text('Only Pending', style: TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _inquiries.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Text('No pending inquiries found.',
                                    style: TextStyle(color: Colors.grey[500])),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _inquiries.length,
                          itemBuilder: (ctx, idx) => _buildCard(_inquiries[idx]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic inq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.orange[50],
          child: const Icon(Icons.person, color: Colors.orange),
        ),
        title: Text(inq['personName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📱 ${inq['mobile'] ?? '-'}', style: const TextStyle(fontSize: 12)),
            if (inq['brandName'] != null)
              Text('Brand: ${inq['brandName']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (inq['categoryName'] != null)
              Text('Category: ${inq['categoryName']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (inq['description'] != null && (inq['description'] as String).isNotEmpty)
              Text(inq['description'], style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_formatDate(inq['inquiryDate']),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            if (inq['price'] != null)
              Text('₹${(inq['price'] as num).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
