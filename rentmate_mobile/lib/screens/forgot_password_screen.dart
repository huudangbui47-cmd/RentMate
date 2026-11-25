import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import '../l10n/l10n.dart';

/// Quên mật khẩu: bước 1 nhập email nhận mã 6 số, bước 2 nhập mã + mật khẩu mới.
/// Mẫu: "Forgot Password" -> "Verify your Email" (ô nhập mã) -> "Create New Password" -> "Success!".
/// Bước 0 nhập email nhận mã, bước 1 nhập mã 6 số, bước 2 đặt mật khẩu mới (gửi mã + mật khẩu lên server),
/// bước 3 báo thành công rồi quay về đăng nhập với email đã điền sẵn.
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
  int _step = 0;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_step == 0 && !_emailForm.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final message = await AuthService().forgotPassword(_email.text.trim());
      if (!mounted) return;
      showSnack(context, message);
      _code.clear();
      setState(() => _step = 1);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _checkCode() {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      showSnack(context, tr('Mã gồm 6 chữ số'), error: true);
      return;
    }
    setState(() => _step = 2);
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
      setState(() => _step = 3);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_step == 0 || _step == 3) {
      Navigator.of(context).pop(_step == 3 ? _email.text.trim() : null);
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: RcAppBar(
          title: Text(tr('Quên mật khẩu')),
          automaticallyImplyLeading: false,
          leading: _step == 3
              ? null
              : IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 26), onPressed: _back),
        ),
        body: SafeArea(
          top: false,
          child: switch (_step) {
            0 => _emailStep(),
            1 => _codeStep(),
            2 => _passwordStep(),
            _ => _doneStep(),
          },
        ),
      ),
    );
  }

  Widget _layout({required List<Widget> children, required Widget button}) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
            // Khối trắng bo tròn như các tờ của mẫu
            child: RcCard(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
        BottomActionBar(
          child: SizedBox(width: double.infinity, child: button),
        ),
      ],
    );
  }

  Widget _emailStep() {
    return _layout(
      children: [
        PageHeading(
          tr('Quên mật khẩu'),
          subtitle: tr('Nhập email đã đăng ký, RentMate sẽ gửi mã xác nhận gồm 6 chữ số.'),
        ),
        const SizedBox(height: 32),
        Form(
          key: _emailForm,
          child: OutlineBox(
            selected: true,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const IconCircle(Icons.mail_outline_rounded, size: 44),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    onFieldSubmitted: (_) => _sendCode(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: tr('Qua email'),
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? tr('Email không hợp lệ') : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      button: BusyButton(busy: _busy, onPressed: _sendCode, label: tr('Gửi mã xác nhận')),
    );
  }

  Widget _codeStep() {
    return _layout(
      children: [
        PageHeading(
          tr('Xác nhận email'),
          subtitle: tr('Nhập mã 6 số vừa gửi tới {0} (có hiệu lực khoảng 10 phút).', [_email.text.trim()]),
        ),
        const SizedBox(height: 40),
        CodeInput(controller: _code, length: 6, onCompleted: _checkCode),
        const SizedBox(height: 32),
        Center(child: Text(tr('Không nhận được mã?'))),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: _busy ? null : _sendCode,
            child: Text(tr('Gửi lại mã'), style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ),
      ],
      button: FilledButton(onPressed: _checkCode, child: Text(tr('Xác nhận'))),
    );
  }

  Widget _passwordStep() {
    return _layout(
      children: [
        PageHeading(tr('Tạo mật khẩu mới'), subtitle: tr('Nhập mật khẩu mới cho tài khoản của bạn')),
        const SizedBox(height: 32),
        Form(
          key: _resetForm,
          child: Column(
            children: [
              LabeledField(
                label: tr('Mật khẩu mới'),
                child: PasswordField(
                  controller: _password,
                  hint: tr('Mật khẩu mới'),
                  action: TextInputAction.next,
                  helper: tr('Ít nhất 6 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt'),
                  validator: passwordError,
                ),
              ),
              const SizedBox(height: 20),
              LabeledField(
                label: tr('Nhập lại mật khẩu mới'),
                child: PasswordField(
                  controller: _confirm,
                  hint: tr('Nhập lại mật khẩu mới'),
                  onSubmitted: (_) => _reset(),
                  validator: (v) => v != _password.text ? tr('Mật khẩu nhập lại không khớp') : null,
                ),
              ),
            ],
          ),
        ),
      ],
      button: BusyButton(busy: _busy, onPressed: _reset, label: tr('Đặt lại mật khẩu')),
    );
  }

  Widget _doneStep() {
    return _layout(
      children: [
        const SizedBox(height: 20),
        const Center(child: RingIcon(Icons.verified_user_rounded, size: 150)),
        const SizedBox(height: 28),
        Text(tr('Thành công!'), textAlign: TextAlign.center, style: kText(22, FontWeight.w400)),
        const SizedBox(height: 12),
        Text(
          tr('Mật khẩu đã được đổi. Hãy đăng nhập lại bằng mật khẩu mới.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.45),
        ),
      ],
      button: FilledButton(onPressed: _back, child: Text(tr('Tiếp tục'))),
    );
  }
}

/// Ô nhập mã kiểu mẫu (Verify your Email): mỗi chữ số một ô vuông viền xám, ô đang nhập viền màu chính.
class CodeInput extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final VoidCallback? onCompleted;
  const CodeInput({super.key, required this.controller, this.length = 6, this.onCompleted});

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    if (widget.controller.text.length == widget.length) widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          // Ô nhập thật nằm ẩn phía sau, các ô vuông chỉ để hiển thị
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < widget.length; i++)
                Container(
                  width: 46,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _focus.hasFocus && i == text.length.clamp(0, widget.length - 1)
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    i < text.length ? text[i] : '',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
