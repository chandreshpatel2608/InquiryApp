import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'storefront_catalog_screen.dart';
import 'storefront_events_screen.dart';

enum _StorefrontMenuAction {
  customerLogin,
  profile,
  orders,
  signOut,
}

/// Shop home page. The store is resolved automatically, so customers never
/// have to know a store code.
class CustomerStorefrontScreen extends StatefulWidget {
  const CustomerStorefrontScreen({super.key});

  @override
  State<CustomerStorefrontScreen> createState() => _CustomerStorefrontScreenState();
}

class _CustomerStorefrontScreenState extends State<CustomerStorefrontScreen> {
  final _catalogKey = GlobalKey<StorefrontCatalogScreenState>();
  int? _cardProfileId;
  String _businessName = 'Shop';
  List<StorefrontCategory> _categories = const [
    StorefrontCategory(name: 'All'),
  ];
  String _category = 'All';
  List<String> _brands = const ['All'];
  String _brand = 'All';
  String _searchQuery = '';
  bool _newArrivalsOnly = false;
  List<int>? _imageMatchIds;
  bool _imageSearching = false;
  Map<String, dynamic>? _customer;
  bool _loading = true;
  String? _error;

  bool get _hasFilter =>
      _category != 'All' ||
      _brand != 'All' ||
      _newArrivalsOnly ||
      _imageMatchIds != null;

  @override
  void initState() {
    super.initState();
    _openStore();
  }

  Future<void> _openStore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await ApiService.getDefaultStorefront();
      if (!mounted) return;
      setState(() {
        _cardProfileId = store['cardProfileId'] as int?;
        _businessName = store['businessName']?.toString() ?? 'Shop';
        _error = _cardProfileId == null ? 'The store is unavailable right now.' : null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleMenuAction(_StorefrontMenuAction action) async {
    switch (action) {
      case _StorefrontMenuAction.customerLogin:
        await _catalogKey.currentState?.openCustomerSignIn();
      case _StorefrontMenuAction.profile:
        await _catalogKey.currentState?.openCustomerProfile();
      case _StorefrontMenuAction.orders:
        await _catalogKey.currentState?.openCustomerOrders();
      case _StorefrontMenuAction.signOut:
        await _catalogKey.currentState?.signOutCustomer();
    }
  }

  void _onCategoriesLoaded(List<StorefrontCategory> categories) {
    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (!categories.any((category) => category.name == _category)) {
        _category = 'All';
      }
    });
  }

  void _onBrandsLoaded(List<String> brands) {
    if (!mounted) return;
    setState(() {
      _brands = brands;
      if (!brands.contains(_brand)) _brand = 'All';
    });
  }

  void _onCustomerChanged(Map<String, dynamic>? customer) {
    if (!mounted) return;
    setState(() => _customer = customer);
  }

