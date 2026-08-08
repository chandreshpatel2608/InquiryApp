import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final int userId;
  const ChangePasswordScreen({super.key, required this.userId});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _success;

  Future<void> _changePassword() async {
    final oldPass = _oldPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Please fill all fields.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final result =
          await ApiService.changePassword(widget.userId, oldPass, newPass);
      if (!mounted) return;

      if (result.containsKey('message') && !result.containsKey('error')) {
        setState(() => _success = result['message']);
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() => _error = result['error'] ?? 'Failed to change password.');
      }
    } catch (e) {
      setState(() => _error = 'Connection error. Check network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: appBarTitle('Change Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.password, size: 64, color: primary),
                const SizedBox(height: 16),
                Text('Change Password',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primary)),
                const SizedBox(height: 32),
                TextField(
                  controller: _oldPassCtrl,
                  obscureText: _obscureOld,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureOld
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureOld = !_obscureOld),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  onSubmitted: (_) => _changePassword(),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                if (_success != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_success!,
                        style: const TextStyle(
                            color: Colors.green, fontSize: 13)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _changePassword,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('CHANGE PASSWORD',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
