import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'notifications_screen.dart';
import 'login_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/language_picker.dart';
import 'main_shell.dart';
import 'my_items_screen.dart';
import 'favorites_screen.dart';
import 'item_form_screen.dart';
import 'wallet_screen.dart';
import '../services/notification_service.dart';
import '../widgets/kit.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Profile> _future = AccountService().getProfile();
  bool _uploadingAvatar = false;

  Future<void> _reload() async {
    setState(() {
      _future = AccountService().getProfile();
    });
    await _future;
  }

  Future<void> _avatarMenu(Profile p) async {
    Widget row(BuildContext ctx, IconData icon, String label, String value) => InkWell(
      onTap: () => Navigator.pop(ctx, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: pagePadding, vertical: 10),
        child: Row(
          children: [
            IconCircle(icon, size: 48),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
    final action = await showAppSheet<String>(
      context,
      title: tr('Ảnh đại diện'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.avatarUrl != null) row(ctx, Icons.visibility_outlined, tr('Xem ảnh đại diện'), 'view'),
            row(ctx, Icons.photo_library_outlined, tr('Đổi ảnh đại diện'), 'change'),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'view') showImageViewer(context, p.avatarUrl!);
    if (action == 'change') await _changeAvatar();
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
      showSnack(context, tr('Đã đổi ảnh đại diện'));
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    if (!await confirmDialog(
      context,
      title: tr('Đăng xuất?'),
      message: tr('Bạn sẽ cần đăng nhập lại để dùng RentMate.'),
      confirmText: tr('Đăng xuất'),
    )) {
      return;
    }
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Profile>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return Column(
              children: [
                RcHeroBar(title: tr('Tài khoản')),
                const Expanded(child: LoadingView()),
              ],
            );
          }
          if (snap.hasError) {
            return Column(
              children: [
                RcHeroBar(title: tr('Tài khoản')),
                Expanded(
                  child: ErrorView(message: errorText(snap.error!), onRetry: _reload),
                ),
              ],
            );
          }
          final p = snap.data!;
          // Mẫu "Settings": đầu trang ảnh chỉ có lời chào + ảnh đại diện; khối "Tuỳ chọn", khối "Tài khoản"
          // (dòng nào cũng có mũi tên, Đăng xuất cũng vậy); nhãn "Trợ giúp" nằm ngoài khối.
          return RefreshIndicator(
            onRefresh: _reload,
            edgeOffset: MediaQuery.of(context).padding.top,
            child: ListView(
              padding: EdgeInsets.only(bottom: navPillSpace(context)),
              children: [
                _header(p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RcMenuGroup(
                        label: tr('Tuỳ chọn'),
                        children: [
                          RcMenuItem(
                            icon: Icons.translate_rounded,
                            title: tr('Ngôn ngữ'),
                            trailing: LanguageBadge(code: currentLanguage),
                            onTap: () => showLanguagePicker(
                              context,
                              rebuild: () => const MainShell(initialIndex: MainShell.accountTab),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RcMenuGroup(
                        label: tr('Tài khoản'),
                        children: [
                          RcMenuItem(
                            icon: Icons.person_outline_rounded,
                            title: tr('Thông tin cá nhân'),
                            onTap: () async {
                              final changed = await Navigator.of(
                                context,
                              ).push<bool>(MaterialPageRoute(builder: (_) => EditProfileScreen(profile: p)));
                              if (changed == true) await _reload();
                            },
                          ),
                          RcMenuItem(
                            icon: Icons.event_note_outlined,
                            title: tr('Đơn thuê của tôi'),
                            onTap: () => NotificationCenter.instance.openTab?.call(MainShell.rentalsTab),
                          ),
                          RcMenuItem(
                            icon: Icons.favorite_border_rounded,
                            title: tr('Yêu thích'),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
                          ),
                          RcMenuItem(
                            icon: Icons.add_circle_outline_rounded,
                            title: tr('Đăng đồ cho thuê'),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ItemFormScreen())),
                          ),
                          RcMenuItem(
                            icon: Icons.inventory_2_outlined,
                            title: tr('Đồ cho thuê của tôi'),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyItemsScreen())),
                          ),
                          RcMenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: tr('Ví RentMate'),
                            onTap: () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (_) => const WalletScreen(standalone: true))),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: NotificationCenter.instance.unread,
                            builder: (_, count, _) => RcMenuItem(
                              icon: Icons.notifications_none_rounded,
                              title: tr('Thông báo'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (count > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        count > 99 ? '99+' : '$count',
                                        style: kText(11, FontWeight.w500, color: Colors.white),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, size: 22),
                                ],
                              ),
                              onTap: NotificationsScreen.open,
                            ),
                          ),
                          RcMenuItem(
                            icon: Icons.lock_outline_rounded,
                            title: tr('Đổi mật khẩu'),
                            onTap: () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                          ),
                          RcMenuItem(icon: Icons.logout_rounded, title: tr('Đăng xuất'), onTap: _logout),
                        ],
                      ),
                      // Nhãn nằm ngoài khối như "Help and Settings" của mẫu
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                        child: Text(
                          tr('Trợ giúp và cài đặt'),
                          style: kText(14, FontWeight.w300, color: AppColors.muted),
                        ),
                      ),
                      RcMenuGroup(
                        children: [
                          RcMenuItem(
                            icon: Icons.support_agent_rounded,
                            title: tr('Hỗ trợ'),
                            onTap: () => showSupportSheet(context),
                          ),
                          RcMenuItem(
                            icon: Icons.info_outline_rounded,
                            title: tr('Giới thiệu về {0}', [appName]),
                            onTap: () => showAboutSheet(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Đầu trang như "Settings" của mẫu: một hàng duy nhất, lời chào ở giữa, ảnh đại diện bên phải
  Widget _header(Profile p) {
    return RcHero(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: Text(
                tr('Chào, {0}', [p.fullName]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kText(23, FontWeight.w400, color: Colors.white),
              ),
            ),
            GestureDetector(
              onTap: _uploadingAvatar ? null : () => _avatarMenu(p),
              child: _uploadingAvatar
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : UserAvatar(name: p.fullName, url: p.avatarUrl, radius: 24),
            ),
          ],
        ),
      ),
    );
  }
}

/// Đầu trang của màn con trong Tài khoản (mẫu "My Information"): đầu trang ảnh cao, hàng tiêu đề ở trên,
/// ảnh đại diện lớn nằm giữa phần ảnh (viền kính mờ), huy hiệu máy ảnh ở góc dưới phải.
class ProfileHeroHeader extends StatelessWidget {
  final String title;
  final String name;
  final String? avatarUrl;
  final bool busy;
  final VoidCallback? onAvatar;
  final bool showCamera;
  const ProfileHeroHeader({
    super.key,
    required this.title,
    required this.name,
    this.avatarUrl,
    this.busy = false,
    this.onAvatar,
    this.showCamera = true,
  });

  @override
  Widget build(BuildContext context) {
    const size = 112.0;
    return RcHeroBar(
      title: title,
      extra: 28,
      bottom: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Center(
          child: GestureDetector(
            onTap: busy ? null : onAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), shape: BoxShape.circle),
                  child: busy
                      ? const CircleAvatar(
                          radius: size / 2 - 4,
                          backgroundColor: Colors.white24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : UserAvatar(name: name, url: avatarUrl, radius: size / 2 - 4),
                ),
                if (onAvatar != null && showCamera)
                  const Positioned(
                    right: 0,
                    bottom: 4,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.ink),
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
  late String? _avatarUrl = widget.profile.avatarUrl;
  bool _busy = false;
  bool _uploading = false;
  bool _avatarChanged = false;

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      _uploading = true;
    });
    try {
      await AccountService().uploadAvatar(file);
      final p = await AccountService().getProfile();
      if (!mounted) return;
      setState(() {
        _avatarUrl = p.avatarUrl;
        _avatarChanged = true;
      });
      showSnack(context, tr('Đã đổi ảnh đại diện'));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

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
      showSnack(context, tr('Đã lưu thông tin'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_avatarChanged,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
            children: [
              ProfileHeroHeader(
                title: tr('Thông tin cá nhân'),
                name: widget.profile.fullName,
                avatarUrl: _avatarUrl,
                busy: _uploading,
                onAvatar: _changeAvatar,
              ),
              const SizedBox(height: 12),
              // Như "My Information": mỗi nhóm ô nhập một khối trắng, nhãn xám trên ô dạng viên thuốc
              _card([
                LabeledField(
                  label: tr('Họ tên'),
                  child: TextFormField(
                    controller: _name,
                    decoration: InputDecoration(hintText: tr('Nguyễn Văn A')),
                    validator: (v) => (v == null || v.trim().isEmpty) ? tr('Vui lòng nhập họ tên') : null,
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: tr('Số điện thoại'),
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 8),
                        child: RcFlag('vi', size: 22),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    validator: phoneError,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _card([
                LabeledField(
                  label: tr('Địa chỉ (không bắt buộc)'),
                  child: TextFormField(
                    controller: _address,
                    decoration: InputDecoration(hintText: tr('Nơi thuận tiện để giao nhận đồ')),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Email',
                  child: TextFormField(
                    initialValue: widget.profile.email,
                    enabled: false,
                    decoration: InputDecoration(
                      helperText: tr('Email dùng để đăng nhập, muốn đổi hãy liên hệ RentMate.'),
                      helperMaxLines: 2,
                    ),
                  ),
                ),
              ]),
              // Như mẫu: "Change Password" căn giữa trên nền xám, dưới là nút đen "Save"
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                  child: Text(tr('Đổi mật khẩu'), style: kText(18, FontWeight.w400)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                child: BusyButton(busy: _busy, onPressed: _save, label: tr('Lưu thay đổi')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => RcCard(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
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
      showSnack(context, tr('Đã đổi mật khẩu. Các máy khác đang đăng nhập sẽ bị đăng xuất.'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Đổi mật khẩu'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
          children: [
            // Khối trắng chứa ô nhập dạng viên thuốc như "My Information" của mẫu
            RcCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Tạo mật khẩu mới'), style: kText(19, FontWeight.w400)),
                  const SizedBox(height: 4),
                  Text(tr('Nhập mật khẩu mới cho tài khoản của bạn'), style: kBody12Hint),
                  const SizedBox(height: 18),
                  LabeledField(
                    label: tr('Mật khẩu hiện tại'),
                    child: PasswordField(
                      controller: _current,
                      validator: (v) => (v == null || v.isEmpty) ? tr('Vui lòng nhập mật khẩu hiện tại') : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: tr('Mật khẩu mới'),
                    child: PasswordField(
                      controller: _new,
                      helper: tr('Ít nhất 6 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt'),
                      validator: (v) {
                        if (v == _current.text) return tr('Mật khẩu mới phải khác mật khẩu hiện tại');
                        return passwordError(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  LabeledField(
                    label: tr('Nhập lại mật khẩu mới'),
                    child: PasswordField(
                      controller: _confirm,
                      validator: (v) => v != _new.text ? tr('Mật khẩu nhập lại không khớp') : null,
                    ),
                  ),
                  const SizedBox(height: 22),
                  BusyButton(busy: _busy, onPressed: _save, label: tr('Đổi mật khẩu')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
