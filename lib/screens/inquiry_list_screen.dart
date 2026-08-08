import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';
import 'add_edit_inquiry_screen.dart';

class InquiryListScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const InquiryListScreen(
      {super.key, required this.userId, required this.userName});

  @override
  State<InquiryListScreen> createState() => _InquiryListScreenState();
}

class _InquiryListScreenState extends State<InquiryListScreen> {
  List<dynamic> _inquiries = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    // Default to today's data; the user can widen the range with the pickers.
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day);
    _loadInquiries();
    // Pre-load brands and categories into cache so Add/Edit screen opens instantly
    ApiService.getBrands(widget.userId);
    ApiService.getCategories(widget.userId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'All';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = DateTime(picked.year, picked.month, picked.day);
        } else {
          _toDate = DateTime(picked.year, picked.month, picked.day);
        }
        _applyFilter();
      });
    }
  }

  void _resetToday() {
    final now = DateTime.now();
    setState(() {
      _fromDate = DateTime(now.year, now.month, now.day);
      _toDate = DateTime(now.year, now.month, now.day);
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchQuery.toLowerCase();
    _filtered = _inquiries.where((inq) {
      // Date range filter (by created date)
      if (_fromDate != null || _toDate != null) {
        final createdStr = (inq['createdAt'] as String? ?? '');
        final datePart = createdStr.length >= 10 ? createdStr.substring(0, 10) : createdStr;
        final dt = DateTime.tryParse(datePart);
        if (dt != null) {
          final d = DateTime(dt.year, dt.month, dt.day);
          if (_fromDate != null && d.isBefore(_fromDate!)) return false;
          if (_toDate != null && d.isAfter(_toDate!)) return false;
        }
      }
      // Search filter
      if (q.isNotEmpty) {
        final name = (inq['personName'] as String? ?? '').toLowerCase();
        final mobile = (inq['mobile'] as String? ?? '').toLowerCase();
        final brand = (inq['brandName'] as String? ?? '').toLowerCase();
        if (!(name.contains(q) || mobile.contains(q) || brand.contains(q))) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _loadInquiries({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await ApiService.getInquiries(widget.userId, forceRefresh: true);
      if (mounted) {
        setState(() {
          _inquiries = data;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Inquiry Master'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInquiries,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date range filter (defaults to today)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'From',
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_formatDate(_fromDate), style: const TextStyle(fontSize: 13)),
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
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_formatDate(_toDate), style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.today, color: Colors.blue),
                        tooltip: 'Reset to today',
                        onPressed: _resetToday,
                      ),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search name, mobile, brand...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() { _searchQuery = ''; _applyFilter(); });
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) {
                      setState(() { _searchQuery = v.trim(); _applyFilter(); });
                    },
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(_searchQuery.isNotEmpty ? 'No results found' : 'No inquiries yet',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 16)),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Tap + to add your first inquiry',
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 13)),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadInquiries,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                      final inq = _filtered[i];
                      final payIcon = switch (inq['paymentType']) {
                        'finance' => Icons.account_balance,
                        'card' => Icons.credit_card,
                        _ => Icons.money,
                      };
                      final payColor = switch (inq['paymentType']) {
                        'finance' => Colors.blue,
                        'card' => Colors.purple,
                        _ => Colors.green,
                      };
                      final isClosed = inq['status'] == 'close';

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isClosed
                                ? Colors.green[100]
                                : Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              (inq['personName'] as String)
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isClosed
                                      ? Colors.green[800]
                                      : Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(inq['personName'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isClosed
                                      ? Colors.green[50]
                                      : Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isClosed ? 'CLOSE' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isClosed
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.phone,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(inq['mobile'],
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                Icon(payIcon, size: 14, color: payColor),
                                const SizedBox(width: 4),
                                Text(
                                    (inq['paymentType'] as String)
                                        .toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: payColor)),
                              ]),
                              if (inq['brandName'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(children: [
                                    Icon(Icons.branding_watermark,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(inq['brandName'],
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700]),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                ),
                              if (inq['categoryName'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(children: [
                                    Icon(Icons.category,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(inq['categoryName'],
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700]),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                ),
                              if (inq['price'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(children: [
                                    Icon(Icons.currency_rupee,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text('₹${inq['price']}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                    ),

                                  ]),
                                ),
                              if (inq['description'] != null &&
                                  (inq['description'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(inq['description'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ),
                              if (inq['createdBy'] != null &&
                                  (inq['createdBy'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(children: [
                                    Icon(Icons.person_outline,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(inq['createdBy'],
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700]),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEditInquiryScreen(
                                      userId: widget.userId,
                                      inquiry: inq,
                                    ),
                                  ),
                                ).then((_) => _loadInquiries(silent: true));
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditInquiryScreen(userId: widget.userId),
            ),
          ).then((_) => _loadInquiries(silent: true));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Inquiry'),
      ),
    );
  }
}
