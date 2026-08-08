import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../config.dart';

class WhatsAppCatalogScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const WhatsAppCatalogScreen({super.key, required this.userData});

  @override
  State<WhatsAppCatalogScreen> createState() => _WhatsAppCatalogScreenState();
}

class _WhatsAppCatalogScreenState extends State<WhatsAppCatalogScreen> {
  List<dynamic> _products = [];
  bool _loading = true;
  Map<String, dynamic>? _cardProfile;

  int get _userId => widget.userData['userId'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getProducts(_userId),
        ApiService.getCardProfile(_userId),
      ]);
      if (mounted) {
        setState(() {
          _products = results[0] as List<dynamic>;
          _cardProfile = results[1] as Map<String, dynamic>?;
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

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    // Convert relative path to full URL
    final apiBase = baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '');
    return '$apiBase$path';
  }

  Future<void> _openWhatsAppOrder(Map<String, dynamic> product) async {
    final whatsApp = _cardProfile?['whatsAppNumber'] ?? '';
    if (whatsApp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp number not configured')),
      );
      return;
    }

    final productName = product['name'] ?? '';
    final price = product['price']?.toString() ?? '';
    final customMsg = product['whatsAppMessage'] ?? '';

    final message = customMsg.isNotEmpty
        ? customMsg
        : 'Hi! I want to order: $productName (₹$price). Please confirm.';

    final cleanWa = whatsApp.replaceAll('+', '').replaceAll(' ', '');
    final url = 'https://wa.me/$cleanWa?text=${Uri.encodeComponent(message)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openUpiPayment(Map<String, dynamic> product) async {
    final upiId = _cardProfile?['upiId'] ?? '';
    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI ID not configured')),
      );
      return;
    }

    final amount = product['price']?.toString() ?? '0';
    final businessName = _cardProfile?['businessName'] ?? 'Shop';
    final productName = product['name'] ?? 'Product';

    // UPI deep link
    final upiUrl = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}'
        '&am=$amount&tn=${Uri.encodeComponent('Payment for $productName')}&cu=INR';

    if (await canLaunchUrl(Uri.parse(upiUrl))) {
      await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI app found on this device')),
        );
      }
    }
  }

  void _shareCatalogLink() async {
    final slug = _cardProfile?['slug'] ?? '';
    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card not configured yet')),
      );
      return;
    }
    final apiBase = baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '');
    final link = '$apiBase/card/$slug';
    final msg = 'Check out our products! Order via WhatsApp: $link';
    final url = 'https://wa.me/?text=${Uri.encodeComponent(msg)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('WhatsApp Catalog + UPI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareCatalogLink,
            tooltip: 'Share Catalog Link',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No products found',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Add products from web admin panel',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // UPI & WhatsApp info bar
                    if (_cardProfile != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.green[50],
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green[700], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'UPI: ${_cardProfile!['upiId'] ?? 'Not set'} • WA: ${_cardProfile!['whatsAppNumber'] ?? 'Not set'}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.green[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Product list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final product = _products[i];
                          final imgPath = product['imagePath'] ?? '';
                          final imgUrl = _getImageUrl(imgPath);

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product image
                                if (imgUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14)),
                                    child: CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        height: 160,
                                        color: Colors.grey[200],
                                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      ),
                                      errorWidget: (_, _, _) =>
                                          Container(
                                        height: 100,
                                        color: Colors.grey[200],
                                        child: const Center(
                                            child: Icon(Icons.image,
                                                color: Colors.grey)),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(product['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      if (product['description'] != null &&
                                          (product['description'] as String)
                                              .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                              product['description'],
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13)),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (product['price'] != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '₹${product['price']}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[800],
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          const Spacer(),
                                          // WhatsApp Order
                                          FilledButton.tonalIcon(
                                            onPressed: () =>
                                                _openWhatsAppOrder(product),
                                            icon: const Icon(Icons.message,
                                                size: 16),
                                            label: const Text('Order',
                                                style:
                                                    TextStyle(fontSize: 12)),
                                            style:
                                                FilledButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green[100],
                                              foregroundColor:
                                                  Colors.green[800],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // UPI Pay
                                          if (product['isEcommerce'] == true)
                                            FilledButton.tonalIcon(
                                              onPressed: () =>
                                                  _openUpiPayment(product),
                                              icon: const Icon(
                                                  Icons.payment,
                                                  size: 16),
                                              label: const Text('Pay UPI',
                                                  style: TextStyle(
                                                      fontSize: 12)),
                                              style:
                                                  FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.blue[100],
                                                foregroundColor:
                                                    Colors.blue[800],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
