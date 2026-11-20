import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/item_service.dart';
import '../services/wallet_service.dart';
import '../services/payment_service.dart';
import '../widgets/ui.dart';
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

  @override
  void initState() {
    super.initState();
    PaymentService().isVnPayEnabled().then((on) {
      if (mounted) setState(() { _vnPay = on; });
    });
  }

  // Nạp qua VNPay: thanh toán xong tiền vào ví ngay, không cần admin duyệt
  Future<void> _submitVnPay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final payment = await PaymentService().createVnPay(amount: parseMoney(_amount.text)!);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VnPayScreen(paymentUrl: payment.paymentUrl)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Nạp tiền vào ví'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(labelText: tr('Số tiền muốn nạp'), suffixText: tr('đ')),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = parseMoney(v);
                if (n == null) return tr('Nhập số tiền');
                if (n < AppConfig.minWalletAmount || n > AppConfig.maxWalletAmount) return tr('Từ {0} đến {1}', [formatVnd(AppConfig.minWalletAmount), formatVnd(AppConfig.maxWalletAmount)]);
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in _quick)
                  ActionChip(
                    label: Text(formatVnd(v)),
                    onPressed: () => setState(() => _amount.text = moneyText(v)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_vnPay) ...[
              NoticeBox(tr('Nạp qua VNPay (thẻ ATM / QR ngân hàng): tiền vào ví ngay sau khi thanh toán.'),
                  icon: Icons.bolt, color: Color(0xFF16A34A)),
              const SizedBox(height: 12),
              BusyButton(busy: _busy, onPressed: _submitVnPay, label: tr('Nạp qua VNPay'), icon: Icons.account_balance),
              const SizedBox(height: 24),
            ],
            NoticeBox(
              tr('Chuyển khoản thủ công: chuyển tới tài khoản RentMate với đúng số tiền và nội dung là mã nạp. Admin kiểm tra sao kê rồi cộng tiền vào ví (thường trong vài giờ).'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _busy ? null : _submit, child: Text(tr('Tạo mã chuyển khoản'))),
          ],
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
  late Future<DepositRequest> _future =
      widget.deposit != null ? Future.value(widget.deposit!) : WalletService().getDeposit(widget.depositId!);

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    showSnack(context, tr('Đã chép {0}', [label]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Chuyển khoản để nạp tiền'))),
      body: FutureBuilder<DepositRequest>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(
              message: errorText(snap.error!),
              onRetry: () => setState(() { _future = WalletService().getDeposit(widget.depositId!); }),
            );
          }
          return _content(snap.data!);
        },
      ),
    );
  }

  Widget _content(DepositRequest d) {
    final scheme = Theme.of(context).colorScheme;
    final hasReceiver = (d.receiverAccountNumber ?? '').isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (d.qrImageUrl != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(tr('Quét mã bằng app ngân hàng'), style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      d.qrImageUrl!,
                      height: 260,
                      errorBuilder: (_, _, _) => Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(tr('Không tải được mã QR, hãy chuyển khoản theo thông tin bên dưới.')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _copyTile(tr('Số tiền'), formatVnd(d.amount), d.amount.round().toString(), tr('số tiền')),
              const Divider(height: 1),
              _copyTile(tr('Nội dung chuyển khoản'), d.code, d.code, tr('mã nạp'), highlight: true),
              if (hasReceiver) ...[
                const Divider(height: 1),
                _copyTile(tr('Số tài khoản'), d.receiverAccountNumber!, d.receiverAccountNumber!, tr('số tài khoản')),
                const Divider(height: 1),
                ListTile(title: Text(tr('Ngân hàng')), subtitle: Text(d.receiverBankName ?? '')),
                const Divider(height: 1),
                ListTile(title: Text(tr('Chủ tài khoản')), subtitle: Text(d.receiverAccountName ?? '')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!hasReceiver)
          NoticeBox(
            tr('RentMate chưa cấu hình tài khoản nhận tiền (mục "Wallet" trong appsettings của Api). Khi chạy thử, Admin có thể duyệt luôn yêu cầu này trên trang quản trị.'),
            color: Color(0xFFE08A00),
          ),
        const SizedBox(height: 8),
        NoticeBox(
          tr('Ghi đúng nội dung {0} và đúng số tiền {1}. Tiền sẽ vào ví sau khi Admin xác nhận. Bạn xem lại hướng dẫn này trong lịch sử ví.', [d.code, formatVnd(d.amount)]),
          icon: Icons.warning_amber_rounded,
          color: scheme.error,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('Tôi đã chuyển khoản')),
        ),
      ],
    );
  }

  Widget _copyTile(String label, String value, String copyText, String copyLabel, {bool highlight = false}) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: highlight ? 1.5 : null,
          color: highlight ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy_rounded),
        tooltip: tr('Chép'),
        onPressed: () => _copy(copyText, copyLabel),
      ),
    );
  }
}
