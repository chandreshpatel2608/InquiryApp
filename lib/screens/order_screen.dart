import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/operations_pdf.dart';
import '../widgets/searchable_dropdown.dart';

class OrderScreen extends StatefulWidget {
  final int userId;
  final String businessName;
  final String? businessAddress;
  const OrderScreen({super.key, required this.userId, required this.businessName, this.businessAddress});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await ApiService.getOrders(widget.userId);
      if (!mounted) return;
      setState(() { _orders = orders; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load orders: $error')));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => _OrderForm(userId: widget.userId, existing: existing),
    ));
    if (saved == true) { setState(() => _loading = true); await _load(); }
  }

  Future<void> _delete(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete order?'),
        content: const Text('This order and its items will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ApiService.deleteOrder(widget.userId, order['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deleted ? 'Order deleted.' : 'Delete failed.')));
    if (deleted) _load();
  }

  Future<void> _sendToPacking(Map<String, dynamic> order) async {
    final result = await ApiService.sendOrderToPackingList(widget.userId, order['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? 'Order sent to packing list.' : (result['error']?.toString() ?? 'Unable to send order.')),
    ));
    if (result['success'] == true) _load();
  }

  Future<void> _shareToWhatsApp(Map<String, dynamic> order) async {
    await SharePlus.instance.share(ShareParams(text: _orderShareText(order)));
  }

  String _orderShareText(Map<String, dynamic> order) =>
      'Order ${order['orderNumber'] ?? ''}\nCustomer: ${order['customerName'] ?? ''}\nTotal: ₹${order['totalAmount'] ?? 0}\nDate: ${order['orderDate'] ?? ''}'
      '${(order['transportName'] ?? '').toString().isEmpty ? '' : '\nTransport: ${order['transportName']}'}'
      '${(order['lrNumber'] ?? '').toString().isEmpty ? '' : '\nLR Number: ${order['lrNumber']}'}';

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final visible = _orders.where((order) => query.isEmpty || '${order['orderNumber']} ${order['customerName']} ${order['transportName'] ?? ''} ${order['lrNumber'] ?? ''}'.toLowerCase().contains(query)).toList();
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Orders')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openForm, icon: const Icon(Icons.add), label: const Text('New Order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Find by order ID, customer, transport or LR'), onChanged: (value) => setState(() => _search = value)),
                  const SizedBox(height: 8),
                  if (visible.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No orders yet.'))),
                  ...visible.map((order) => _orderCard(Map<String, dynamic>.from(order))),
                ],
              ),
            ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final sent = order['packingListId'] != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.receipt_long_outlined), const SizedBox(width: 10), Expanded(child: Text('${order['orderNumber'] ?? ''}  |  ${order['customerName'] ?? ''}', style: Theme.of(context).textTheme.titleMedium))]),
          const SizedBox(height: 5),
          Text('Date: ${order['orderDate'] ?? ''}  |  Items: ${(order['items'] as List?)?.length ?? 0}  |  Total: ₹${order['totalAmount'] ?? 0}'),
          Text('Payment: ${order['paymentOption'] ?? 'Cash'}'),
          if ((order['transportName'] ?? '').toString().isNotEmpty) Text('Transport: ${order['transportName']}'),
          if ((order['lrNumber'] ?? '').toString().isNotEmpty) Text('LR Number: ${order['lrNumber']}'),
          if ((order['address'] ?? '').toString().isNotEmpty) Text('Address: ${order['address']}'),
          if ((order['contactNumber'] ?? '').toString().isNotEmpty) Text('Contact: ${order['contactNumber']}'),
          if ((order['remark'] ?? '').toString().isNotEmpty) Text('Remark: ${order['remark']}'),
          Wrap(alignment: WrapAlignment.end, children: [
            IconButton(tooltip: 'Share order PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => OperationsPdf.shareOrder({...order, 'businessAddress': widget.businessAddress}, businessName: widget.businessName)),
            IconButton(tooltip: 'Share on WhatsApp', icon: const Icon(Icons.share_outlined, color: Colors.green), onPressed: () => _shareToWhatsApp(order)),
            IconButton(tooltip: 'Edit order', icon: const Icon(Icons.edit_outlined), onPressed: sent ? null : () => _openForm(order)),
            IconButton(tooltip: sent ? 'Already sent to packing list' : 'Send to packing list', icon: Icon(sent ? Icons.check_circle_outline : Icons.inventory_2_outlined, color: sent ? Colors.green : null), onPressed: sent ? null : () => _sendToPacking(order)),
            IconButton(tooltip: 'Delete order', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: sent ? null : () => _delete(order)),
          ]),
        ]),
      ),
    );
  }
}

