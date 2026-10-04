import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'login_screen.dart';
import 'storefront_catalog_screen.dart';

enum _StorefrontMenuAction {
  customerLogin,
  businessLogin,
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
  List<String> _categories = const ['All'];
  String _category = 'All';
  List<String> _brands = const ['All'];
  String _brand = 'All';
  String _searchQuery = '';
  Map<String, dynamic>? _customer;
  bool _loading = true;
  String? _error;

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
      case _StorefrontMenuAction.businessLogin:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      case _StorefrontMenuAction.profile:
        await _catalogKey.currentState?.openCustomerProfile();
      case _StorefrontMenuAction.orders:
        await _catalogKey.currentState?.openCustomerOrders();
      case _StorefrontMenuAction.signOut:
        await _catalogKey.currentState?.signOutCustomer();
    }
  }

  void _onCategoriesLoaded(List<String> categories) {
    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (!categories.contains(_category)) _category = 'All';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              const PopupMenuItem(
                value: _StorefrontMenuAction.businessLogin,
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Business / admin login'),
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            64 + (_categories.length > 1 ? 48 : 0) + (_brands.length > 1 ? 48 : 0),
          ),
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
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_categories.length > 1)
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final category = _categories[index];
                      return ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
                ),
              if (_brands.length > 1)
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: _brands.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final brand = _brands[index];
                      return ChoiceChip(
                        label: Text(brand == 'All' ? 'All Brands' : brand),
                        selected: _brand == brand,
                        onSelected: (_) => setState(() => _brand = brand),
                      );
                    },
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: StorefrontCatalogScreen(
        key: _catalogKey,
        cardProfileId: _cardProfileId,
        category: _category,
        brand: _brand,
        searchQuery: _searchQuery,
        onCategoriesLoaded: _onCategoriesLoaded,
        onBrandsLoaded: _onBrandsLoaded,
        onCustomerChanged: _onCustomerChanged,
      ),
    );
  }
}