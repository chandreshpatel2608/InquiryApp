import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';

class AddEditInquiryScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? inquiry; // null = add mode

  const AddEditInquiryScreen({super.key, required this.userId, this.inquiry});

  @override
  State<AddEditInquiryScreen> createState() => _AddEditInquiryScreenState();
}

class _AddEditInquiryScreenState extends State<AddEditInquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _descCtrl;
  String _paymentType = 'cash';
  String _status = 'pending';
  int? _brandId;
  int? _categoryId;
  DateTime? _inquiryDate;
  DateTime? _dob;
  DateTime? _anniversary;
  DateTime? _closeDate;
  bool _saving = false;

  List<dynamic> _brands = [];
  List<dynamic> _categories = [];
  bool _loadingBrands = true;
  bool _loadingCategories = true;

  bool get _isEdit => widget.inquiry != null;

  // Snapshot of the initial field values, used to detect unsaved changes.
  late Map<String, dynamic> _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final inq = widget.inquiry;
    _nameCtrl = TextEditingController(text: inq?['personName'] ?? '');
    _mobileCtrl = TextEditingController(text: inq?['mobile'] ?? '');
    _emailCtrl = TextEditingController(text: inq?['email'] ?? '');
    _priceCtrl = TextEditingController(
        text: inq?['price'] != null ? inq!['price'].toString() : '');
    _descCtrl = TextEditingController(text: inq?['description'] ?? '');
    _paymentType = inq?['paymentType'] ?? 'cash';
    _status = inq?['status'] ?? 'pending';
    _brandId = inq?['brandId'];
    _categoryId = inq?['categoryId'];
    if (inq?['inquiryDate'] != null) {
      _inquiryDate = DateTime.tryParse(inq!['inquiryDate']);
    }
    if (inq?['dateOfBirth'] != null) {
      _dob = DateTime.tryParse(inq!['dateOfBirth']);
    }
    if (inq?['anniversaryDate'] != null) {
      _anniversary = DateTime.tryParse(inq!['anniversaryDate']);
    }
    if (inq?['inquiryCloseDate'] != null) {
      _closeDate = DateTime.tryParse(inq!['inquiryCloseDate']);
    }
    _initialSnapshot = _currentSnapshot();
    _loadBrands();
    _loadCategories();
  }

  /// Captures the current form state for change detection.
  Map<String, dynamic> _currentSnapshot() => {
        'name': _nameCtrl.text.trim(),
        'mobile': _mobileCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'desc': _descCtrl.text.trim(),
        'payment': _paymentType,
        'status': _status,
        'brandId': _brandId,
        'categoryId': _categoryId,
        'inquiryDate': _inquiryDate?.toIso8601String(),
        'dob': _dob?.toIso8601String(),
        'anniversary': _anniversary?.toIso8601String(),
      };

  /// True when the user has entered/changed data that has not been saved.
  bool get _hasUnsavedChanges {
    final current = _currentSnapshot();
    for (final key in current.keys) {
      if (current[key] != _initialSnapshot[key]) return true;
    }
    return false;
  }

  /// Called when the user attempts to leave the screen with unsaved changes.
  /// Offers to Save (via the same logic as the Save button), Discard, or stay.
  Future<void> _handleBackWithUnsavedChanges() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: Text(_isEdit
            ? 'You have unsaved changes. Save them before leaving?'
            : 'This inquiry has not been saved yet. Save it before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == 'discard') {
      Navigator.pop(context);
    } else if (choice == 'save') {
      // _save() pops the screen itself on success.
      await _save();
    }
    // 'cancel'/null: stay on the screen.
  }


  Future<void> _loadBrands() async {
    final brands = await ApiService.getBrands(widget.userId);
    if (mounted) {
      setState(() {
        _brands = brands;
        _loadingBrands = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    final categories = await ApiService.getCategories(widget.userId);
    if (mounted) {
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    }
  }

  Future<void> _pickDate(String field) async {
    final initial = field == 'inquiry'
        ? _inquiryDate
        : field == 'dob'
            ? _dob
            : _anniversary;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (field == 'inquiry') {
          _inquiryDate = picked;
        } else if (field == 'dob') {
          _dob = picked;
        } else {
          _anniversary = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Not set';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // If status is changing to "close", ask for close date
    final wasClose = widget.inquiry?['status'] == 'close';
    if (_status == 'close' && !wasClose) {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        helpText: 'Select Close Date',
      );
      if (pickedDate == null) return; // User cancelled
      _closeDate = pickedDate;
    }

    setState(() => _saving = true);

    final data = {
      'userId': widget.userId,
      'personName': _nameCtrl.text.trim(),
      'mobile': _mobileCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      'brandId': _brandId,
      'categoryId': _categoryId,
      'inquiryDate': _inquiryDate?.toIso8601String(),
      'price': _priceCtrl.text.trim().isNotEmpty
          ? double.tryParse(_priceCtrl.text.trim())
          : null,
      'status': _status,
      'paymentType': _paymentType,
      'dateOfBirth': _dob?.toIso8601String(),
      'anniversaryDate': _anniversary?.toIso8601String(),
      'description': _descCtrl.text.trim(),
      if (_closeDate != null) 'inquiryCloseDate': _closeDate!.toIso8601String(),
    };

    bool ok;
    String? errorMsg;
    if (_isEdit) {
      ok = await ApiService.updateInquiry(widget.inquiry!['id'], data);
    } else {
      final result = await ApiService.createInquiry(data);
      ok = result['success'] == true;
      if (!ok) errorMsg = result['error'] as String?;
    }

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Inquiry updated' : 'Inquiry added'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMsg ?? 'Failed to save. Try again.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_saving) return;
        if (_hasUnsavedChanges) {
          await _handleBackWithUnsavedChanges();
        } else if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: appBarTitle(_isEdit ? 'Edit Inquiry' : 'Add Inquiry'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            // Extra bottom padding so the Save button is never clipped by the
            // device's system navigation bar / home indicator or the keyboard.
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Person Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Person Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Mobile
              TextFormField(
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile No *',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Brand - Searchable
              _loadingBrands
                  ? const LinearProgressIndicator()
                  : Autocomplete<Map<String, dynamic>>(
                      initialValue: _brandId != null
                          ? TextEditingValue(text: _brands.firstWhere(
                              (b) => b['id'] == _brandId,
                              orElse: () => {'name': ''})['name'] as String? ?? '')
                          : TextEditingValue.empty,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _brands.cast<Map<String, dynamic>>();
                        }
                        return _brands.cast<Map<String, dynamic>>().where((b) =>
                            (b['name'] as String).toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      displayStringForOption: (b) => b['name'] as String,
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Brand',
                            prefixIcon: Icon(Icons.branding_watermark),
                            hintText: 'Search brand...',
                          ),
                        );
                      },
                      onSelected: (b) => setState(() => _brandId = b['id'] as int),
                    ),
              const SizedBox(height: 16),

              // Category - Searchable
              _loadingCategories
                  ? const LinearProgressIndicator()
                  : Autocomplete<Map<String, dynamic>>(
                      initialValue: _categoryId != null
                          ? TextEditingValue(text: _categories.firstWhere(
                              (c) => c['id'] == _categoryId,
                              orElse: () => {'name': ''})['name'] as String? ?? '')
                          : TextEditingValue.empty,
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _categories.cast<Map<String, dynamic>>();
                        }
                        return _categories.cast<Map<String, dynamic>>().where((c) =>
                            (c['name'] as String).toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      displayStringForOption: (c) => c['name'] as String,
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category),
                            hintText: 'Search category...',
                          ),
                        );
                      },
                      onSelected: (c) => setState(() => _categoryId = c['id'] as int),
                    ),
              const SizedBox(height: 16),

              // Inquiry Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: const Text('Inquiry Date'),
                subtitle: Text(_formatDate(_inquiryDate)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _pickDate('inquiry'),
                    ),
                    if (_inquiryDate != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.red[300]),
                        onPressed: () =>
                            setState(() => _inquiryDate = null),
                      ),
                  ],
                ),
              ),

              // Price
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),

              // Status
              const Text('Status',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'pending',
                        label: Text('Pending', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.hourglass_empty, size: 18)),
                    ButtonSegment(
                        value: 'close',
                        label: Text('Close', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.check_circle_outline, size: 18)),
                  ],
                  selected: {_status},
                  onSelectionChanged: (v) =>
                      setState(() => _status = v.first),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Type
              const Text('Payment Type',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'cash',
                        label: Text('Cash', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.money, size: 18)),
                    ButtonSegment(
                        value: 'finance',
                        label: Text('Finance', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.account_balance, size: 18)),
                    ButtonSegment(
                        value: 'card',
                        label: Text('Card', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.credit_card, size: 18)),
                  ],
                  selected: {_paymentType},
                  onSelectionChanged: (v) =>
                      setState(() => _paymentType = v.first),
                ),
              ),
              const SizedBox(height: 20),

              // Date of Birth
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Date of Birth'),
                subtitle: Text(_formatDate(_dob)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _pickDate('dob'),
                    ),
                    if (_dob != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.red[300]),
                        onPressed: () => setState(() => _dob = null),
                      ),
                  ],
                ),
              ),

              // Anniversary Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite_border),
                title: const Text('Anniversary Date'),
                subtitle: Text(_formatDate(_anniversary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _pickDate('anniversary'),
                    ),
                    if (_anniversary != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.red[300]),
                        onPressed: () => setState(() => _anniversary = null),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),

              // Save button
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isEdit ? 'UPDATE INQUIRY' : 'SAVE INQUIRY',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
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
