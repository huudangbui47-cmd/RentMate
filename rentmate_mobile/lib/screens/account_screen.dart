import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Profile> _future = AccountService().getProfile();
  bool _uploadingAvatar = false;

  Future<void> _reload() async {
    setState(() { _future = AccountService().getProfile(); });
    await _future;
  }

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      await AccountService().uploadAvatar(file);
      if (!mounted) return;
      showSnack(context, 'Đã đổi ảnh đại diện');
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    if (!await confirmDialog(context, title: 'Đăng xuất?', message: 'Bạn sẽ cần đăng nhập lại để dùng RentMate.', confirmText: 'Đăng xuất')) {
      return;
    }
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: FutureBuilder<Profile>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final p = snap.data!;
          final scheme = Theme.of(context).colorScheme;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _uploadingAvatar ? null : _changeAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: scheme.primary,
                                backgroundImage: p.avatarUrl == null ? null : NetworkImage(p.avatarUrl!),
                                child: _uploadingAvatar
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : p.avatarUrl != null
                                        ? null
                                        : Text(
                                            p.fullName.isEmpty ? '?' : p.fullName.trim().split(' ').last.characters.first.toUpperCase(),
                                            style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: scheme.outlineVariant),
                                  ),
                                  child: Icon(Icons.camera_alt_outlined, size: 14, color: scheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(p.email, style: TextStyle(color: scheme.onSurfaceVariant)),
                              Text('Thành viên từ ${fmtDate(p.createdAt)}',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Thông tin cá nhân'),
                        subtitle: Text([p.phoneNumber, if (p.address.isNotEmpty) p.address].join(' · ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => EditProfileScreen(profile: p)),
                          );
                          if (changed == true) await _reload();
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Đổi mật khẩu'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.logout, color: scheme.error),
                    title: Text('Đăng xuất', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
                    onTap: _logout,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text('RentMate · Thuê đồ dễ dàng', style: TextStyle(color: scheme.outline, fontSize: 12)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Profile profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phoneNumber);
  late final _address = TextEditingController(text: widget.profile.address);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AccountService().updateProfile(
        fullName: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        address: _address.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, 'Đã lưu thông tin');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: widget.profile.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                helperText: 'Email dùng để đăng nhập, muốn đổi hãy liên hệ RentMate.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
              validator: phoneError,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ (không bắt buộc)',
                prefixIcon: Icon(Icons.location_on_outlined),
                hintText: 'Nơi thuận tiện để giao nhận đồ',
              ),
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _save, label: 'Lưu thay đổi'),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    for (final c in [_current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AccountService().changePassword(_current.text, _new.text);
      if (!mounted) return;
      showSnack(context, 'Đã đổi mật khẩu. Các máy khác đang đăng nhập sẽ bị đăng xuất.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _hide = !_hide),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _current,
              obscureText: _hide,
              decoration: _deco('Mật khẩu hiện tại'),
              validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _new,
              obscureText: _hide,
              decoration: _deco('Mật khẩu mới').copyWith(
                helperText: 'Ít nhất 6 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt',
              ),
              validator: (v) {
                if (v == _current.text) return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                return passwordError(v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: _hide,
              decoration: _deco('Nhập lại mật khẩu mới'),
              validator: (v) => v != _new.text ? 'Mật khẩu nhập lại không khớp' : null,
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _save, label: 'Đổi mật khẩu'),
          ],
        ),
      ),
    );
  }
}
