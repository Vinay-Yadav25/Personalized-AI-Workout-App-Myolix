import 'package:flutter/material.dart';
import '../services/api.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _pwd      = TextEditingController();
  final _confirm  = TextEditingController();
  bool  _loading  = false;
  bool  _obscure  = true;
  String _email   = '';
  String _otp     = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    _email = args?['email'] ?? '';
    _otp   = args?['otp']   ?? '';
  }

  @override
  void dispose() { _pwd.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await Api.post('/auth/reset_password.php', {
      'email':        _email,
      'otp':          _otp,
      'new_password': _pwd.text,
    });

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password reset! Please log in with your new password.')),
      );
      // Clear navigation stack and go to login
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Reset failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('New Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.lock_outline,
                    size: 72, color: Color(0xFF6C5CE7)),
                const SizedBox(height: 24),
                const Text('Create new password',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  'Your new password must be at least 6 characters.',
                  style: TextStyle(color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller:  _pwd,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText:   'New Password',
                    prefixIcon:  const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                  v == null || v.length < 6
                      ? 'Minimum 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller:  _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText:  'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                  v != _pwd.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 16),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _reset,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Reset Password'),
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