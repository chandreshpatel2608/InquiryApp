import 'package:flutter/material.dart';
import '../config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class GoogleReviewScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const GoogleReviewScreen({super.key, required this.userData});

  @override
  State<GoogleReviewScreen> createState() => _GoogleReviewScreenState();
}

class _GoogleReviewScreenState extends State<GoogleReviewScreen> {
  int get _userId => widget.userData['userId'];
  final _mobilesCtrl = TextEditingController();
  final _reviewLinkCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  bool _generated = false;
  bool _loadingData = true;
  List<String> _savedMobiles = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loadingData = true);
    try {
      // Fetch card profile and inquiry mobiles in parallel
      final results = await Future.wait([
        ApiService.getCardProfile(_userId),
        ApiService.getInquiries(_userId),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      final inquiries = results[1] as List<dynamic>;

      if (profile != null && mounted) {
        _reviewLinkCtrl.text = profile['googleReviewLink'] ?? widget.userData['googleReviewLink'] ?? '';
      }

      if (mounted) {
        final mobiles = <String>{};
        for (final inq in inquiries) {
          final m = (inq['mobile'] ?? '').toString().trim();
          if (m.isNotEmpty) mobiles.add(m);
        }
        setState(() {
          _savedMobiles = mobiles.toList()..sort();
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _reviewLinkCtrl.text = widget.userData['googleReviewLink'] ?? '';
        setState(() => _loadingData = false);
      }
    }
  }

  Future<void> _generateLinks() async {
    final mobiles = _mobilesCtrl.text
        .split(RegExp(r'[,\n;]+'))
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();

    if (mobiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one mobile number')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService.generateReviewLinks(
        _userId,
        mobiles,
        _reviewLinkCtrl.text.trim(),
      );
      if (result != null && mounted) {
        setState(() {
          _results = result['results'] ?? [];
          _generated = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWhatsAppLink(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendAll() async {
    for (final r in _results) {
      await _openWhatsAppLink(r['whatsappLink']);
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Google Review Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info
            Card(
              elevation: 0,
              color: Colors.amber[50],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter multiple mobile numbers. Each person will get a WhatsApp message with your Google Review link asking for 5 stars.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Google Review Link
            TextField(
              controller: _reviewLinkCtrl,
              decoration: const InputDecoration(
                labelText: 'Google Review Link',
                prefixIcon: Icon(Icons.link),
                hintText: 'https://g.page/r/...',
              ),
            ),
            const SizedBox(height: 14),

            // Quick-add saved mobiles from inquiries
            if (_loadingData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_savedMobiles.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Quick Add from Inquiries',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _mobilesCtrl.text = _savedMobiles.join('\n');
                    },
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Add All', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _savedMobiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: Text(_savedMobiles[i], style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final current = _mobilesCtrl.text.trim();
                      final num = _savedMobiles[i];
                      if (!current.contains(num)) {
                        _mobilesCtrl.text = current.isEmpty ? num : '$current\n$num';
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Mobile numbers
            TextField(
              controller: _mobilesCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Mobile Numbers',
                prefixIcon: Icon(Icons.phone),
                alignLabelWithHint: true,
                hintText:
                    'Enter numbers separated by comma or new line\ne.g.\n9876543210\n9876543211, 9876543212',
              ),
            ),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _loading ? null : _generateLinks,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Generate WhatsApp Links'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Results
            if (_generated && _results.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_results.length} Links Generated',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  FilledButton.tonalIcon(
                    onPressed: _sendAll,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send All'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      foregroundColor: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._results.map((r) => Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child:
                            Icon(Icons.person, color: Colors.green[700]),
                      ),
                      title: Text(r['mobile'] ?? '',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        r['message'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.message, color: Colors.green),
                        onPressed: () =>
                            _openWhatsAppLink(r['whatsappLink']),
                        tooltip: 'Send via WhatsApp',
                      ),
                    ),
                  )),

              const SizedBox(height: 12),
              // Preview message
              Card(
                elevation: 0,
                color: Colors.grey[100],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Message Preview',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        _results.isNotEmpty
                            ? _results.first['message'] ?? ''
                            : '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mobilesCtrl.dispose();
    _reviewLinkCtrl.dispose();
    super.dispose();
  }
}
