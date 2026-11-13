import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/item_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';

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
      final deposit = await WalletService().createDeposit(num.parse(_amount.text));
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
      appBar: AppBar(title: const Text('Nạp tiền vào ví')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Số tiền muốn nạp', suffixText: 'đ'),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = num.tryParse(v ?? '');
                if (n == null) return 'Nhập số tiền';
                if (n < 10000 || n > 50000000) return 'Từ 10.000 đ đến 50.000.000 đ';
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
                    onPressed: () => setState(() => _amount.text = '$v'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const NoticeBox(
              'Bước tiếp theo: chuyển khoản tới tài khoản RentMate với đúng số tiền và nội dung là mã nạp. '
              'Admin kiểm tra sao kê rồi cộng tiền vào ví (thường trong vài giờ).',
            ),
            const SizedBox(height: 24),
            BusyButton(busy: _busy, onPressed: _submit, label: 'Tạo yêu cầu nạp'),
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
    showSnack(context, 'Đã chép $label');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chuyển khoản để nạp tiền')),
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
                  const Text('Quét mã bằng app ngân hàng', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      d.qrImageUrl!,
                      height: 260,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Không tải được mã QR, hãy chuyển khoản theo thông tin bên dưới.'),
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
              _copyTile('Số tiền', formatVnd(d.amount), d.amount.round().toString(), 'số tiền'),
              const Divider(height: 1),
              _copyTile('Nội dung chuyển khoản', d.code, d.code, 'mã nạp', highlight: true),
              if (hasReceiver) ...[
                const Divider(height: 1),
                _copyTile('Số tài khoản', d.receiverAccountNumber!, d.receiverAccountNumber!, 'số tài khoản'),
                const Divider(height: 1),
                ListTile(title: const Text('Ngân hàng'), subtitle: Text(d.receiverBankName ?? '')),
                const Divider(height: 1),
                ListTile(title: const Text('Chủ tài khoản'), subtitle: Text(d.receiverAccountName ?? '')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!hasReceiver)
          const NoticeBox(
            'RentMate chưa cấu hình tài khoản nhận tiền (mục "Wallet" trong appsettings của Api). '
            'Khi chạy thử, Admin có thể duyệt luôn yêu cầu này trên trang quản trị.',
            color: Color(0xFFE08A00),
          ),
        const SizedBox(height: 8),
        NoticeBox(
          'Ghi đúng nội dung ${d.code} và đúng số tiền ${formatVnd(d.amount)}. '
          'Tiền sẽ vào ví sau khi Admin xác nhận. Bạn xem lại hướng dẫn này trong lịch sử ví.',
          icon: Icons.warning_amber_rounded,
          color: scheme.error,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Tôi đã chuyển khoản'),
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
        tooltip: 'Chép',
        onPressed: () => _copy(copyText, copyLabel),
      ),
    );
  }
}
