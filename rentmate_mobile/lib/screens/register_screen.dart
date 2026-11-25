import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import '../l10n/l10n.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_fullName, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.register(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        phoneNumber: _phone.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      showSnack(context, tr('Đăng ký thành công, vui lòng đăng nhập.'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Mẫu "Register Account": tiêu đề lớn, nhãn đậm trên ô nhập, nút Đăng ký, dòng "Đã có tài khoản ? Đăng nhập".
  @override
  Widget build(BuildContext context) {
    return RcAuthLayout(
      title: tr('Tạo tài khoản'),
      subtitle: tr('Điền thông tin bên dưới để bắt đầu thuê và cho thuê đồ'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: tr('Họ tên'),
              child: TextFormField(
                controller: _fullName,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: tr('Nguyễn Văn A')),
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Vui lòng nhập họ tên') : null,
              ),
            ),
            const SizedBox(height: 14),
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
              label: tr('Số điện thoại'),
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: '09xxxxxxxx'),
                validator: phoneError,
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: tr('Mật khẩu'),
              child: PasswordField(
                controller: _password,
                hint: tr('Mật khẩu'),
                action: TextInputAction.next,
                helper: tr('Ít nhất 6 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt'),
                validator: passwordError,
              ),
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: tr('Nhập lại mật khẩu'),
              child: PasswordField(
                controller: _confirm,
                hint: tr('Nhập lại mật khẩu'),
                onSubmitted: (_) => _submit(),
                validator: (v) => v != _password.text ? tr('Mật khẩu nhập lại không khớp') : null,
              ),
            ),
            const SizedBox(height: 22),
            BusyButton(busy: _loading, onPressed: _submit, label: tr('Đăng ký')),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tr('Đã có tài khoản?'), style: kText(14, FontWeight.w300, color: AppColors.muted)),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                  child: Text(tr('Đăng nhập'), style: kText(14, FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
