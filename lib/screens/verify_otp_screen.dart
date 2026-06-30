import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key});
  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final List<TextEditingController> _ctrl =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focus = List.generate(6, (_) => FocusNode());

  bool    _loading    = false;
  bool    _resending  = false;
  int     _countdown  = 60;
  Timer?  _timer;
  String  _email      = '';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrl)  c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _otp => _ctrl.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focus[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focus[index - 1].requestFocus();
    }
    // Auto-verify when all 6 digits entered
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the complete 6-digit OTP')),
      );
      return;
    }
    setState(() => _loading = true);

    final res = await Api.post('/auth/verify_otp.php', {
      'email': _email,
      'otp':   _otp,
    });

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      Navigator.pushNamed(
        context,
        '/reset-password',
        arguments: {'email': _email, 'otp': _otp},
      );
    } else {
      // Clear boxes on failure
      for (final c in _ctrl) c.clear();
      _focus[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Invalid OTP')),
      );
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    await Api.post('/auth/forgot_password.php', {'email': _email});
    if (!mounted) return;
    setState(() => _resending = false);
    for (final c in _ctrl) c.clear();
    _focus[0].requestFocus();
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New OTP sent to your email')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.mark_email_read_outlined,
                  size: 72, color: Color(0xFF00CEC9)),
              const SizedBox(height: 24),
              const Text('Check your email',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit OTP to\n$_email',
                style: const TextStyle(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 6 OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _ctrl[i],
                  focusNode:  _focus[i],
                  onChanged:  (v) => _onDigitChanged(i, v),
                )),
              ),

              const SizedBox(height: 40),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _verify,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Verify OTP'),
                ),
              ),

              const SizedBox(height: 16),

              // Resend
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Didn't receive it? ",
                    style: TextStyle(color: Colors.white60)),
                _resending
                    ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : _countdown > 0
                    ? Text('Resend in ${_countdown}s',
                    style: const TextStyle(color: Colors.white38))
                    : TextButton(
                  onPressed: _resend,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero),
                  child: const Text('Resend OTP'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final ValueChanged<String>  onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 62,
      child: TextField(
        controller:   controller,
        focusNode:    focusNode,
        onChanged:    onChanged,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
        maxLength:    1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF6C5CE7), width: 2),
          ),
        ),
      ),
    );
  }
}