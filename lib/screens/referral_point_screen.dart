import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';

class ReferralPointScreen extends StatefulWidget {
  final int userId;

  const ReferralPointScreen({super.key, required this.userId});

  @override
  State<ReferralPointScreen> createState() => _ReferralPointScreenState();
}

class _ReferralPointScreenState extends State<ReferralPointScreen> {
  final _mobileCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _billNoCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  bool _searching = false;
  bool _adding = false;
  String? _personName;
  double? _totalPoints;
  String? _searchedMobile;
  List<dynamic> _history = [];

  Future<void> _searchMobile() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isEmpty) return;

    setState(() {
      _searching = true;
      _personName = null;
      _totalPoints = null;
      _searchedMobile = null;
      _history = [];
    });

    try {
      final result = await ApiService.getRoyaltyPoints(widget.userId, mobile);
      if (mounted) {
        setState(() {
          _searching = false;
          _searchedMobile = mobile;
          _personName = result?['personName'] as String?;
          _totalPoints = _parseDouble(result?['totalPoints']) ?? 0;
        });
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchedMobile = mobile;
          _personName = null;
          _totalPoints = 0;
        });
        _loadHistory();
      }
    }
  }

  Future<void> _loadHistory() async {
    if (_searchedMobile == null) return;
    try {
      final history = await ApiService.getRoyaltyHistory(widget.userId, _searchedMobile!);
      if (mounted) {
        // Sum all history points for accurate total
        double sumPoints = 0;
        for (final h in history) {
          final pts = h['points'];
          if (pts is num) sumPoints += pts.toDouble();
        }
        setState(() {
          _history = history;
          _totalPoints = sumPoints;
        });
      }
    } catch (_) {}
  }

  Future<void> _addPoints() async {
    if (_searchedMobile == null) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _adding = true);
    final result = await ApiService.addReferralPoints(
      widget.userId,
      _searchedMobile!,
      amount,
      _billNoCtrl.text.trim().isNotEmpty ? _billNoCtrl.text.trim() : null,
      _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() => _adding = false);
      if (result != null && !result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Points added!'), backgroundColor: Colors.green),
        );
        _amountCtrl.clear();
        _billNoCtrl.clear();
        _remarksCtrl.clear();
        // Refresh
        _totalPoints = _parseDouble(result['totalPoints']);
        _loadHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result?['error'] ?? 'Failed.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _amountCtrl.dispose();
    _billNoCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Referral Point'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Search Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _mobileCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile No',
                              prefixIcon: Icon(Icons.phone),
                            ),
                            onSubmitted: (_) => _searchMobile(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _searching ? null : _searchMobile,
                          icon: _searching
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.search),
                          label: const Text('Search'),
                        ),
                      ],
                    ),
                    if (_searchedMobile != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withAlpha(80),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_personName ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Mobile: $_searchedMobile',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Text(
                                '${_totalPoints?.toStringAsFixed(2) ?? "0"} pts',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Add Points Form
            if (_searchedMobile != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add Referral Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Points = Amount × configured %', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _billNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bill No',
                          prefixIcon: Icon(Icons.receipt_long),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarksCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _adding ? null : _addPoints,
                          icon: _adding
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add),
                          label: const Text('Add Points', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // History
              const SizedBox(height: 16),
              const Text('Reward History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (_history.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text('No history found.', style: TextStyle(color: Colors.grey[500]))),
                  ),
                )
              else
                ..._history.map((h) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (h['points'] as num) >= 0 ? Colors.green[50] : Colors.red[50],
                          child: Icon(
                            (h['points'] as num) >= 0 ? Icons.add : Icons.remove,
                            color: (h['points'] as num) >= 0 ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${(h['points'] as num) >= 0 ? "+" : ""}${(h['points'] as num).toStringAsFixed(2)} pts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (h['points'] as num) >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        subtitle: Text(h['remark'] ?? '-', style: const TextStyle(fontSize: 12)),
                        trailing: Text(h['createdAt'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}
