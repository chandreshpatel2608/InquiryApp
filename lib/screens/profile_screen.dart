import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _whatsApp = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  String _mobile = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _businessName.dispose();
    _phone.dispose();
    _whatsApp.dispose();
    _address.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await ApiService.getProfile(widget.userId);
    if (!mounted) return;
    if (data != null) {
      _fullName.text = (data['fullName'] ?? '').toString();
      _email.text = (data['email'] ?? '').toString();
      _businessName.text = (data['businessName'] ?? '').toString();
      _phone.text = (data['phone'] ?? '').toString();
      _whatsApp.text = (data['whatsAppNumber'] ?? '').toString();
      _address.text = (data['address'] ?? '').toString();
      _website.text = (data['website'] ?? '').toString();
      _mobile = (data['mobile'] ?? '').toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await ApiService.updateProfile({
      'userId': widget.userId,
      'fullName': _fullName.text.trim(),
      'email': _email.text.trim(),
      'businessName': _businessName.text.trim(),
      'phone': _phone.text.trim(),
      'whatsAppNumber': _whatsApp.text.trim(),
      'address': _address.text.trim(),
      'website': _website.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? 'Profile updated!' : (result['error'] ?? 'Failed to update')),
      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_mobile.isNotEmpty)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(70),
                      child: ListTile(
                        leading: const Icon(Icons.phone_android),
                        title: const Text('Login Mobile'),
                        subtitle: Text(_mobile),
                        trailing: const Icon(Icons.lock, size: 18),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _field(_fullName, 'Full Name *', required: true),
                  _field(_email, 'Email', keyboard: TextInputType.emailAddress),
                  _field(_businessName, 'Business Name'),
                  _field(_phone, 'Phone', keyboard: TextInputType.phone),
                  _field(_whatsApp, 'WhatsApp Number', keyboard: TextInputType.phone),
                  _field(_website, 'Website'),
                  _field(_address, 'Address', maxLines: 2),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? 'This field is required' : null
            : null,
      ),
    );
  }
}
