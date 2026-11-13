import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/ui.dart';
import 'forgot_password_screen.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  /// true khi bị đưa về đây vì phiên hết hạn (token hết hạn, bị khóa, đổi mật khẩu ở máy khác).
  final bool sessionExpired;
  const LoginScreen({super.key, this.sessionExpired = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showSnack(context, 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại'),
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.handshake_rounded, size: 46, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('RentMate',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Thuê đồ dễ dàng, cho thuê có thu nhập',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                      if (!v.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              final email = await Navigator.of(context).push<String>(
                                MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(email: _email.text.trim())),
                              );
                              if (email != null) {
                                _email.text = email;
                                _password.clear();
                              }
                            },
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BusyButton(busy: _loading, onPressed: _submit, label: 'Đăng nhập'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Chưa có tài khoản?'),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                ),
                        child: const Text('Đăng ký ngay'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Xem trước với tư cách khách'),
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const MainShell(guest: true)),
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