class _OrderForm extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? existing;
  const _OrderForm({required this.userId, this.existing});
  @override
  State<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<_OrderForm> {
  static const _paymentOptions = ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Credit'];
  static const _gstOptions = [0.0, 5.0, 12.0, 18.0, 28.0];

  final _formKey = GlobalKey<FormState>();
  final _orderNumber = TextEditingController();
  final _remark = TextEditingController();
  final _lrNumber = TextEditingController();
  final _rows = <_OrderRow>[];
  List<dynamic> _customers = [];
  List<dynamic> _products = [];
  List<dynamic> _transports = [];
  int? _customerId;
  int? _transportId;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String _paymentOption = 'Cash';

  Map<String, dynamic>? get _customer => _customers.cast<Map<String, dynamic>?>().where((c) => c?['id'] == _customerId).firstOrNull;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final values = await Future.wait([
      ApiService.getCustomers(widget.userId),
      ApiService.getProducts(
        widget.userId,
        includeInactive: widget.existing != null,
      ),
      ApiService.getTransports(widget.userId),
    ]);
    final existing = widget.existing;
    String orderNumber = '';
    if (existing != null) {
      orderNumber = existing['orderNumber']?.toString() ?? '';
      _remark.text = existing['remark']?.toString() ?? '';
      _lrNumber.text = existing['lrNumber']?.toString() ?? '';
      final payment = existing['paymentOption']?.toString() ?? 'Cash';
      _paymentOption = _paymentOptions.contains(payment) ? payment : 'Cash';
      _customerId = existing['customerId'] as int?;
      _transportId = existing['transportId'] as int?;
      _date = DateTime.tryParse(existing['orderDate']?.toString() ?? '') ?? _date;
      for (final item in (existing['items'] as List? ?? const [])) {
        _rows.add(_OrderRow(
          productId: (item['productId'] ?? item['itemId']) as int?,
          variantId: item['variantId'] as int?,
          variantName: item['variantName']?.toString() ?? '',
          productName: item['item']?.toString() ?? '',
          qty: item['qty']?.toString() ?? '1',
          price: item['price']?.toString() ?? '0',
          hsn: item['hsnNumber']?.toString() ?? '',
          gstRate: item['gstRate']?.toString() ?? '0',
        ));
      }
    } else {
      orderNumber = await ApiService.getNextOrderNumber(widget.userId) ?? '';
    }
    if (_rows.isEmpty) _rows.add(_OrderRow());
    if (!mounted) return;
    setState(() {
      _orderNumber.text = orderNumber;
      _customers = values[0];
      _products = values[1];
      _transports = values[2];
      if (_transports.every((t) => t['id'] != _transportId)) _transportId = null;
      for (final row in _rows) {
        row.product = _products.cast<Map<String, dynamic>?>().where((p) => p?['id'] == row.productId).firstOrNull;
        // Keep the catalogue name so the saved line is not rebuilt as "Name - Variant - Variant".
        if (row.product != null) row.productName = row.product!['name']?.toString() ?? row.productName;
        final variants = (row.product?['variants'] as List? ?? const []);
        if (!variants.any((v) => v['id'] == row.variantId)) { row.variantId = null; row.variantName = ''; }
      }
      _loading = false;
    });
  }

  @override
  void dispose() { _orderNumber.dispose(); _remark.dispose(); _lrNumber.dispose(); for (final row in _rows) { row.dispose(); } super.dispose(); }

  double get _subTotal => _rows.fold(0, (sum, row) => sum + row.amount);
  double get _tax => _rows.fold(0, (sum, row) => sum + row.taxAmount);
  bool get _isInterState {
    final city = _customer?['city']?.toString().trim().toLowerCase();
    return city != null && city.isNotEmpty && city != 'ahmedabad';
  }
  double get _total => _subTotal + _tax;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) { _message('Select a customer.'); return; }
    if (_rows.any((row) => row.productId == null)) { _message('Select a product in every row.'); return; }
    setState(() => _saving = true);
    final result = await ApiService.saveOrder({
      'userId': widget.userId,
      'orderNumber': _orderNumber.text.trim(),
      'orderDate': _date.toIso8601String(),
      'customerId': _customerId,
      'remark': _remark.text.trim().isEmpty ? null : _remark.text.trim(),
      'paymentOption': _paymentOption,
      'transportId': _transportId,
      'lrNumber': _lrNumber.text.trim().isEmpty ? null : _lrNumber.text.trim(),
      'items': _rows.map((row) => row.toJson()).toList(),
    }, id: widget.existing?['id'] as int?);
    if (!mounted) return;
    if (result['success'] == true) { Navigator.pop(context, true); } else { setState(() => _saving = false); _message(result['error']?.toString() ?? 'Unable to save order.'); }
  }

  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    return Scaffold(
      appBar: AppBar(title: appBarTitle(widget.existing == null ? 'New Order' : 'Edit Order')),
      bottomNavigationBar: SafeArea(minimum: const EdgeInsets.all(12), child: FilledButton.icon(onPressed: _saving || _loading ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save Order'))),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [Expanded(child: TextFormField(controller: _orderNumber, readOnly: true, decoration: const InputDecoration(labelText: 'Order ID', helperText: 'Generated automatically'))), const SizedBox(width: 12), Expanded(child: InkWell(onTap: () async { final date = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (date != null) setState(() => _date = date); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Order Date *'), child: Text(DateFormat('dd MMM yyyy').format(_date)))))]),
          const SizedBox(height: 16),
          SearchableDropdown<Map<String, dynamic>>(items: _customers.map<Map<String, dynamic>>((c) => Map<String, dynamic>.from(c)).toList(), initialValue: _customerId == null ? null : _customers.cast<Map<String, dynamic>>().where((c) => c['id'] == _customerId).firstOrNull, itemLabel: (c) => c['name']?.toString() ?? '', labelText: 'Customer *', onChanged: (c) => setState(() => _customerId = c?['id'] as int?), validator: (v) => v == null ? 'Select a customer' : null),
          if (customer != null) Card(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Address: ${customer['address'] ?? '-'}'), const SizedBox(height: 4), Text('Contact: ${customer['mobile'] ?? '-'}')]))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _paymentOption,
            decoration: const InputDecoration(labelText: 'Payment Option *'),
            items: _paymentOptions
                .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                .toList(),
            onChanged: (value) => setState(() => _paymentOption = value ?? 'Cash'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _transportId,
            decoration: const InputDecoration(labelText: 'Transport', prefixIcon: Icon(Icons.local_shipping_outlined)),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('No transport')),
              ..._transports.map((t) => DropdownMenuItem<int?>(value: t['id'] as int, child: Text(t['name']?.toString() ?? ''))),
            ],
            onChanged: (value) => setState(() => _transportId = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lrNumber,
            decoration: const InputDecoration(labelText: 'LR Number', prefixIcon: Icon(Icons.confirmation_number_outlined)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _remark,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Remark', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_outlined)),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: () => setState(() => _rows.add(_OrderRow())), icon: const Icon(Icons.add), label: const Text('Add Item'))]),
          ...List.generate(_rows.length, (index) => _itemCard(index)),
            Align(alignment: Alignment.centerRight, child: Text(_isInterState
              ? 'Sub Total: ₹${_subTotal.toStringAsFixed(2)}\nIGST: ₹${_tax.toStringAsFixed(2)}\nGrand Total: ₹${_total.toStringAsFixed(2)}'
              : 'Sub Total: ₹${_subTotal.toStringAsFixed(2)}\nCGST: ₹${(_tax / 2).toStringAsFixed(2)}  SGST: ₹${(_tax / 2).toStringAsFixed(2)}\nGrand Total: ₹${_total.toStringAsFixed(2)}',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _itemCard(int index) {
    final row = _rows[index];
    final product = row.product;
    final variants = (product?['variants'] as List? ?? const []);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
            if (_rows.length > 1) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() { row.dispose(); _rows.removeAt(index); })),
          ]),
          SearchableDropdown<Map<String, dynamic>>(
            items: _products.map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p)).toList(),
            initialValue: product,
            itemLabel: (p) => p['name']?.toString() ?? '',
            labelText: 'Product *',
            onChanged: (p) => setState(() {
              row.product = p;
              row.productId = p?['id'] as int?;
              row.productName = p?['name']?.toString() ?? '';
              row.variantId = null;
              row.variantName = '';
              row.hsn.text = p?['hsnNumber']?.toString() ?? '';
              row.gstRate.text = p?['gstRate']?.toString() ?? '0';
              row.price.text = p?['price']?.toString() ?? '0';
            }),
            validator: (v) => v == null ? 'Select a product' : null,
          ),
          if (variants.isNotEmpty) DropdownButtonFormField<int>(
            initialValue: variants.any((v) => v['id'] == row.variantId) ? row.variantId : null,
            decoration: const InputDecoration(labelText: 'Variant'),
            items: variants.map<DropdownMenuItem<int>>((v) => DropdownMenuItem(value: v['id'] as int, child: Text(v['name']?.toString() ?? ''))).toList(),
            onChanged: (id) {
              final variant = variants.firstWhere((v) => v['id'] == id);
              setState(() { row.variantId = id; row.variantName = variant['name']?.toString() ?? ''; row.price.text = variant['price']?.toString() ?? row.price.text; });
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(controller: row.hsn, decoration: const InputDecoration(labelText: 'HSN Number'))),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<double>(initialValue: row.gstValue, decoration: const InputDecoration(labelText: 'GST %'), items: ({..._gstOptions, row.gstValue}.toList()..sort()).map((rate) => DropdownMenuItem(value: rate, child: Text('$rate%'))).toList(), onChanged: (rate) => setState(() => row.gstRate.text = '${rate ?? 0}'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(controller: row.qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Qty *'), onChanged: (_) => setState(() {}), validator: _positive)),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: row.price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price *'), onChanged: (_) => setState(() {}), validator: _nonNegative)),
          ]),
          Align(alignment: Alignment.centerRight, child: Text('Taxable: ₹${row.amount.toStringAsFixed(2)}  |  Tax: ₹${row.taxAmount.toStringAsFixed(2)}')),
        ]),
      ),
    );
  }

  String? _positive(String? value) { final number = double.tryParse(value ?? ''); return number == null || number <= 0 ? 'Enter a positive value' : null; }
  String? _nonNegative(String? value) { final number = double.tryParse(value ?? ''); return number == null || number < 0 ? 'Enter a valid price' : null; }
}

class _OrderRow {
  int? productId;
  int? variantId;
  String variantName;
  String productName;
  final qty = TextEditingController();
  final price = TextEditingController();
  final hsn = TextEditingController();
  final gstRate = TextEditingController(text: '0');
  Map<String, dynamic>? product;
  _OrderRow({this.productId, this.variantId, this.variantName = '', this.productName = '', String qty = '1', String price = '', String hsn = '', String gstRate = '0'}) { this.qty.text = qty; this.price.text = price; this.hsn.text = hsn; this.gstRate.text = gstRate; }
  double get amount => (double.tryParse(qty.text) ?? 0) * (double.tryParse(price.text) ?? 0);
  double get gstValue => double.tryParse(gstRate.text) ?? 0;
  double get taxAmount => amount * gstValue / 100;
  Map<String, dynamic> toJson() => {'productId': productId, 'variantId': variantId, 'variantName': variantName, 'item': variantName.isEmpty ? productName : '$productName - $variantName', 'hsnNumber': hsn.text.trim(), 'gstRate': gstValue, 'qty': double.tryParse(qty.text) ?? 0, 'price': double.tryParse(price.text) ?? 0};
  void dispose() { qty.dispose(); price.dispose(); hsn.dispose(); gstRate.dispose(); }
}
