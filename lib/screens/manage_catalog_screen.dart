import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../config.dart';

/// Lets the mobile user create/manage Products and Gallery photos —
/// the same features available on the web at Admin/Products & Admin/Gallery.
class ManageCatalogScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ManageCatalogScreen({super.key, required this.userData});

  @override
  State<ManageCatalogScreen> createState() => _ManageCatalogScreenState();
}

class _ManageCatalogScreenState extends State<ManageCatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  int get _userId => widget.userData['userId'];

  List<dynamic> _products = [];
  List<dynamic> _gallery = [];
  bool _loadingProducts = true;
  bool _loadingGallery = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadProducts();
    _loadGallery();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _imageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$path';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // ── Products ──────────────────────────────────────────────────────────
  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final data = await ApiService.getProducts(_userId);
      if (mounted) setState(() { _products = data; _loadingProducts = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingProducts = false);
      _snack('Failed to load products: $e', error: true);
    }
  }

  Future<void> _loadGallery() async {
    setState(() => _loadingGallery = true);
    try {
      final data = await ApiService.getGallery(_userId);
      if (mounted) setState(() { _gallery = data; _loadingGallery = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingGallery = false);
      _snack('Failed to load gallery: $e', error: true);
    }
  }

  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1280, imageQuality: 88);
    return picked == null ? null : File(picked.path);
  }

  Future<void> _addProductDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final waCtrl = TextEditingController();
    File? image;
    bool isEcommerce = false;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Product',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final f = await _pickImage();
                        if (f != null) setModal(() => image = f);
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: image == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      color: Colors.grey[400], size: 34),
                                  const SizedBox(height: 6),
                                  Text('Tap to add product image',
                                      style: TextStyle(color: Colors.grey[500])),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(image!,
                                    fit: BoxFit.cover, width: double.infinity),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: waCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Message (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Buy button (e-commerce)'),
                      value: isEcommerce,
                      onChanged: (v) => setModal(() => isEcommerce = v),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(saving ? 'Saving...' : 'Save Product'),
                        onPressed: saving
                            ? null
                            : () async {
                                if (nameCtrl.text.trim().isEmpty) {
                                  _snack('Product name is required', error: true);
                                  return;
                                }
                                setModal(() => saving = true);
                                final navigator = Navigator.of(ctx);
                                final result = await ApiService.addProduct(
                                  userId: _userId,
                                  name: nameCtrl.text.trim(),
                                  description: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  price: double.tryParse(priceCtrl.text.trim()),
                                  whatsAppMessage: waCtrl.text.trim().isEmpty
                                      ? null
                                      : waCtrl.text.trim(),
                                  isEcommerce: isEcommerce,
                                  image: image,
                                );
                                if (!mounted) return;
                                if (result != null && !result.containsKey('error')) {
                                  navigator.pop();
                                  _snack('Product added!');
                                  _loadProducts();
                                } else {
                                  setModal(() => saving = false);
                                  _snack(result?['error'] ?? 'Failed to add product', error: true);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteProduct(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await ApiService.deleteProduct(_userId, id);
      if (success) {
        _snack('Product deleted');
        _loadProducts();
      } else {
        _snack('Failed to delete product', error: true);
      }
    }
  }

  // ── Gallery ───────────────────────────────────────────────────────────
  Future<void> _addGalleryPhoto() async {
    final image = await _pickImage();
    if (image == null) return;
    if (!mounted) return;
    final captionCtrl = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Gallery Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(image, height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionCtrl,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upload')),
        ],
      ),
    );

    if (!mounted) return;
    if (proceed == true) {
      _snack('Uploading photo...');
      final result = await ApiService.uploadGalleryPhoto(
        userId: _userId,
        caption: captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim(),
        image: image,
      );
      if (result != null && !result.containsKey('error')) {
        _snack('Photo uploaded!');
        _loadGallery();
      } else {
        _snack(result?['error'] ?? 'Failed to upload photo', error: true);
      }
    }
  }

  Future<void> _confirmDeletePhoto(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await ApiService.deleteGalleryPhoto(_userId, id);
      if (success) {
        _snack('Photo deleted');
        _loadGallery();
      } else {
        _snack('Failed to delete photo', error: true);
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Products & Gallery'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: 'Products'),
            Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildProductsTab(),
          _buildGalleryTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) => FloatingActionButton.extended(
          onPressed: _tabs.index == 0 ? _addProductDialog : _addGalleryPhoto,
          icon: const Icon(Icons.add),
          label: Text(_tabs.index == 0 ? 'Add Product' : 'Add Photo'),
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return _emptyState(Icons.storefront, 'No products yet',
          'Tap "Add Product" to create your first one');
    }
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _products.length,
        itemBuilder: (ctx, i) {
          final p = _products[i];
          final imgUrl = _imageUrl(p['imagePath'] ?? '');
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: imgUrl.isEmpty
                  ? Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.image, color: Colors.grey[400]),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imgUrl,
                        width: 56, height: 56, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                      ),
                    ),
              title: Text(p['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                p['price'] != null ? '₹ ${p['price']}' : (p['description'] ?? ''),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDeleteProduct(p['id']),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGalleryTab() {
    if (_loadingGallery) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_gallery.isEmpty) {
      return _emptyState(Icons.photo_library, 'No photos yet',
          'Tap "Add Photo" to upload gallery images');
    }
    return RefreshIndicator(
      onRefresh: _loadGallery,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _gallery.length,
        itemBuilder: (ctx, i) {
          final g = _gallery[i];
          final imgUrl = _imageUrl(g['imagePath'] ?? '');
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              Positioned(
                top: 2, right: 2,
                child: GestureDetector(
                  onTap: () => _confirmDeletePhoto(g['id']),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}
