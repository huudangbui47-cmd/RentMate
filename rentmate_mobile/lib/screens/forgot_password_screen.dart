import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../widgets/ui.dart';

/// Quên mật khẩu: bước 1 nhập email nhận mã 6 số, bước 2 nhập mã + mật khẩu mới.
class ForgotPasswordScreen extends StatefulWidget {
  final String? email;
  const ForgotPasswordScreen({super.key, this.email});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final message = await AuthService().forgotPassword(_email.text.trim());
      if (!mounted) return;
      showSnack(context, message);
      setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService().resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      showSnack(context, 'Đặt lại mật khẩu thành công. Hãy đăng nhập bằng mật khẩu mới.');
      Navigator.of(context).pop(_email.text.trim());
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _emailForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _codeSent
                      ? 'Mã 6 số đã được gửi tới email của bạn (có hiệu lực khoảng 10 phút).'
                      : 'Nhập email đã đăng ký, RentMate sẽ gửi mã xác nhận gồm 6 chữ số.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
                ),
                const SizedBox(height: 16),
                if (!_codeSent) BusyButton(busy: _busy, onPressed: _sendCode, label: 'Gửi mã xác nhận'),
              ],
            ),
          ),
          if (_codeSent)
            Form(
              key: _resetForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(labelText: 'Mã xác nhận', counterText: ''),
                    validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'Mã gồm 6 chữ số',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText: 'Ít nhất 6 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt',
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: passwordError,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _hide,
                    decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
                  ),
                  const SizedBox(height: 24),
                  BusyButton(busy: _busy, onPressed: _reset, label: 'Đặt lại mật khẩu'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _codeSent = false),
                    child: const Text('Không nhận được mã? Gửi lại'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
