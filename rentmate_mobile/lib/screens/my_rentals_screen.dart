import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';
import 'condition_report_screen.dart';
import 'wallet_screen.dart';

/// Hai tab: đơn mình đi thuê, và đơn người khác thuê đồ của mình.
class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen> {
  late Future<(List<Rental>, String)> _future = _load();
  final _busy = <int>{}; // đơn đang gửi thao tác, khóa nút để không bấm 2 lần

  Future<(List<Rental>, String)> _load() async {
    final userId = await AuthService().getUserId();
    if (userId == null) throw Exception('Bạn cần đăng nhập lại');
    return (await RentalService().getMyRentals(), userId);
  }

  Future<void> _reload() async {
    setState(() { _future = _load(); });
    await _future;
  }

  Future<void> _act(Rental r, String action, String doneText) async {
    setState(() => _busy.add(r.id));
    try {
      await RentalService().updateStatus(r.id, action);
      if (!mounted) return;
      showSnack(context, doneText);
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _confirmAndAct(Rental r, String action, String doneText,
      {required String title, required String message, required String confirmText, bool danger = false}) async {
    if (await confirmDialog(context, title: title, message: message, confirmText: confirmText, danger: danger)) {
      await _act(r, action, doneText);
    }
  }

  // Thanh toán: xem số dư trước, thiếu thì mời nạp tiền.
  Future<void> _pay(Rental r) async {
    WalletSummary wallet;
    try {
      wallet = await WalletService().getSummary();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
      return;
    }
    if (!mounted) return;
    if (wallet.availableBalance < r.amountToPay) {
      final topUp = await confirmDialog(
        context,
        title: 'Số dư không đủ',
        message: 'Cần ${formatVnd(r.amountToPay)}, ví của bạn có ${formatVnd(wallet.availableBalance)}.\n'
            'Nạp thêm ít nhất ${formatVnd(r.amountToPay - wallet.availableBalance)} để thanh toán.',
        confirmText: 'Nạp tiền',
      );
      if (topUp && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen(standalone: true)));
        await _reload();
      }
      return;
    }
    await _confirmAndAct(
      r,
      'pay',
      'Thanh toán thành công. Chờ chủ đồ giao đồ.',
      title: 'Thanh toán đơn #${r.id}?',
      message: 'Trừ ${formatVnd(r.amountToPay)} từ ví (thuê ${formatVnd(r.totalPrice)} + cọc ${formatVnd(r.depositAmount)}).\n'
          'Số dư sau thanh toán: ${formatVnd(wallet.availableBalance - r.amountToPay)}.',
      confirmText: 'Thanh toán',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn thuê'),
          bottom: const TabBar(tabs: [Tab(text: 'Tôi đi thuê'), Tab(text: 'Đồ tôi cho thuê')]),
        ),
        body: FutureBuilder<(List<Rental>, String)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
            if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
            final (rentals, userId) = snap.data!;
            return TabBarView(children: [
              _list(rentals.where((r) => r.renterId == userId).toList(),
                  isOwner: false,
                  empty: const EmptyView(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Bạn chưa thuê đồ nào',
                    subtitle: 'Vào tab Khám phá để tìm đồ cần thuê.',
                  )),
              _list(rentals.where((r) => r.ownerId == userId).toList(),
                  isOwner: true,
                  empty: const EmptyView(
                    icon: Icons.handshake_outlined,
                    title: 'Chưa có ai thuê đồ của bạn',
                    subtitle: 'Đăng thêm đồ trong tab "Đồ của tôi" để có người thuê.',
                  )),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(List<Rental> rentals, {required bool isOwner, required Widget empty}) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: rentals.isEmpty
          ? ListView(children: [empty])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rentals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _card(rentals[i], isOwner),
            ),
    );
  }

