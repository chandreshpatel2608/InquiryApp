import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../services/api_service.dart';

class MobileCatalogScreen extends StatefulWidget {
  final int userId;
  const MobileCatalogScreen({super.key, required this.userId});

  @override
  State<MobileCatalogScreen> createState() => _MobileCatalogScreenState();
}

class _MobileCatalogScreenState extends State<MobileCatalogScreen> {
  List<dynamic> _products = [];
  String _category = 'All';
  bool _loading = true;
  final Map<int, int> _cart = {};

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$path';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await ApiService.getProducts(widget.userId);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  void _add(Map<String, dynamic> product) {
    final id = product['id'] as int;
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} added to cart'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _shareProduct(Map<String, dynamic> product) async {
    final productName = product['name']?.toString() ?? 'Product';
    final price = product['price'] == null
        ? 'Price on request'
        : '₹${product['price']}';
    final productUrl =
        '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}/product/${product['id']}';
    final imagePaths = List<dynamic>.from(product['images'] ?? const []);
    final imagePath = imagePaths.isNotEmpty
        ? imagePaths.first?.toString()
        : product['imagePath']?.toString();
    final imageUrl = imagePath == null ? '' : _imageUrl(imagePath);

    await SharePlus.instance.share(
      ShareParams(
        title: productName,
        text:
            '$productName\nPrice: $price\n$productUrl'
            '${imageUrl.isEmpty ? '' : '\n$imageUrl'}',
      ),
    );
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final selected = _products
            .where((p) => _cart.containsKey(p['id']))
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your Cart',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (selected.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Your cart is empty.')),
                  ),
                ...selected.map((product) {
                  final productId = product['id'];
                  final productName = product['name']?.toString() ?? '';
                  final quantity = _cart[productId] ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(productName),
                    subtitle: Text('Quantity: $quantity'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          _cart.remove(product['id']);
                        });
                        Navigator.pop(sheetContext);
                        _openCart();
                      },
                    ),
                  );
                }),
                if (selected.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showLoginMessage(sheetContext),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Login to proceed'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLoginMessage(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please use the website Login to Proceed checkout flow.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      'All',
      ..._products.map(
        (p) => p['categoryName']?.toString() ?? 'Other Products',
      ),
    };
    final visible = _category == 'All'
        ? _products
        : _products
              .where(
                (p) =>
                    (p['categoryName']?.toString() ?? 'Other Products') ==
                    _category,
              )
              .toList();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Product Catalogue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Badge(
                  label: Text(
                    '${_cart.values.fold<int>(0, (sum, value) => sum + value)}',
                  ),
                  isLabelVisible: _cart.isNotEmpty,
                  child: IconButton(
                    onPressed: _openCart,
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                ),
              ],
            ),
            const Text(
              'Browse by category and add products to your cart.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (categories.length > 1)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final category = categories.elementAt(index);
                    return ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (visible.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No products available.'),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .68,
                ),
                itemBuilder: (_, index) {
                  final product = Map<String, dynamic>.from(visible[index]);
                  final images = List<dynamic>.from(
                    product['images'] ?? const [],
                  );
                  final image = _imageUrl(
                    images.isNotEmpty
                        ? images.first?.toString()
                        : product['imagePath']?.toString(),
                  );
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: image.isEmpty
                              ? Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  child: const Center(
                                    child: Icon(Icons.inventory_2, size: 40),
                                  ),
                                )
                              : Image.network(
                                  image,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                          child: Text(
                            product['name']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            product['categoryName']?.toString() ??
                                'Other Products',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['price'] == null
                                      ? 'Price on request'
                                      : '₹${product['price']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined),
                                tooltip: 'Share product',
                                onPressed: () => _shareProduct(product),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_shopping_cart),
                                tooltip: 'Add to cart',
                                onPressed: () => _add(product),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
