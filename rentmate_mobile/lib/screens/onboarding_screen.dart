import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Đã xem phần giới thiệu thì lần sau mở app vào thẳng màn đăng nhập.
const onboardingDoneKey = 'onboarding_done';

class _Page {
  final String before, bold, after, subtitle;
  final IconData front, back;
  const _Page(this.before, this.bold, this.after, this.subtitle, this.front, this.back);
}

/// 3 màn giới thiệu (mẫu "On Boarding 1-3"): 2 khối bo tròn chồng nhau, tiêu đề có phần in đậm,
/// chấm trang, nút Tiếp. Mẫu dùng ảnh; theo lựa chọn B, khối bo tròn chứa icon lớn.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  List<_Page> get _pages => [
    _Page(
      tr('Thuê '),
      tr('mọi thứ bạn cần'),
      tr(' ngay gần nhà'),
      tr('Máy ảnh, lều trại, laptop... thuê theo ngày với giá hợp lý.'),
      Icons.photo_camera_rounded,
      Icons.forest_rounded,
    ),
    _Page(
      tr('Kiếm tiền từ '),
      tr('đồ để không'),
      '',
      tr('Đăng đồ cho thuê trong vài phút, tiền về ví sau mỗi đơn.'),
      Icons.inventory_2_rounded,
      Icons.account_balance_wallet_rounded,
    ),
    _Page(
      tr('Thuê '),
      tr('an tâm'),
      tr(' với biên bản và tiền cọc'),
      tr('Ảnh lúc giao, lúc nhận và tiền cọc giữ hộ giúp cả hai bên yên tâm.'),
      Icons.verified_user_rounded,
      Icons.receipt_long_rounded,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingDoneKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final last = _index == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: pagePadding),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: last
                      ? null
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.ink,
                            textStyle: const TextStyle(fontSize: 14),
                          ),
                          onPressed: _finish,
                          child: Text(tr('Bỏ qua')),
                        ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _PageView(page: pages[i], flip: i == 1),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 28 : 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.primary : const Color(0xFFD5D7DB),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: last
                      ? _finish
                      : () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Text(last ? tr('Bắt đầu') : tr('Tiếp')),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _Page page;
  final bool flip;
  const _PageView({required this.page, required this.flip});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SizedBox(
              width: 240,
              height: 300,
              child: Stack(
                children: [
                  // Khối sau: xám đậm, lệch xuống dưới
                  Positioned(
                    left: flip ? 0 : null,
                    right: flip ? null : 0,
                    bottom: 0,
                    child: _Capsule(icon: page.back, dark: true),
                  ),
                  // Khối trước: trắng có bóng, lệch lên trên
                  Positioned(
                    left: flip ? null : 0,
                    right: flip ? 0 : null,
                    top: 0,
                    child: _Capsule(icon: page.front, dark: false),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 26, height: 1.3, color: AppColors.ink),
            children: [
              TextSpan(text: page.before),
              TextSpan(
                text: page.bold,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: page.after),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          page.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _Capsule extends StatelessWidget {
  final IconData icon;
  final bool dark;
  const _Capsule({required this.icon, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 230,
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(75),
        boxShadow: dark ? null : const [BoxShadow(color: Color(0x1F000000), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: Icon(icon, size: 64, color: dark ? Colors.white : AppColors.primary),
    );
  }
}
