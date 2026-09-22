import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/api_service.dart';

class StorefrontCatalogScreen extends StatefulWidget {
  final int? cardProfileId;

  const StorefrontCatalogScreen({super.key, required this.cardProfileId});

  @override
  State<StorefrontCatalogScreen> createState() =>
      _StorefrontCatalogScreenState();
}

class _StorefrontCatalogScreenState extends State<StorefrontCatalogScreen> {
  List<dynamic> _products = [];
  Map<String, dynamic> _cart = const {'items': [], 'count': 0, 'total': 0};
  Map<String, dynamic>? _customer;
  bool _loading = true;
  String _category = 'All';

  String get _sessionKey => 'storefront_customer_${widget.cardProfileId}';
  String? get _token => _customer?['authToken']?.toString();
  List<dynamic> get _cartItems =>
      List<dynamic>.from(_cart['items'] ?? const []);
  int get _cartCount => _number(_cart['count']);

  @override
  void initState() {
    super.initState();
    _load();
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

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$path';
  }

  Future<void> _load() async {
    final profileId = widget.cardProfileId;
    if (profileId == null || profileId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? customer;
    final saved = prefs.getString(_sessionKey);
    if (saved != null) {
      try {
        customer = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      } on FormatException {
        await prefs.remove(_sessionKey);
      }
    }

    final products = await ApiService.getStorefrontProducts(profileId);
    Map<String, dynamic> cart = const {'items': [], 'count': 0, 'total': 0};
    final token = customer?['authToken']?.toString();
    if (token != null && token.isNotEmpty) {
      try {
        cart = await ApiService.getStorefrontCart(
          cardProfileId: profileId,
          token: token,
        );
      } on ApiException {
        await prefs.remove(_sessionKey);
        customer = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _products = products;
      _customer = customer;
      _cart = cart;
      _loading = false;
    });
  }

  Future<void> _refreshCart() async {
    final profileId = widget.cardProfileId;
    final token = _token;
    if (profileId == null || token == null) return;
    try {
      final cart = await ApiService.getStorefrontCart(
        cardProfileId: profileId,
        token: token,
      );
      if (mounted) setState(() => _cart = cart);
    } on ApiException {
      await _signOut(silent: true);
    }
  }

  Future<void> _showAuth() async {
    final profileId = widget.cardProfileId;
    if (profileId == null) return;
    final customer = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StorefrontAuthSheet(cardProfileId: profileId),
    );
    if (customer == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(customer));
    if (!mounted) return;
    setState(() => _customer = customer);
    await _refreshCart();
  }

