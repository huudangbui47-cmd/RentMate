import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/item_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';

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
    final amount = num.parse(_amount.text);
    final w = widget.wallet;
    final ok = await confirmDialog(
      context,
      title: 'Rút ${formatVnd(amount)}?',
      message: 'Tiền sẽ chuyển về ${w.bankName} ${w.maskedAccountNumber} (${w.bankAccountName}). '
          'Số tiền này bị khóa trong ví cho tới khi Admin chuyển khoản xong.',
      confirmText: 'Rút tiền',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await WalletService().createWithdraw(amount);
      if (!mounted) return;
      showSnack(context, 'Đã gửi yêu cầu rút tiền. Admin sẽ chuyển khoản sớm.');
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
      appBar: AppBar(title: const Text('Rút tiền')),
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
                    InfoRow('Số dư khả dụng', formatVnd(w.availableBalance), bold: true),
                    InfoRow('Rút về', '${w.bankName} ${w.maskedAccountNumber}'),
                    InfoRow('Chủ tài khoản', w.bankAccountName ?? ''),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Số tiền muốn rút',
                suffixText: 'đ',
                suffixIcon: TextButton(
                  onPressed: () => setState(() => _amount.text = w.availableBalance.round().toString()),
                  child: const Text('Tất cả'),
                ),
              ),
              validator: (v) {
                final n = num.tryParse(v ?? '');
                if (n == null) return 'Nhập số tiền';
                if (n < 10000 || n > 50000000) return 'Từ 10.000 đ đến 50.000.000 đ';
                if (n > w.availableBalance) return 'Vượt quá số dư khả dụng';
                return null;
              },
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _submit, label: 'Gửi yêu cầu rút'),
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
      showSnack(context, 'Đã lưu tài khoản ngân hàng');
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
      appBar: AppBar(title: const Text('Tài khoản ngân hàng')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const NoticeBox('Tiền rút sẽ được chuyển vào tài khoản này. Họ tên chủ tài khoản phải đúng như trên thẻ.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bank,
              decoration: InputDecoration(
                labelText: 'Ngân hàng',
                hintText: 'Ví dụ: Vietcombank',
                suffixIcon: PopupMenuButton<String>(
                  tooltip: 'Chọn ngân hàng',
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (v) => setState(() => _bank.text = v),
                  itemBuilder: (_) => [for (final b in _popularBanks) PopupMenuItem(value: b, child: Text(b))],
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên ngân hàng' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Số tài khoản'),
              validator: (v) =>
                  RegExp(r'^\d{6,20}$').hasMatch(v ?? '') ? null : 'Số tài khoản gồm 6–20 chữ số',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Họ tên chủ tài khoản', hintText: 'NGUYEN VAN A'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên chủ tài khoản' : null,
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _save, label: 'Lưu'),
          ],
        ),
      ),
    );
  }
}
