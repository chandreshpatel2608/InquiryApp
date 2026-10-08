import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

class StorefrontProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final int quantity;
  final Future<bool> Function(int productId, int quantity) onCartQuantityChanged;

  const StorefrontProductDetailScreen({
    super.key,
    required this.product,
    required this.quantity,
    required this.onCartQuantityChanged,
  });

  @override
  State<StorefrontProductDetailScreen> createState() =>
      _StorefrontProductDetailScreenState();
}

class _StorefrontProductDetailScreenState
    extends State<StorefrontProductDetailScreen> {
  late int _quantity;
  int _imageIndex = 0;

  static const _brandBlue = Color(0xFF0B5CA8);
  static const _brandGold = Color(0xFFF9A825);

  @override
  void initState() {
    super.initState();
    _quantity = widget.quantity;
  }

  int get _productId => _number(widget.product['id']);
  bool get _soldOut => _isTrue(widget.product['soldOut']);
  bool get _isEcommerce => _isTrue(widget.product['isEcommerce']);
  num get _price => _amount(widget.product['price']);

  List<String> get _images {
    final paths = List<dynamic>.from(widget.product['images'] ?? const [])
        .map((image) => _imageUrl(image?.toString()))
        .where((image) => image.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      final primaryImage = _imageUrl(widget.product['imagePath']?.toString());
      if (primaryImage.isNotEmpty) paths.add(primaryImage);
    }
    return paths;
  }

  int _number(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  num _amount(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isTrue(dynamic value) =>
      value == true || value?.toString().toLowerCase() == 'true';

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$path';
  }

  Future<void> _changeQuantity(int quantity) async {
    final updated = await widget.onCartQuantityChanged(_productId, quantity);
    if (updated && mounted) setState(() => _quantity = quantity);
  }

  Future<void> _openWhatsApp() async {
    final number = widget.product['whatsAppNumber']?.toString().trim() ?? '';
    if (number.isEmpty) return;

    final name = widget.product['name']?.toString() ?? 'this product';
    var message = widget.product['whatsAppMessage']?.toString().trim();
    if (message == null || message.isEmpty) {
      message = 'Hi Deval Enterprise LLP, I would like details about $name.';
    }
    final images = _images;
    if (images.isNotEmpty) message += '\n\nProduct image: ${images.first}';

    final phone = number.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = _images;
    final name = product['name']?.toString() ?? 'Product';
    final category = product['categoryName']?.toString() ?? 'Product';
    final brand = product['brandName']?.toString();
    final modelNumber = product['modelNumber']?.toString();
    final description = product['description']?.toString();
    final hasWhatsApp =
        (product['whatsAppNumber']?.toString().trim() ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductGallery(
              images: images,
              name: name,
              activeIndex: _imageIndex,
              onChanged: (index) => setState(() => _imageIndex = index),
            ),
            const SizedBox(height: 20),
            Text(
              category.toUpperCase(),
              style: const TextStyle(
                color: _brandBlue,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _brandBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            if ((brand ?? '').isNotEmpty || (modelNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if ((brand ?? '').isNotEmpty) 'Brand: $brand',
                  if ((modelNumber ?? '').isNotEmpty) 'Model: $modelNumber',
                ].join('  |  '),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            if (_price > 0) ...[
              const SizedBox(height: 14),
              Text(
                'Rs. ${_price.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _brandBlue,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if ((description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                description!,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
            const SizedBox(height: 24),
            if (hasWhatsApp)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openWhatsApp,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Enquire on WhatsApp'),
                ),
              ),
            if (hasWhatsApp) const SizedBox(height: 10),
            if (_soldOut)
              const SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: Text('Sold Out'),
                ),
              )
            else if (_isEcommerce && _price > 0)
              _CartQuantityControl(
                quantity: _quantity,
                brandColor: _brandBlue,
                accentColor: _brandGold,
                onChanged: _changeQuantity,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductGallery extends StatelessWidget {
  final List<String> images;
  final String name;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const _ProductGallery({
    required this.images,
    required this.name,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 320,
        color: Colors.white,
        child: images.isEmpty
            ? const Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 72,
                  color: Colors.black38,
                ),
              )
            : Stack(
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: onChanged,
                    itemBuilder: (_, index) => InteractiveViewer(
                      child: Image.network(
                        images[index],
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 52),
                        ),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activeIndex + 1}/${images.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CartQuantityControl extends StatelessWidget {
  final int quantity;
  final Color brandColor;
  final Color accentColor;
  final ValueChanged<int> onChanged;

  const _CartQuantityControl({
    required this.quantity,
    required this.brandColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => onChanged(1),
          style: FilledButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.add_shopping_cart_outlined),
          label: const Text('Add to Cart'),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: brandColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Remove one',
            onPressed: () => onChanged(quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$quantity in cart',
            style: TextStyle(color: brandColor, fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Add one',
            color: accentColor,
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}