  Future<void> _signOut({bool silent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    if (!mounted) return;
    setState(() {
      _customer = null;
      _cart = const {'items': [], 'count': 0, 'total': 0};
    });
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out of customer shopping.')),
      );
    }
  }

  int _quantityFor(int productId) {
    final item = _cartItems.cast<Map>().cast<Map<String, dynamic>>().firstWhere(
      (line) => _number(line['productId']) == productId,
      orElse: () => const {},
    );
    return _number(item['quantity']);
  }

  Future<void> _updateQuantity(int productId, int quantity) async {
    final profileId = widget.cardProfileId;
    final token = _token;
    if (profileId == null || token == null) {
      await _showAuth();
      return;
    }

    try {
      final cart = await ApiService.updateStorefrontCart(
        cardProfileId: profileId,
        token: token,
        productId: productId,
        quantity: quantity,
      );
      if (mounted) setState(() => _cart = cart);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openCart() async {
    if (_token == null) {
      await _showAuth();
      return;
    }
    final profileId = widget.cardProfileId;
    final customer = _customer;
    final token = _token;
    if (profileId == null || customer == null || token == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StorefrontCartScreen(
          cardProfileId: profileId,
          token: token,
          customer: customer,
        ),
      ),
    );
    await _refreshCart();
  }

  Future<void> _openOrders() async {
    final profileId = widget.cardProfileId;
    final token = _token;
    if (profileId == null || token == null) {
      await _showAuth();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StorefrontOrdersScreen(cardProfileId: profileId, token: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cardProfileId == null || widget.cardProfileId! <= 0) {
      return const SizedBox.shrink();
    }

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
                    'Shop',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'My orders',
                  onPressed: _openOrders,
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
                IconButton(
                  tooltip: _customer == null
                      ? 'Customer sign in'
                      : 'Customer account',
                  onPressed: _customer == null
                      ? _showAuth
                      : () => showModalBottomSheet<void>(
                          context: context,
                          builder: (sheetContext) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Text(
                                    _customer?['name']?.toString() ??
                                        'Customer',
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.receipt_long_outlined,
                                  ),
                                  title: const Text('My orders'),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _openOrders();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.logout),
                                  title: const Text('Sign out'),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _signOut();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                  icon: Icon(
                    _customer == null
                        ? Icons.person_outline
                        : Icons.account_circle_outlined,
                  ),
                ),
                Badge(
                  isLabelVisible: _cartCount > 0,
                  label: Text('$_cartCount'),
                  child: IconButton(
                    tooltip: 'Cart',
                    onPressed: _openCart,
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                ),
              ],
            ),
            if (categories.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
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
            ],
            const SizedBox(height: 12),
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
                  child: Text('No products are available.'),
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
                  final product = Map<String, dynamic>.from(
                    visible[index] as Map,
                  );
                  final productId = _number(product['id']);
                  final soldOut = product['soldOut'] == true;
                  final images = List<dynamic>.from(
                    product['images'] ?? const [],
                  );
                  final image = _imageUrl(
                    images.isNotEmpty
                        ? images.first?.toString()
                        : product['imagePath']?.toString(),
                  );
                  final quantity = _quantityFor(productId);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              image.isEmpty
                                  ? Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      child: const Center(
                                        child: Icon(
                                          Icons.inventory_2,
                                          size: 40,
                                        ),
                                      ),
                                    )
                                  : Image.network(
                                      image,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                          ),
                                    ),
                              if (soldOut)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade700,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'SOLD OUT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                            'Rs ${_amount(product['price']).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                          child: soldOut
                              ? const Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: 8,
                                      top: 6,
                                      bottom: 6,
                                    ),
                                    child: Text(
                                      'Sold Out',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : quantity == 0
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: 'Add to cart',
                                    icon: const Icon(Icons.add_shopping_cart),
                                    onPressed: () =>
                                        _updateQuantity(productId, 1),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Remove one',
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      onPressed: () => _updateQuantity(
                                        productId,
                                        quantity - 1,
                                      ),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Add one',
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      onPressed: () => _updateQuantity(
                                        productId,
                                        quantity + 1,
                                      ),
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

class _StorefrontAuthSheet extends StatefulWidget {
  final int cardProfileId;

  const _StorefrontAuthSheet({required this.cardProfileId});

  @override
  State<_StorefrontAuthSheet> createState() => _StorefrontAuthSheetState();
}

class _StorefrontAuthSheetState extends State<_StorefrontAuthSheet> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _address.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final customer = _register
          ? await ApiService.registerStorefrontCustomer(
              cardProfileId: widget.cardProfileId,
              name: _name.text.trim(),
              mobile: _mobile.text.trim(),
              password: _password.text,
              email: _email.text.trim(),
              address: _address.text.trim(),
            )
          : await ApiService.loginStorefrontCustomer(
              cardProfileId: widget.cardProfileId,
              mobile: _mobile.text.trim(),
              password: _password.text,
            );
      if (mounted) Navigator.pop(context, customer);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _register ? 'Create customer account' : 'Customer sign in',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_register) ...[
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 10),
              if (_register) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _address,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _password,
                obscureText: true,
                onSubmitted: (_) => _submitting ? null : _submit(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_register ? 'Create account' : 'Sign in'),
                ),
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _register = !_register),
                child: Text(
                  _register ? 'I already have an account' : 'Create an account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StorefrontCartScreen extends StatefulWidget {
  final int cardProfileId;
  final String token;
  final Map<String, dynamic> customer;

  const StorefrontCartScreen({
    super.key,
    required this.cardProfileId,
    required this.token,
    required this.customer,
  });

  @override
  State<StorefrontCartScreen> createState() => _StorefrontCartScreenState();
}

