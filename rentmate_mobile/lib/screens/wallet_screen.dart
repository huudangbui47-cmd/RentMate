import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';

class WalletScreen extends StatefulWidget {
  /// true khi mở riêng (từ màn hình khác) thay vì là tab trong thanh điều hướng.
  final bool standalone;
  const WalletScreen({super.key, this.standalone = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<(WalletSummary, List<WalletTransaction>)> _future = _load();

  Future<(WalletSummary, List<WalletTransaction>)> _load() async {
    final service = WalletService();
    final results = await Future.wait([service.getSummary(), service.getHistory()]);
    return (results[0] as WalletSummary, results[1] as List<WalletTransaction>);
  }

  Future<void> _reload() async {
    setState(() { _future = _load(); });
    await _future;
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (changed == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ví RentMate'), automaticallyImplyLeading: widget.standalone),
      body: FutureBuilder<(WalletSummary, List<WalletTransaction>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final (wallet, history) = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _balanceCard(wallet),
                const SizedBox(height: 12),
                _bankCard(wallet),
                const SizedBox(height: 20),
                const Text('Lịch sử giao dịch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const EmptyView(
                    icon: Icons.receipt_outlined,
                    title: 'Chưa có giao dịch',
                    subtitle: 'Nạp tiền để thanh toán đơn thuê nhanh chóng.',
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < history.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          _transactionTile(history[i]),
                        ],
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

  Widget _balanceCard(WalletSummary w) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E9F8E), Color(0xFF0B7A6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Số dư khả dụng', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(formatVnd(w.availableBalance),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          if (w.pendingWithdrawAmount > 0) ...[
            const SizedBox(height: 4),
            Text('Đang chờ rút: ${formatVnd(w.pendingWithdrawAmount)}', style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0B7A6E)),
                  onPressed: () => _open(const DepositScreen()),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Nạp tiền'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () => _open(w.hasBankInfo ? WithdrawScreen(wallet: w) : const BankInfoScreen(thenWithdraw: true)),
                  icon: const Icon(Icons.arrow_circle_up_outlined),
                  label: const Text('Rút tiền'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bankCard(WalletSummary w) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.account_balance_outlined)),
        title: Text(w.hasBankInfo ? '${w.bankName} · ${w.maskedAccountNumber}' : 'Chưa có tài khoản ngân hàng'),
        subtitle: Text(w.hasBankInfo ? w.bankAccountName ?? '' : 'Cần thêm để rút tiền về ngân hàng'),
        trailing: TextButton(
          onPressed: () => _open(const BankInfoScreen()),
          child: Text(w.hasBankInfo ? 'Sửa' : 'Thêm'),
        ),
      ),
    );
  }

  Widget _transactionTile(WalletTransaction t) {
    final scheme = Theme.of(context).colorScheme;
    final incoming = t.amount >= 0;
    final pendingDeposit = t.type == 'Deposit' && t.status == 'Pending';
    final rejected = t.status == 'Rejected';
    return ListTile(
      onTap: pendingDeposit ? () => _open(DepositInfoScreen(depositId: t.id)) : null,
      leading: CircleAvatar(
        backgroundColor: (incoming ? const Color(0xFF16A34A) : scheme.error).withValues(alpha: 0.1),
        child: Icon(
          incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: incoming ? const Color(0xFF16A34A) : scheme.error,
        ),
      ),
      title: Text(walletTypeLabels[t.type] ?? t.type, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([
            fmtDateTime(t.createdAt),
            if (t.code != null) 'Mã ${t.code}',
            if (t.rentalId != null) 'Đơn #${t.rentalId}',
          ].join(' · ')),
          if (t.status != 'Completed')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: StatusBadge(
                pendingDeposit ? 'Chờ duyệt · bấm để xem cách chuyển khoản' : walletStatusLabels[t.status] ?? t.status,
                statusColor(t.status == 'Pending' ? 'Pending' : 'Rejected'),
              ),
            ),
          if (rejected && (t.note ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Lý do: ${t.note}')),
        ],
      ),
      isThreeLine: t.status != 'Completed',
      trailing: Text(
        '${incoming ? '+' : ''}${formatVnd(t.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: rejected ? scheme.outline : (incoming ? const Color(0xFF16A34A) : scheme.error),
          decoration: rejected ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
