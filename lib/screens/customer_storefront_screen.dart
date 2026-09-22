import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'storefront_catalog_screen.dart';

class CustomerStorefrontScreen extends StatefulWidget {
  const CustomerStorefrontScreen({super.key});

  @override
  State<CustomerStorefrontScreen> createState() => _CustomerStorefrontScreenState();
}

class _CustomerStorefrontScreenState extends State<CustomerStorefrontScreen> {
  final _storeCode = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _storeCode.dispose();
    super.dispose();
  }

  Future<void> _openStore() async {
    final storeCode = _storeCode.text.trim();
    if (storeCode.isEmpty) {
      setState(() => _error = 'Enter the store code shared by the business.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await ApiService.resolveStorefront(storeCode);
      if (!mounted) return;
      final cardProfileId = store['cardProfileId'] as int?;
      if (cardProfileId == null) {
        setState(() => _error = 'The store profile is unavailable.');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CustomerStorePage(
            cardProfileId: cardProfileId,
            businessName: store['businessName']?.toString() ?? 'Shop',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer shopping')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.storefront_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Shop a business', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _storeCode,
                    autocorrect: false,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _openStore(),
                    decoration: const InputDecoration(
                      labelText: 'Store code',
                      prefixIcon: Icon(Icons.tag_outlined),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _loading ? null : _openStore,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Open store'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerStorePage extends StatelessWidget {
  final int cardProfileId;
  final String businessName;

  const _CustomerStorePage({
    required this.cardProfileId,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(businessName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StorefrontCatalogScreen(cardProfileId: cardProfileId),
        ),
      ),
    );
  }
}