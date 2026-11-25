import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/item_service.dart';
import '../services/wallet_service.dart';
import '../services/payment_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import 'vnpay_screen.dart';
import '../l10n/l10n.dart';
import '../services/config_service.dart';

/// Bước 1: nhập số tiền muốn nạp.
class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _busy = false;
  bool _vnPay = false; // VNPay đã cấu hình trên Api chưa
  bool _chooseVnPay = true; // khách chọn VNPay hay chuyển khoản (chỉ có tác dụng khi VNPay bật)

  @override
  void initState() {
    super.initState();
    PaymentService().isVnPayEnabled().then((on) {
      if (mounted) {
        setState(() {
          _vnPay = on;
        });
      }
    });
  }

  // Nạp qua VNPay: thanh toán xong tiền vào ví ngay, không cần admin duyệt
  Future<void> _submitVnPay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final payment = await PaymentService().createVnPay(amount: parseMoney(_amount.text)!);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => VnPayScreen(paymentUrl: payment.paymentUrl)));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _quick = [100000, 200000, 500000, 1000000, 2000000];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final deposit = await WalletService().createDeposit(parseMoney(_amount.text)!);
      if (!mounted) return;
      // Thay màn hình nhập số tiền bằng màn hình hướng dẫn chuyển khoản;
      // result: true để màn hình Ví tải lại lịch sử (có yêu cầu nạp mới)
      Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute(builder: (_) => DepositInfoScreen(deposit: deposit)),
        result: true,
      );
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Mẫu "Payments": ô số tiền, chọn nhanh, chọn cách nạp (dòng icon tròn + nút chọn), nút chính ở đáy
  @override
  Widget build(BuildContext context) {
    final useVnPay = _vnPay && _chooseVnPay;
    final amount = parseMoney(_amount.text);
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Nạp tiền vào ví'))),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  RcCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabeledField(
                          label: tr('Số tiền muốn nạp'),
                          child: TextFormField(
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [MoneyInputFormatter()],
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(hintText: '0', suffixText: tr('đ')),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = parseMoney(v);
                              if (n == null) return tr('Nhập số tiền');
                              if (n < AppConfig.minWalletAmount || n > AppConfig.maxWalletAmount) {
                                return tr('Từ {0} đến {1}', [
                                  formatVnd(AppConfig.minWalletAmount),
                                  formatVnd(AppConfig.maxWalletAmount),
                                ]);
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final v in _quick)
                              ChoiceChip(
                                label: Text(formatVnd(v)),
                                selected: amount == v,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _amount.text = moneyText(v)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        SectionTitle(tr('Cách nạp')),
                        const SizedBox(height: 8),
                        _method(
                          true,
                          Icons.bolt_rounded,
                          tr('Nạp qua VNPay'),
                          tr('Thẻ ATM / QR ngân hàng, vào ví ngay'),
                          enabled: _vnPay,
                        ),
                        _method(
                          false,
                          Icons.account_balance_outlined,
                          tr('Chuyển khoản thủ công'),
                          tr('Admin cộng tiền sau khi kiểm tra'),
                          enabled: true,
                        ),
                        const Divider(height: 16),
                        const SizedBox(height: 8),
                        useVnPay
                            ? NoticeBox(
                                tr('Nạp qua VNPay (thẻ ATM / QR ngân hàng): tiền vào ví ngay sau khi thanh toán.'),
                                icon: Icons.bolt,
                                color: AppColors.success,
                              )
                            : NoticeBox(
                                tr(
                                  'Chuyển khoản thủ công: chuyển tới tài khoản RentMate với đúng số tiền và nội dung là mã nạp. Admin kiểm tra sao kê rồi cộng tiền vào ví (thường trong vài giờ).',
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: SizedBox(
                width: double.infinity,
                child: BusyButton(
                  busy: _busy,
                  onPressed: useVnPay ? _submitVnPay : _submit,
                  label: useVnPay ? tr('Nạp qua VNPay') : tr('Tạo mã chuyển khoản'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _method(bool vnPay, IconData icon, String title, String subtitle, {required bool enabled}) {
    final selected = (_vnPay && _chooseVnPay) == vnPay;
    return InkWell(
      onTap: !enabled || _busy
          ? null
          : () => setState(() {
              _chooseVnPay = vnPay;
            }),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconCircle(icon, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.border,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bước 2: hướng dẫn chuyển khoản (mã QR, số tài khoản, nội dung).
/// Mở từ bước 1 (có sẵn deposit) hoặc từ lịch sử ví (chỉ có depositId).
class DepositInfoScreen extends StatefulWidget {
  final DepositRequest? deposit;
  final int? depositId;
  const DepositInfoScreen({super.key, this.deposit, this.depositId});

  @override
  State<DepositInfoScreen> createState() => _DepositInfoScreenState();
}

class _DepositInfoScreenState extends State<DepositInfoScreen> {
  late Future<DepositRequest> _future = widget.deposit != null
      ? Future.value(widget.deposit!)
      : WalletService().getDeposit(widget.depositId!);

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    showSnack(context, tr('Đã chép {0}', [label]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Chuyển khoản để nạp tiền'))),
      body: FutureBuilder<DepositRequest>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(
              message: errorText(snap.error!),
              onRetry: () => setState(() {
                _future = WalletService().getDeposit(widget.depositId!);
              }),
            );
          }
          return _content(snap.data!);
        },
      ),
    );
  }

  Widget _content(DepositRequest d) {
    final hasReceiver = (d.receiverAccountNumber ?? '').isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            children: [
              RcCard(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (d.qrImageUrl != null) ...[
                      OutlineBox(
                        child: Column(
                          children: [
                            Text(tr('Quét mã bằng app ngân hàng'), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                d.qrImageUrl!,
                                height: 260,
                                errorBuilder: (_, _, _) => Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(tr('Không tải được mã QR, hãy chuyển khoản theo thông tin bên dưới.')),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    SectionTitle(tr('Thông tin chuyển khoản')),
                    const SizedBox(height: 4),
                    _copyTile(tr('Số tiền'), formatVnd(d.amount), d.amount.round().toString(), tr('số tiền')),
                    _copyTile(tr('Nội dung chuyển khoản'), d.code, d.code, tr('mã nạp'), highlight: true),
                    if (hasReceiver) ...[
                      _copyTile(
                        tr('Số tài khoản'),
                        d.receiverAccountNumber!,
                        d.receiverAccountNumber!,
                        tr('số tài khoản'),
                      ),
                      _plainTile(tr('Ngân hàng'), d.receiverBankName ?? ''),
                      _plainTile(tr('Chủ tài khoản'), d.receiverAccountName ?? ''),
                    ],
                    const SizedBox(height: 16),
                    if (!hasReceiver) ...[
                      NoticeBox(
                        tr(
                          'RentMate chưa cấu hình tài khoản nhận tiền (mục "Wallet" trong appsettings của Api). Khi chạy thử, Admin có thể duyệt luôn yêu cầu này trên trang quản trị.',
                        ),
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 8),
                    ],
                    NoticeBox(
                      tr(
                        'Ghi đúng nội dung {0} và đúng số tiền {1}. Tiền sẽ vào ví sau khi Admin xác nhận. Bạn xem lại hướng dẫn này trong lịch sử ví.',
                        [d.code, formatVnd(d.amount)],
                      ),
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        BottomActionBar(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('Tôi đã chuyển khoản')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _plainTile(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _copyTile(String label, String value, String copyText, String copyLabel, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: highlight ? 1.5 : null,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: tr('Chép'),
            onPressed: () => _copy(copyText, copyLabel),
          ),
        ],
      ),
    );
  }
}