class _StorefrontCartScreenState extends State<StorefrontCartScreen> {
  Map<String, dynamic> _cart = const {'items': [], 'count': 0, 'total': 0};
  bool _loading = true;
  bool _saving = false;

  List<dynamic> get _items => List<dynamic>.from(_cart['items'] ?? const []);

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  num _amount(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

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
    try {
      final cart = await ApiService.getStorefrontCart(
        cardProfileId: widget.cardProfileId,
        token: widget.token,
      );
      if (mounted) setState(() => _cart = cart);
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setQuantity(int productId, int quantity) async {
    setState(() => _saving = true);
    try {
      final cart = await ApiService.updateStorefrontCart(
        cardProfileId: widget.cardProfileId,
        token: widget.token,
        productId: productId,
        quantity: quantity,
      );
      if (mounted) setState(() => _cart = cart);
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkout() async {
    if (_items.isEmpty || _saving) return;
    final details = await showModalBottomSheet<_CheckoutDetails>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StorefrontCheckoutSheet(customer: widget.customer),
    );
    if (details == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final result = await ApiService.checkoutStorefrontCart(
        cardProfileId: widget.cardProfileId,
        token: widget.token,
        deliveryAddress: details.address,
        paymentMethod: details.paymentMethod,
        name: details.name,
        mobile: details.mobile,
        email: details.email,
      );
      if (!mounted) return;
      final orderId = _number(result['orderId']);
      if (details.paymentMethod == 'upi') {
        final launched = await launchUrl(
          Uri.parse(result['upiUri'].toString()),
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (launched) {
          await _submitUpiReference(orderId);
          if (mounted) await _askForReview();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No UPI app is available. Open My orders to try payment again.',
              ),
            ),
          );
        }
      } else if (details.paymentMethod == 'card') {
        await _payWithRazorpay(orderId, details);
      } else if (details.paymentMethod == 'neft') {
        await _showBankTransfer(orderId, result['bank']);
        if (mounted) await _askForReview();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully.')),
        );
        await _askForReview();
        if (!mounted) return;
        Navigator.pop(context);
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _payWithRazorpay(int orderId, _CheckoutDetails details) async {
    try {
      final order = await ApiService.createMobileRazorpayOrder(
        orderId: orderId,
        token: widget.token,
      );
      if (!mounted) return;
      final razorpay = Razorpay();
      final completer = Completer<bool>();
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
        PaymentSuccessResponse response,
      ) async {
        try {
          await ApiService.verifyMobileRazorpay(
            orderId: orderId,
            token: widget.token,
            razorpayPaymentId: response.paymentId ?? '',
            razorpayOrderId: response.orderId ?? '',
            razorpaySignature: response.signature ?? '',
          );
          if (!completer.isCompleted) completer.complete(true);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(false);
        }
      });
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (
        PaymentFailureResponse response,
      ) {
        if (!completer.isCompleted) completer.complete(false);
      });
      razorpay.on(
        Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse response) {},
      );
      razorpay.open({
        'key': order['key'],
        'order_id': order['razorpayOrderId'],
        'amount': order['amount'],
        'name': order['name'] ?? 'Payment',
        'prefill': {'contact': details.mobile, 'email': details.email},
      });
      final ok = await completer.future;
      razorpay.clear();
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment successful.')));
        await _askForReview();
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment not completed. Open My orders to try again.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showBankTransfer(int orderId, dynamic bank) async {
    final map = bank is Map ? bank : const {};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bank transfer details'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.8,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.55,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((map['bankAccountHolder'] ?? '').toString().isNotEmpty)
                  Text('Name: ${map['bankAccountHolder']}'),
                if ((map['bankName'] ?? '').toString().isNotEmpty)
                  Text('Bank: ${map['bankName']}'),
                if ((map['bankAccountNumber'] ?? '').toString().isNotEmpty)
                  Text('A/C: ${map['bankAccountNumber']}'),
                if ((map['bankIfsc'] ?? '').toString().isNotEmpty)
                  Text('IFSC: ${map['bankIfsc']}'),
                const SizedBox(height: 8),
                const Text(
                  'Transfer the amount and submit the reference number to confirm.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('I have paid'),
          ),
        ],
      ),
    );
    if (mounted) await _submitUpiReference(orderId);
  }

  Future<void> _askForReview() async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('Rate your experience'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setDialog(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    final comment = commentCtrl.text.trim();
    commentCtrl.dispose();
    if (submitted != true) return;
    try {
      await ApiService.submitStorefrontReview(
        cardProfileId: widget.cardProfileId,
        token: widget.token,
        rating: rating,
        comment: comment.isEmpty ? null : comment,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your review!')),
        );
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _submitUpiReference(int orderId) async {
    final controller = TextEditingController();
    final reference = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('UPI payment reference'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Transaction ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reference == null || reference.isEmpty) return;
    try {
      await ApiService.submitStorefrontUpiPayment(
        orderId: orderId,
        token: widget.token,
        paymentReference: reference,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment reference submitted for verification.'),
          ),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _amount(_cart['total']);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, index) {
                final item = Map<String, dynamic>.from(_items[index] as Map);
                final productId = _number(item['productId']);
                final quantity = _number(item['quantity']);
                final image = _imageUrl(item['imagePath']?.toString());
                return Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: image.isEmpty
                          ? const Icon(Icons.inventory_2_outlined)
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Rs ${_amount(item['price']).toStringAsFixed(2)}',
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Remove one',
                                onPressed: _saving
                                    ? null
                                    : () =>
                                          _setQuantity(productId, quantity - 1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                '$quantity',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Add one',
                                onPressed: _saving
                                    ? null
                                    : () =>
                                          _setQuantity(productId, quantity + 1),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text('Rs ${_amount(item['lineTotal']).toStringAsFixed(2)}'),
                  ],
                );
              },
            ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total\nRs ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _checkout,
                    icon: const Icon(Icons.payment),
                    label: const Text('Checkout'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StorefrontCheckoutSheet extends StatefulWidget {
  final Map<String, dynamic> customer;

  const _StorefrontCheckoutSheet({required this.customer});

  @override
  State<_StorefrontCheckoutSheet> createState() =>
      _StorefrontCheckoutSheetState();
}

class _StorefrontCheckoutSheetState extends State<_StorefrontCheckoutSheet> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _address;
  String _paymentMethod = 'cod';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.customer['name']?.toString() ?? '',
    );
    _mobile = TextEditingController(
      text: widget.customer['mobile']?.toString() ?? '',
    );
    _email = TextEditingController(
      text: widget.customer['email']?.toString() ?? '',
    );
    _address = TextEditingController(
      text: widget.customer['address']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Checkout', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _address,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                ),
              ),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: _paymentMethod,
                onChanged: (value) => setState(() => _paymentMethod = value!),
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'cod',
                      title: Text('Cash on delivery'),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'upi',
                      title: Text('GPay / UPI'),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'card',
                      title: Text('Card / Net banking'),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'neft',
                      title: Text('NEFT / Bank transfer'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    _CheckoutDetails(
                      name: _name.text.trim(),
                      mobile: _mobile.text.trim(),
                      email: _email.text.trim(),
                      address: _address.text.trim(),
                      paymentMethod: _paymentMethod,
                    ),
                  ),
                  icon: const Icon(Icons.lock_outline),
                  label: Text(
                    _paymentMethod == 'upi'
                        ? 'Continue to UPI'
                        : _paymentMethod == 'card'
                        ? 'Continue to payment'
                        : 'Place order',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutDetails {
  final String name;
  final String mobile;
  final String email;
  final String address;
  final String paymentMethod;

  const _CheckoutDetails({
    required this.name,
    required this.mobile,
    required this.email,
    required this.address,
    required this.paymentMethod,
  });
}

class StorefrontOrdersScreen extends StatefulWidget {
  final int cardProfileId;
  final String token;

  const StorefrontOrdersScreen({
    super.key,
    required this.cardProfileId,
    required this.token,
  });

  @override
  State<StorefrontOrdersScreen> createState() => _StorefrontOrdersScreenState();
}

class _StorefrontOrdersScreenState extends State<StorefrontOrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await ApiService.getStorefrontOrders(
        cardProfileId: widget.cardProfileId,
        token: widget.token,
      );
      if (mounted) setState(() => _orders = orders);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _amount(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _editOrder(Map<String, dynamic> order) async {
    final nameCtrl = TextEditingController(
      text: order['customerName']?.toString() ?? '',
    );
    final mobileCtrl = TextEditingController(
      text: order['customerPhone']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: order['customerEmail']?.toString() ?? '',
    );
    final addressCtrl = TextEditingController(
      text: order['deliveryAddress']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit order #${order['id']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final mobile = mobileCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final address = addressCtrl.text.trim();
    nameCtrl.dispose();
    mobileCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    if (saved != true) return;
    try {
      await ApiService.editStorefrontOrder(
        orderId: _amount(order['id']).toInt(),
        token: widget.token,
        name: name,
        mobile: mobile,
        email: email.isEmpty ? null : email,
        deliveryAddress: address.isEmpty ? null : address,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order updated.')));
      await _load();
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _resumeUpiPayment(int orderId) async {
    try {
      final payment = await ApiService.getStorefrontUpiPayment(
        orderId: orderId,
        token: widget.token,
      );
      final launched = await launchUrl(
        Uri.parse(payment['upiUri'].toString()),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No UPI app is available on this device.'),
          ),
        );
        return;
      }

      final controller = TextEditingController();
      final reference = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('UPI payment reference'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Transaction ID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reference == null || reference.isEmpty) return;
      await ApiService.submitStorefrontUpiPayment(
        orderId: orderId,
        token: widget.token,
        paymentReference: reference,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment reference submitted for verification.'),
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : _orders.isEmpty
          ? const Center(child: Text('No orders yet.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final order = Map<String, dynamic>.from(
                    _orders[index] as Map,
                  );
                  final items = List<dynamic>.from(order['items'] ?? const []);
                  final isPendingUpi =
                      order['paymentMethod'] == 'UPI' &&
                      order['status'] == 'PaymentPending';
                  final canEdit = !const [
                    'Shipped',
                    'Delivered',
                    'Cancelled',
                  ].contains(order['status']?.toString());
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${order['id']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(order['status']?.toString() ?? ''),
                              if (canEdit)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  tooltip: 'Edit order',
                                  onPressed: () => _editOrder(order),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(order['createdAt']?.toString() ?? ''),
                          const SizedBox(height: 8),
                          ...items.map((item) {
                            final line = Map<String, dynamic>.from(item as Map);
                            return Text(
                              '${line['productName']} x${line['quantity']}',
                            );
                          }),
                          const SizedBox(height: 8),
                          Text(
                            'Rs ${_amount(order['totalAmount']).toStringAsFixed(2)} | ${order['paymentMethod']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (isPendingUpi) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _resumeUpiPayment(
                                _amount(order['id']).toInt(),
                              ),
                              icon: const Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                              label: const Text('Pay by UPI'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