  Widget _card(Rental r, bool isOwner) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final hint = _hint(r, isOwner);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Đơn #${r.id} · ${isOwner ? 'Người thuê: ${r.renterName}' : 'Chủ đồ: ${r.ownerName}'}',
                          style: TextStyle(color: muted, fontSize: 13)),
                    ],
                  ),
                ),
                StatusBadge(rentalStatusLabels[r.status] ?? r.status, statusColor(r.status)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 18, color: muted),
                const SizedBox(width: 6),
                Text('${fmtDate(r.startDate)} → ${fmtDate(r.endDate)} (${r.days} ngày)'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 18, color: muted),
                const SizedBox(width: 6),
                Expanded(child: Text('Thuê ${formatVnd(r.totalPrice)} · Cọc ${formatVnd(r.depositAmount)}')),
              ],
            ),
            if (r.requestNote != null && r.requestNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r.requestNote!, style: TextStyle(color: muted))),
                ],
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 10),
              NoticeBox(hint, color: statusColor(r.status)),
            ],
            ..._actions(r, isOwner),
          ],
        ),
      ),
    );
  }

  // Câu hướng dẫn bước tiếp theo, theo luồng trong RentalService.cs.
  String? _hint(Rental r, bool isOwner) {
    if (isOwner) {
      return switch (r.status) {
        'Pending' => 'Có người muốn thuê. Duyệt hoặc từ chối yêu cầu.',
        'Approved' => r.ownerCanCancel
            ? 'Người thuê chưa thanh toán sau 24 giờ. Bạn có thể hủy đơn.'
            : 'Chờ người thuê thanh toán (trong 24 giờ). Bạn có thể lập biên bản trước.',
        'WaitingForPickup' => 'Người thuê đã thanh toán. Lập biên bản tình trạng đồ rồi bấm "Đã giao đồ".',
        'Rented' => 'Đang cho thuê, hạn trả ${fmtDate(r.endDate)}.',
        'Returned' => 'Người thuê đã trả đồ. Kiểm tra, lập biên bản sau khi trả rồi bấm "Hoàn tất".',
        'Completed' => 'Đã hoàn tất. Tiền thuê (trừ 5% phí) đã vào ví của bạn.',
        _ => null,
      };
    }
    return switch (r.status) {
      'Pending' => 'Đang chờ chủ đồ duyệt.',
      'Approved' => 'Chủ đồ đã duyệt! Thanh toán ${formatVnd(r.amountToPay)} trong 24 giờ để giữ đơn.',
      'WaitingForPickup' => 'Đã thanh toán. Liên hệ chủ đồ để nhận đồ.',
      'Rented' => 'Bạn đang thuê, hạn trả ${fmtDate(r.endDate)}. Trả đồ xong bấm "Đã trả đồ".',
      'Returned' => 'Chờ chủ đồ kiểm tra. Tiền cọc sẽ hoàn vào ví khi đơn hoàn tất.',
      'Completed' => 'Đã hoàn tất. Tiền cọc ${formatVnd(r.depositAmount)} đã hoàn vào ví.',
      _ => null,
    };
  }

  // Ai được bấm nút nào: theo kiểm tra quyền trong RentalService.cs.
  List<Widget> _actions(Rental r, bool isOwner) {
    final busy = _busy.contains(r.id);
    final s = r.status;
    void Function()? guard(void Function() f) => busy ? null : f;

    final buttons = <Widget>[
      // Biên bản có từ lúc duyệt trở đi; chủ đồ lập, người thuê xem.
      if (!['Pending', 'Rejected', 'Cancelled'].contains(s))
        TextButton.icon(
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Biên bản'),
          onPressed: guard(() async {
            final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => ConditionReportScreen(rental: r, isOwner: isOwner)));
            if (created == true) await _reload();
          }),
        ),

      // ===== Người thuê =====
      if (!isOwner && ['Pending', 'Approved', 'WaitingForPickup'].contains(s))
        OutlinedButton(
          onPressed: guard(() => _confirmAndAct(r, 'cancel', 'Đã hủy đơn',
              title: 'Hủy đơn #${r.id}?',
              message: s == 'WaitingForPickup'
                  ? 'Bạn đã thanh toán, ${formatVnd(r.amountToPay)} sẽ được hoàn 100% vào ví.'
                  : 'Yêu cầu thuê sẽ bị hủy.',
              confirmText: 'Hủy đơn',
              danger: true)),
          child: const Text('Hủy đơn'),
        ),
      if (!isOwner && s == 'Approved')
        FilledButton(onPressed: guard(() => _pay(r)), child: const Text('Thanh toán')),
      if (!isOwner && s == 'Rented')
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'return', 'Đã báo trả đồ. Chờ chủ đồ kiểm tra.',
              title: 'Bạn đã trả đồ?', message: 'Chỉ bấm khi đã giao lại đồ cho chủ đồ.', confirmText: 'Đã trả')),
          child: const Text('Đã trả đồ'),
        ),

      // ===== Chủ đồ =====
      if (isOwner && s == 'Pending') ...[
        OutlinedButton(
          onPressed: guard(() => _confirmAndAct(r, 'reject', 'Đã từ chối yêu cầu',
              title: 'Từ chối yêu cầu?', message: 'Người thuê sẽ thấy đơn bị từ chối.', confirmText: 'Từ chối', danger: true)),
          child: const Text('Từ chối'),
        ),
        FilledButton(onPressed: guard(() => _act(r, 'approve', 'Đã duyệt. Chờ người thuê thanh toán.')), child: const Text('Duyệt')),
      ],
      if (isOwner && r.ownerCanCancel)
        OutlinedButton(
          onPressed: guard(() => _confirmAndAct(r, 'cancel', 'Đã hủy đơn',
              title: 'Hủy đơn #${r.id}?', message: 'Người thuê chưa thanh toán sau 24 giờ.', confirmText: 'Hủy đơn', danger: true)),
          child: const Text('Hủy đơn'),
        ),
      if (isOwner && s == 'WaitingForPickup')
        FilledButton(onPressed: guard(() => _act(r, 'pickup', 'Đã xác nhận giao đồ')), child: const Text('Đã giao đồ')),
      if (isOwner && s == 'Returned')
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'complete', 'Đơn đã hoàn tất. Tiền đã vào ví.',
              title: 'Hoàn tất đơn?',
              message: 'Tiền thuê (trừ 5% phí) vào ví của bạn, tiền cọc hoàn cho người thuê. Không hoàn tác được.',
              confirmText: 'Hoàn tất')),
          child: const Text('Hoàn tất'),
        ),
    ];
    if (buttons.isEmpty) return [];
    return [
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: buttons),
    ];
  }
}
