import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/item_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';
import '../l10n/l10n.dart';
import '../services/config_service.dart';

/// Rút tiền từ ví về tài khoản ngân hàng đã lưu.
class WithdrawScreen extends StatefulWidget {
  final WalletSummary wallet;
  const WithdrawScreen({super.key, required this.wallet});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseMoney(_amount.text)!;
    final w = widget.wallet;
    final ok = await confirmDialog(
      context,
      title: tr('Rút {0}?', [formatVnd(amount)]),
      message: tr('Tiền sẽ chuyển về {0} {1} ({2}). Số tiền này bị khóa trong ví cho tới khi Admin chuyển khoản xong.', [w.bankName, w.maskedAccountNumber, w.bankAccountName]),
      confirmText: tr('Rút tiền'),
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await WalletService().createWithdraw(amount);
      if (!mounted) return;
      showSnack(context, tr('Đã gửi yêu cầu rút tiền. Admin sẽ chuyển khoản sớm.'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Rút tiền'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InfoRow(tr('Số dư khả dụng'), formatVnd(w.availableBalance), bold: true),
                    InfoRow(tr('Rút về'), '${w.bankName} ${w.maskedAccountNumber}'),
                    InfoRow(tr('Chủ tài khoản'), w.bankAccountName ?? ''),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: tr('Số tiền muốn rút'),
                suffixText: tr('đ'),
                suffixIcon: TextButton(
                  onPressed: () => setState(() => _amount.text = moneyText(w.availableBalance)),
                  child: Text(tr('Tất cả')),
                ),
              ),
              validator: (v) {
                final n = parseMoney(v);
                if (n == null) return tr('Nhập số tiền');
                if (n < AppConfig.minWalletAmount || n > AppConfig.maxWalletAmount) return tr('Từ {0} đến {1}', [formatVnd(AppConfig.minWalletAmount), formatVnd(AppConfig.maxWalletAmount)]);
                if (n > w.availableBalance) return tr('Vượt quá số dư khả dụng');
                return null;
              },
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _submit, label: tr('Gửi yêu cầu rút')),
          ],
        ),
      ),
    );
  }
}

/// Nhập / sửa tài khoản ngân hàng nhận tiền khi rút.
class BankInfoScreen extends StatefulWidget {
  /// true: lưu xong mở luôn màn hình rút tiền.
  final bool thenWithdraw;
  const BankInfoScreen({super.key, this.thenWithdraw = false});

  @override
  State<BankInfoScreen> createState() => _BankInfoScreenState();
}

class _BankInfoScreenState extends State<BankInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _number = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;

  static const _popularBanks = [
    'Vietcombank', 'VietinBank', 'BIDV', 'Agribank', 'Techcombank',
    'MB Bank', 'ACB', 'VPBank', 'TPBank', 'Sacombank',
  ];

  @override
  void dispose() {
    for (final c in [_bank, _number, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await WalletService().updateBankInfo(
        bankName: _bank.text.trim(),
        accountNumber: _number.text.trim(),
        accountName: _name.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, tr('Đã lưu tài khoản ngân hàng'));
      if (widget.thenWithdraw) {
        final wallet = await WalletService().getSummary();
        if (!mounted) return;
        Navigator.of(context).pushReplacement<bool, bool>(
          MaterialPageRoute(builder: (_) => WithdrawScreen(wallet: wallet)),
          result: true,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tài khoản ngân hàng'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NoticeBox(tr('Tiền rút sẽ được chuyển vào tài khoản này. Họ tên chủ tài khoản phải đúng như trên thẻ.')),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bank,
              decoration: InputDecoration(
                labelText: tr('Ngân hàng'),
                hintText: tr('Ví dụ: Vietcombank'),
                suffixIcon: PopupMenuButton<String>(
                  tooltip: tr('Chọn ngân hàng'),
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (v) => setState(() => _bank.text = v),
                  itemBuilder: (_) => [for (final b in _popularBanks) PopupMenuItem(value: b, child: Text(b))],
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr('Vui lòng nhập tên ngân hàng') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: tr('Số tài khoản')),
              validator: (v) =>
                  RegExp(r'^\d{6,20}$').hasMatch(v ?? '') ? null : tr('Số tài khoản gồm 6–20 chữ số'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: tr('Họ tên chủ tài khoản'), hintText: 'NGUYEN VAN A'),
              validator: (v) => (v == null || v.trim().isEmpty) ? tr('Vui lòng nhập họ tên chủ tài khoản') : null,
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _save, label: tr('Lưu')),
          ],
        ),
      ),
    );
  }
}
