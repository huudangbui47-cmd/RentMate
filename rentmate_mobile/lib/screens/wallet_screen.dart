import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../services/wallet_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import 'notifications_screen.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';
import 'main_shell.dart';
import '../l10n/l10n.dart';

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
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (changed == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(
        title: Text(tr('Ví RentMate')),
        automaticallyImplyLeading: widget.standalone,
        actions: [if (!widget.standalone) const NotificationBell()],
      ),
      body: FutureBuilder<(WalletSummary, List<WalletTransaction>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final (wallet, history) = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, 12, 12, widget.standalone ? 24 : navPillSpace(context)),
              children: [
                _balanceCard(wallet),
                const SizedBox(height: 12),
                RcMenuGroup(
                  label: tr('Tài khoản nhận tiền'),
                  children: [
                    RcMenuItem(
                      icon: Icons.account_balance_outlined,
                      title: wallet.hasBankInfo
                          ? '${wallet.bankName} · ${wallet.maskedAccountNumber}'
                          : tr('Chưa có tài khoản ngân hàng'),
                      subtitle: wallet.hasBankInfo
                          ? wallet.bankAccountName ?? ''
                          : tr('Cần thêm để rút tiền về ngân hàng'),
                      onTap: () => _open(const BankInfoScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  RcCard(
                    child: EmptyView(
                      icon: Icons.receipt_outlined,
                      title: tr('Chưa có giao dịch'),
                      subtitle: tr('Nạp tiền để thanh toán đơn thuê nhanh chóng.'),
                    ),
                  )
                else
                  RcCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(tr('Lịch sử giao dịch'), style: kText(13, FontWeight.w300, color: AppColors.muted)),
                        const SizedBox(height: 2),
                        for (var i = 0; i < history.length; i++)
                          _transactionTile(history[i], last: i == history.length - 1),
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

  // Khối số dư: khối trắng bo tròn, số tiền lớn, nút đen "Nạp tiền" và nút viền "Rút tiền" (viên thuốc)
  Widget _balanceCard(WalletSummary w) {
    return RcCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('Số dư khả dụng'), style: kText(13, FontWeight.w300, color: AppColors.muted)),
              ),
              const RcIconCircle(Icons.account_balance_wallet_outlined, size: 36),
            ],
          ),
          Text(formatVnd(w.availableBalance), style: kText(32, FontWeight.w500, lh: 40)),
          if (w.pendingWithdrawAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(tr('Đang chờ rút: {0}', [formatVnd(w.pendingWithdrawAmount)]), style: kBody12Hint),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _open(const DepositScreen()),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(tr('Nạp tiền')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _open(w.hasBankInfo ? WithdrawScreen(wallet: w) : const BankInfoScreen(thenWithdraw: true)),
                  icon: const Icon(Icons.north_east_rounded, size: 18),
                  label: Text(tr('Rút tiền')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dòng giao dịch kiểu dòng thông báo: icon tròn, tên + thời gian, số tiền bên phải
  Widget _transactionTile(WalletTransaction t, {bool last = false}) {
    final incoming = t.amount >= 0;
    final pendingDeposit = t.type == 'Deposit' && t.status == 'Pending';
    final rejected = t.status == 'Rejected';
    return InkWell(
      onTap: pendingDeposit ? () => _open(DepositInfoScreen(depositId: t.id)) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RcIconCircle(incoming ? Icons.south_west_rounded : Icons.north_east_rounded, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(walletTypeLabels[t.type] ?? t.type, style: kText(15, FontWeight.w400)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      fmtDateTime(t.createdAt),
                      if (t.code != null) tr('Mã {0}', [t.code]),
                      if (t.rentalId != null) tr('Đơn #{0}', [t.rentalId]),
                    ].join(' · '),
                    style: kSub12,
                  ),
                  if (t.status != 'Completed')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: StatusBadge(
                        pendingDeposit
                            ? tr('Chờ duyệt · bấm để xem cách chuyển khoản')
                            : walletStatusLabels[t.status] ?? t.status,
                        statusColor(t.status == 'Pending' ? 'Pending' : 'Rejected'),
                      ),
                    ),
                  if (rejected && (t.note ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tr('Lý do: {0}', [t.note]),
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${incoming ? '+' : ''}${formatVnd(t.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: rejected ? AppColors.muted : (incoming ? AppColors.success : AppColors.ink),
                decoration: rejected ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