  Future<void> _openEvents() async {
    final profileId = _cardProfileId;
    if (profileId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StorefrontEventsScreen(cardProfileId: profileId),
      ),
    );
  }

  /// Lets the shopper photograph or pick a product picture and matches it against the catalogue.
  Future<void> _startImageSearch() async {
    final profileId = _cardProfileId;
    if (profileId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _imageSearching = true);
    try {
      final ids = await ApiService.imageSearchStorefront(profileId, picked.path);
      if (!mounted) return;
      setState(() {
        _imageMatchIds = ids;
        _category = 'All';
        _brand = 'All';
        _newArrivalsOnly = false;
        _searchQuery = '';
      });
      if (ids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No similar products found. Try another photo.'),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _imageSearching = false);
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var filter = '';
        return StatefulBuilder(
          builder: (_, setSheetState) {
            final visible = _categories
                .where(
                  (category) =>
                      filter.isEmpty ||
                      category.name.toLowerCase().contains(filter.toLowerCase()),
                )
                .toList();
            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Category',
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (value) => setSheetState(() => filter = value),
                      decoration: const InputDecoration(
                        hintText: 'Search Category',
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, index) {
                        final category = visible[index];
                        return ListTile(
                          leading: _categoryImage(category),
                          title: Text(
                            category.name == 'All'
                                ? 'All Categories'
                                : category.name,
                          ),
                          trailing: category.name == _category
                              ? const Icon(Icons.check)
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(sheetContext, category.name),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickBrand() => _pickFromList(
        title: 'Brand',
        searchHint: 'Search Brand',
        options: _brands,
        selected: _brand,
        onPicked: (value) => setState(() => _brand = value),
      );

  Widget _categoryImage(StorefrontCategory category) {
    final imageUrl = _imageUrl(category.imagePath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 42,
        height: 42,
        child: imageUrl.isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.category_outlined),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.category_outlined),
                ),
              ),
      ),
    );
  }

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$path';
  }

  Future<void> _openBusinessLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// Full-height picker sheet with its own search box, mirroring the website mega menu.
  Future<void> _pickFromList({
    required String title,
    required String searchHint,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onPicked,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var filter = '';
        return StatefulBuilder(
          builder: (_, setSheetState) {
            final visible = options
                .where((o) =>
                    filter.isEmpty ||
                    o.toLowerCase().contains(filter.toLowerCase()))
                .toList();
            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      onChanged: (value) => setSheetState(() => filter = value),
                      decoration: InputDecoration(
                        hintText: searchHint,
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, index) {
                        final option = visible[index];
                        return ListTile(
                          title: Text(option == 'All' ? 'All $title' : option),
                          trailing: option == selected
                              ? const Icon(Icons.check)
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(sheetContext, option),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool active = false,
  }) {
    const brandBlue = Color(0xFF0B5CA8);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: active ? Colors.white : brandBlue,
          backgroundColor: active ? brandBlue : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(label: Text(label), onDeleted: onClear),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B5CA8),
        foregroundColor: Colors.white,
        title: Text(_businessName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<_StorefrontMenuAction>(
            tooltip: _customer == null ? 'Sign in' : 'My account',
            onSelected: _handleMenuAction,
            icon: Icon(
              _customer == null
                  ? Icons.account_circle_outlined
                  : Icons.account_circle,
            ),
            itemBuilder: (_) => [
              if (_customer == null)
                const PopupMenuItem(
                  value: _StorefrontMenuAction.customerLogin,
                  child: ListTile(
                    leading: Icon(Icons.shopping_bag_outlined),
                    title: Text('Customer sign in'),
                  ),
                )
              else ...[
                PopupMenuItem(
                  value: _StorefrontMenuAction.profile,
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(_customer?['name']?.toString() ?? 'Profile'),
                  ),
                ),
                const PopupMenuItem(
                  value: _StorefrontMenuAction.orders,
                  child: ListTile(
                    leading: Icon(Icons.receipt_long_outlined),
                    title: Text('My orders'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _StorefrontMenuAction.signOut,
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sign out'),
                  ),
                ),
              ],
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(64 + 48 + (_hasFilter ? 44 : 0)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search dental products',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Search by image',
                      onPressed: _imageSearching ? null : _startImageSearch,
                      icon: _imageSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_search),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  children: [
                    _menuButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Category',
                      active: _category != 'All',
                      onTap: _categories.length > 1 ? _pickCategory : null,
                    ),
                    _menuButton(
                      icon: Icons.sell_outlined,
                      label: 'Brand',
                      active: _brand != 'All',
                      onTap: _brands.length > 1 ? _pickBrand : null,
                    ),
                    _menuButton(
                      icon: Icons.auto_awesome,
                      label: 'New Arrivals',
                      active: _newArrivalsOnly,
                      onTap: () => setState(
                        () => _newArrivalsOnly = !_newArrivalsOnly,
                      ),
                    ),
                    _menuButton(
                      icon: Icons.image_search,
                      label: 'Image Search',
                      active: _imageMatchIds != null,
                      onTap: _imageSearching ? null : _startImageSearch,
                    ),
                    _menuButton(
                      icon: Icons.event_outlined,
                      label: 'Events',
                      onTap: _openEvents,
                    ),
                    _menuButton(
                      icon: Icons.receipt_long_outlined,
                      label: 'My Orders',
                      onTap: () => _handleMenuAction(
                        _StorefrontMenuAction.orders,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasFilter)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    children: [
                      if (_category != 'All')
                        _filterChip(_category, () => setState(() => _category = 'All')),
                      if (_brand != 'All')
                        _filterChip(_brand, () => setState(() => _brand = 'All')),
                      if (_newArrivalsOnly)
                        _filterChip(
                          'New Arrivals',
                          () => setState(() => _newArrivalsOnly = false),
                        ),
                      if (_imageMatchIds != null)
                        _filterChip(
                          'Image match (${_imageMatchIds!.length})',
                          () => setState(() => _imageMatchIds = null),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _openStore,
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _cardProfileId == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.storefront_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(_error ?? 'The store is unavailable right now.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openStore,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 360) {
          _catalogKey.currentState?.loadMoreProducts();
        }
        return false;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: StorefrontCatalogScreen(
          key: _catalogKey,
          cardProfileId: _cardProfileId,
          category: _category,
          brand: _brand,
          searchQuery: _searchQuery,
          newArrivalsOnly: _newArrivalsOnly,
          imageMatchIds: _imageMatchIds,
          onCategoriesLoaded: _onCategoriesLoaded,
          onBrandsLoaded: _onBrandsLoaded,
          onCustomerChanged: _onCustomerChanged,
          onBusinessLogin: _openBusinessLogin,
        ),
      ),
    );
  }
}