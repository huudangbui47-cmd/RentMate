import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import 'forgot_password_screen.dart';
import 'main_shell.dart';
import 'register_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/language_picker.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showSnack(context, tr('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại')),
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
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: _email.text.trim())));
    if (email != null) {
      _email.text = email;
      _password.clear();
    }
  }

  // Mẫu "Login": nút đổi ngôn ngữ góc phải, tiêu đề lớn, nhãn đậm trên ô nhập, "Quên mật khẩu ?" bên phải,
  // nút Đăng nhập, dòng "Chưa có tài khoản ? Đăng ký" ở dưới.
  @override
  Widget build(BuildContext context) {
    return RcAuthLayout(
      title: tr('Chào mừng trở lại!'),
      subtitle: tr('Đăng nhập bằng email và mật khẩu để tiếp tục thuê và cho thuê đồ'),
      trailing: FlagToggleButton(rebuild: () => const LoginScreen()),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'email@example.com'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return tr('Vui lòng nhập email');
                  if (!v.contains('@')) return tr('Email không hợp lệ');
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: tr('Mật khẩu'),
              child: PasswordField(
                controller: _password,
                hint: tr('Mật khẩu'),
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.isEmpty) ? tr('Vui lòng nhập mật khẩu') : null,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgot,
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                child: Text(
                  tr('Quên mật khẩu?'),
                  style: kText(14, FontWeight.w400, decoration: TextDecoration.underline),
                ),
              ),
            ),
            const SizedBox(height: 6),
            BusyButton(busy: _loading, onPressed: _submit, label: tr('Đăng nhập')),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tr('Chưa có tài khoản?'), style: kText(14, FontWeight.w300, color: AppColors.muted)),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                  child: Text(tr('Đăng ký ngay'), style: kText(14, FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(tr('Hoặc'), style: const TextStyle(color: AppColors.muted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell(guest: true))),
              child: Text(tr('Xem trước với tư cách khách')),
            ),
          ],
        ),
      ),
    );
  }
}
