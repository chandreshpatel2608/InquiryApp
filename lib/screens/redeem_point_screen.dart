import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config.dart';

class RedeemPointScreen extends StatefulWidget {
  final int userId;

  const RedeemPointScreen({super.key, required this.userId});

  @override
  State<RedeemPointScreen> createState() => _RedeemPointScreenState();
}

class _RedeemPointScreenState extends State<RedeemPointScreen> {
  final _mobileCtrl = TextEditingController();
  bool _searching = false;
  bool _loadingGifts = false;

  String? _personName;
  double? _totalPoints;
  String? _searchedMobile;
  List<dynamic> _gifts = [];
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    // Load available products up-front so they always display,
    // even before a customer is searched.
    _loadGifts();
  }

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
          _totalPoints = _parseDecimal(result?['totalPoints']) ?? 0;
        });
        _loadGifts();
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
        _loadGifts();
        _loadHistory();
      }
    }
  }

  Future<void> _loadHistory() async {
    if (_searchedMobile == null) return;
    try {
      final history = await ApiService.getRoyaltyHistory(widget.userId, _searchedMobile!);
      if (mounted) {
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

  Future<void> _loadGifts() async {
    setState(() => _loadingGifts = true);
    try {
      final gifts = await ApiService.getRedeemGifts(widget.userId);
      if (mounted) {
        setState(() {
          _gifts = gifts;
          _loadingGifts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingGifts = false);
    }
  }

  Future<void> _redeemProduct(dynamic gift) async {
    if (_searchedMobile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Redeem'),
        content: Text(
            'Redeem "${gift['productName']}" for ${gift['pointsRequired']} points from $_searchedMobile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Redeem', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.redeemPoints(
        widget.userId, _searchedMobile!, gift['id'] as int);

    if (result != null && mounted) {
      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Redeemed successfully!'), backgroundColor: Colors.green),
        );
        // Refresh points
        _searchMobile();
      }
    }
  }

  double? _parseDecimal(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Redeem Point Master'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload products',
            onPressed: _loadingGifts ? null : _loadGifts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadGifts();
          if (_searchedMobile != null) await _loadHistory();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Section
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
                              hintText: 'Enter mobile number',
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
                    // Show Name and Points after search
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
                                  Text(
                                    _personName ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text('Mobile: $_searchedMobile', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
                                '${_totalPoints?.toStringAsFixed(0) ?? "0"} pts',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
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

            const SizedBox(height: 20),

            // Products / Gifts List — always visible
            const Text('Available Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (_loadingGifts)
              const Center(child: CircularProgressIndicator())
            else if (_gifts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No products available for redemption.',
                            style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadGifts,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._gifts.map((gift) => _buildGiftCard(gift)),

            // Reward History — only after a customer is searched
            if (_searchedMobile != null) ...[
              const SizedBox(height: 20),
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
      ),
    );
  }

  Widget _buildGiftCard(dynamic gift) {
    final pointsRequired = gift['pointsRequired'] is num
        ? (gift['pointsRequired'] as num).toDouble()
        : double.tryParse(gift['pointsRequired'].toString()) ?? 0;
    final hasEnoughPoints = _totalPoints != null && _totalPoints! >= pointsRequired;
    final photoPath = gift['photoPath'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photoPath != null && photoPath.isNotEmpty
                  ? Image.network(
                      '${baseUrl.replaceAll('/digitalcard/api', '')}$photoPath',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.card_giftcard, size: 40, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.card_giftcard, size: 40, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gift['productName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${pointsRequired.toStringAsFixed(0)} Points',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                    ],
                  ),
                ],
              ),
            ),
            // Redeem Button
            ElevatedButton(
              onPressed: hasEnoughPoints ? () => _redeemProduct(gift) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasEnoughPoints ? Colors.green : Colors.grey[300],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Redeem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
