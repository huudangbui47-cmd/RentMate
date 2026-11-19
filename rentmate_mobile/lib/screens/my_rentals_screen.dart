import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/condition_report_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';
import 'notifications_screen.dart';
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

  // Chạy một thao tác có gọi API, khóa nút của đơn trong lúc chờ
  Future<void> _run(Rental r, Future<void> Function() call, String doneText) async {
    setState(() => _busy.add(r.id));
    try {
      await call();
      if (!mounted) return;
      showSnack(context, doneText);
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  // Chủ đồ hoàn tất: xem nhận xét AI của biên bản nhận lại, nhập số tiền trừ cọc (0 = hoàn đủ)
  Future<void> _complete(Rental r) async {
    ConditionReport? after;
    try {
      final reports = await ConditionReportService().getReports(r.id);
      after = reports.where((x) => x.reportType == 'AfterRental').firstOrNull;
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
      return;
    }
    if (!mounted) return;
    if (after == null) {
      showSnack(context, 'Hãy chụp ảnh lập biên bản lúc nhận lại trước (nút "Biên bản")', error: true);
      return;
    }

    final report = after;
    final suggested = report.aiSuggestedDeduction ?? 0;
    final amount = TextEditingController(text: suggested > 0 ? '${suggested.round()}' : '0');
    final note = TextEditingController(text: suggested > 0 ? report.aiDamages.join('; ') : '');
    final result = await showModalBottomSheet<(num, String)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hoàn tất đơn #${r.id}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (report.hasAi) ...[AiReviewBox(report: report), const SizedBox(height: 12)],
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Trừ cọc bồi thường (đ)',
                  helperText: 'Từ 0 đến ${formatVnd(r.depositAmount)}. Nhập 0 nếu đồ không hư hỏng.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Lý do trừ cọc (bắt buộc nếu trừ)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, (num.tryParse(amount.text) ?? 0, note.text.trim())),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ),
      ),
    );
    amount.dispose();
    note.dispose();
    if (result == null || !mounted) return;
    final (damage, reason) = result;
    if (damage > r.depositAmount) {
      showSnack(context, 'Không trừ quá tiền cọc ${formatVnd(r.depositAmount)}', error: true);
      return;
    }
    if (damage > 0 && reason.isEmpty) {
      showSnack(context, 'Hãy ghi lý do trừ cọc để người thuê biết', error: true);
      return;
    }
    await _run(
      r,
      () => RentalService().complete(r.id, damageAmount: damage, damageNote: damage > 0 ? reason : null),
      damage > 0 ? 'Đã gửi yêu cầu bồi thường. Chờ người thuê đồng ý (tối đa 2 ngày).' : 'Đơn đã hoàn tất. Tiền đã vào ví.',
    );
  }

  // Người thuê không đồng ý mức trừ cọc: gửi lý do, quản trị viên phân xử
  Future<void> _dispute(Rental r) async {
    final reason = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khiếu nại bồi thường'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Vì sao bạn không đồng ý? (vd. vết xước đã có từ lúc giao)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          FilledButton(onPressed: () => Navigator.pop(context, reason.text.trim()), child: const Text('Gửi khiếu nại')),
        ],
      ),
    );
    reason.dispose();
    if (text == null || !mounted) return;
    if (text.isEmpty) {
      showSnack(context, 'Hãy nhập lý do khiếu nại', error: true);
      return;
    }
    await _run(r, () => RentalService().dispute(r.id, text), 'Đã gửi khiếu nại. Quản trị viên sẽ xem ảnh biên bản và phân xử.');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn thuê'),
          actions: const [NotificationBell()],
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
            if (r.damageAmount > 0 && r.damageNote != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.build_circle_outlined, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Bồi thường ${formatVnd(r.damageAmount)}: ${r.damageNote}')),
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
        'WaitingForPickup' => 'Người thuê đã thanh toán. Chụp ảnh lập biên bản lúc giao, khi nhận đồ người thuê sẽ bấm "Đã nhận đồ".',
        'Rented' => 'Đang cho thuê, hạn trả ${fmtDate(r.endDate)}.',
        'Returned' => 'Người thuê đã trả đồ. Trong 3 ngày, chụp ảnh lập biên bản nhận lại (AI so sánh với lúc giao) rồi bấm "Hoàn tất".',
        'DamageClaimed' => r.ownerCanFinalizeDamage
            ? 'Người thuê không phản hồi sau 2 ngày. Bạn có thể chốt mức bồi thường.'
            : 'Chờ người thuê đồng ý hoặc khiếu nại mức bồi thường (tối đa 2 ngày).',
        'Disputed' => 'Người thuê khiếu nại: ${r.disputeReason ?? ''}. Quản trị viên đang phân xử.',
        'Completed' => r.damageAmount > 0
            ? 'Đã hoàn tất. Tiền thuê (trừ 5% phí) và ${formatVnd(r.damageAmount)} bồi thường đã vào ví.${r.resolutionNote != null ? ' Kết luận: ${r.resolutionNote}' : ''}'
            : 'Đã hoàn tất. Tiền thuê (trừ 5% phí) đã vào ví của bạn.',
        _ => null,
      };
    }
    return switch (r.status) {
      'Pending' => 'Đang chờ chủ đồ duyệt.',
      'Approved' => 'Chủ đồ đã duyệt! Thanh toán ${formatVnd(r.amountToPay)} trong 24 giờ để giữ đơn.',
      'WaitingForPickup' => 'Đã thanh toán. Khi nhận đồ, xem ảnh biên bản lúc giao rồi bấm "Đã nhận đồ".',
      'Rented' => 'Bạn đang thuê, hạn trả ${fmtDate(r.endDate)}. Trả đồ xong bấm "Đã trả đồ".',
      'Returned' => r.renterCanForceComplete
          ? 'Chủ đồ chưa kiểm tra sau 3 ngày. Bạn có thể tự hoàn tất để nhận lại đủ cọc.'
          : 'Chờ chủ đồ kiểm tra (tối đa 3 ngày). Tiền cọc sẽ hoàn vào ví khi đơn hoàn tất.',
      'DamageClaimed' => 'Chủ đồ đề nghị trừ ${formatVnd(r.damageAmount)} tiền cọc. Xem ảnh biên bản rồi đồng ý hoặc khiếu nại trong 2 ngày.',
      'Disputed' => 'Bạn đã khiếu nại. Quản trị viên đang xem ảnh biên bản để phân xử.',
      'Completed' => r.damageAmount > 0
          ? 'Đã hoàn tất. Trừ ${formatVnd(r.damageAmount)} bồi thường, hoàn ${formatVnd(r.depositAmount - r.damageAmount)} cọc vào ví.${r.resolutionNote != null ? ' Kết luận: ${r.resolutionNote}' : ''}'
          : 'Đã hoàn tất. Tiền cọc ${formatVnd(r.depositAmount)} đã hoàn vào ví.',
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
      if (!isOwner && s == 'WaitingForPickup')
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'pickup', 'Đã xác nhận nhận đồ. Nhớ trả đúng hạn.',
              title: 'Bạn đã nhận đồ?',
              message: 'Chỉ bấm khi đã cầm đồ trên tay và thấy đúng như ảnh biên bản lúc giao. '
                  'Không đúng thì đừng nhận, có thể hủy đơn để được hoàn tiền.',
              confirmText: 'Đã nhận đồ')),
          child: const Text('Đã nhận đồ'),
        ),
      if (!isOwner && r.renterCanForceComplete)
        FilledButton(
          onPressed: guard(() => _run(r, () => RentalService().complete(r.id), 'Đơn đã hoàn tất, tiền cọc đã hoàn vào ví.')),
          child: const Text('Tự hoàn tất'),
        ),
      if (!isOwner && s == 'DamageClaimed') ...[
        OutlinedButton(onPressed: guard(() => _dispute(r)), child: const Text('Khiếu nại')),
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'accept-damage', 'Đã đồng ý. Phần cọc còn lại đã hoàn vào ví.',
              title: 'Đồng ý trừ ${formatVnd(r.damageAmount)}?',
              message: 'Bạn nhận lại ${formatVnd(r.depositAmount - r.damageAmount)} tiền cọc. Không hoàn tác được.',
              confirmText: 'Đồng ý')),
          child: const Text('Đồng ý'),
        ),
      ],
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
      if (isOwner && s == 'Returned')
        FilledButton(onPressed: guard(() => _complete(r)), child: const Text('Hoàn tất')),
      if (isOwner && r.ownerCanFinalizeDamage)
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'complete', 'Đã chốt bồi thường. Tiền đã vào ví.',
              title: 'Chốt bồi thường ${formatVnd(r.damageAmount)}?',
              message: 'Người thuê không phản hồi sau 2 ngày nên áp dụng mức bạn đã đề nghị.',
              confirmText: 'Chốt')),
          child: const Text('Chốt bồi thường'),
        ),
    ];
    if (buttons.isEmpty) return [];
    return [
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: buttons),
    ];
  }
}
