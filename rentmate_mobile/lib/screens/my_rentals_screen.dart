import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/condition_report_service.dart';
import '../services/item_service.dart';
import '../services/payment_service.dart';
import '../services/shipping_service.dart';
import '../services/rental_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';
import 'notifications_screen.dart';
import 'condition_report_screen.dart';
import 'shipping_screen.dart';
import 'vnpay_screen.dart';
import 'wallet_screen.dart';
import '../l10n/l10n.dart';
import '../services/config_service.dart';

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
    if (userId == null) throw Exception(tr('Bạn cần đăng nhập lại'));
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
      final missing = r.amountToPay - wallet.availableBalance;
      if (await PaymentService().isVnPayEnabled()) {
        if (!mounted) return;
        final ok = await confirmDialog(
          context,
          title: tr('Ví còn thiếu {0}', [formatVnd(missing)]),
          message: tr('Cần {0}, ví của bạn có {1}.\nThanh toán phần còn thiếu qua VNPay (thẻ ATM / QR ngân hàng). Xong, đơn được trả tiền tự động.', [formatVnd(r.amountToPay), formatVnd(wallet.availableBalance)]),
          confirmText: tr('Trả qua VNPay'),
        );
        if (ok) await _payWithVnPay(r);
        return;
      }
      if (!mounted) return;
      final topUp = await confirmDialog(
        context,
        title: tr('Số dư không đủ'),
        message: tr('Cần {0}, ví của bạn có {1}.\nNạp thêm ít nhất {2} để thanh toán.', [formatVnd(r.amountToPay), formatVnd(wallet.availableBalance), formatVnd(r.amountToPay - wallet.availableBalance)]),
        confirmText: tr('Nạp tiền'),
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
      tr('Thanh toán thành công. Chờ chủ đồ giao đồ.'),
      title: tr('Thanh toán đơn #{0}?', [r.id]),
      message: tr('Trừ {0} từ ví (thuê {1} + cọc {2}).\nSố dư sau thanh toán: {3}.', [formatVnd(r.amountToPay), formatVnd(r.totalPrice), formatVnd(r.depositAmount), formatVnd(wallet.availableBalance - r.amountToPay)]),
      confirmText: tr('Thanh toán'),
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
      showSnack(context, tr('Hãy chụp ảnh lập biên bản lúc nhận lại trước (nút "Biên bản")'), error: true);
      return;
    }

    final report = after;
    final result = await showModalBottomSheet<(num, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CompleteSheet(rental: r, report: report),
    );
    if (result == null || !mounted) return;
    final (damage, reason) = result;
    if (damage > r.depositAmount) {
      showSnack(context, tr('Không trừ quá tiền cọc {0}', [formatVnd(r.depositAmount)]), error: true);
      return;
    }
    if (damage > 0 && reason.isEmpty) {
      showSnack(context, tr('Hãy ghi lý do trừ cọc để người thuê biết'), error: true);
      return;
    }
    await _run(
      r,
      () => RentalService().complete(r.id, damageAmount: damage, damageNote: damage > 0 ? reason : null),
      damage > 0 ? tr('Đã gửi yêu cầu bồi thường. Chờ người thuê đồng ý (tối đa {0} ngày).', [AppConfig.renterResponseDays]) : tr('Đơn đã hoàn tất. Tiền đã vào ví.'),
    );
  }

  // Người thuê không đồng ý mức trừ cọc: gửi lý do, quản trị viên phân xử
  Future<void> _dispute(Rental r) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
        title: tr('Khiếu nại bồi thường'),
        hint: tr('Vì sao bạn không đồng ý? (vd. vết xước đã có từ lúc giao)'),
        confirmText: tr('Gửi khiếu nại'),
      ),
    );
    if (text == null || !mounted) return;
    if (text.isEmpty) {
      showSnack(context, tr('Hãy nhập lý do khiếu nại'), error: true);
      return;
    }
    await _run(r, () => RentalService().dispute(r.id, text), tr('Đã gửi khiếu nại. Quản trị viên sẽ xem ảnh biên bản và phân xử.'));
  }

  Future<void> _payWithVnPay(Rental r) async {
    setState(() => _busy.add(r.id));
    try {
      final payment = await PaymentService().createVnPay(rentalId: r.id);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => VnPayScreen(paymentUrl: payment.paymentUrl)));
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  // Chủ đồ gửi hàng: chọn khối lượng để GHN tính phí rồi tạo vận đơn
  Future<void> _ship(Rental r) async {
    final grams = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Khối lượng món đồ (cả hộp)')),
        children: [
          for (final g in const [500, 1000, 2000, 5000, 10000, 20000])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, g),
              child: Text(g < 1000 ? tr('Dưới {0}g', [g]) : tr('Khoảng {0} kg', [g ~/ 1000])),
            ),
        ],
      ),
    );
    if (grams == null || !mounted) return;
    await _run(r, () => ShippingService().createShipment(r.id, grams),
        tr('Đã tạo đơn GHN. Shipper sẽ đến lấy hàng tại địa chỉ cửa hàng.'));
  }

  // Người thuê từ chối nhận (đồ khác tin đăng, hư hỏng...): hủy đơn, hoàn 100%
  Future<void> _rejectPickup(Rental r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
        title: tr('Từ chối nhận đồ'),
        hint: tr('Vì sao bạn không nhận? (vd. khác món trong tin đăng, bị nứt màn hình)'),
        confirmText: tr('Từ chối và hoàn tiền'),
      ),
    );
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      showSnack(context, tr('Hãy nhập lý do để chủ đồ và quản trị viên biết'), error: true);
      return;
    }
    await _run(r, () => RentalService().cancel(r.id, reason: reason),
        tr('Đã từ chối nhận. {0} đã hoàn vào ví.', [formatVnd(r.amountToPay)]));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Đơn thuê')),
          actions: const [NotificationBell()],
          bottom: TabBar(tabs: [Tab(text: tr('Tôi đi thuê')), Tab(text: tr('Đồ tôi cho thuê'))]),
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
                  empty: EmptyView(
                    icon: Icons.shopping_bag_outlined,
                    title: tr('Bạn chưa thuê đồ nào'),
                    subtitle: tr('Vào tab Khám phá để tìm đồ cần thuê.'),
                  )),
              _list(rentals.where((r) => r.ownerId == userId).toList(),
                  isOwner: true,
                  empty: EmptyView(
                    icon: Icons.handshake_outlined,
                    title: tr('Chưa có ai thuê đồ của bạn'),
                    subtitle: tr('Đăng thêm đồ trong tab "Đồ của tôi" để có người thuê.'),
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
                      Text(tr('Đơn #{0} · {1}', [r.id, isOwner ? 'Người thuê: ${r.renterName}' : 'Chủ đồ: ${r.ownerName}']),
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
                Text(tr('{0} → {1} ({2} ngày)', [fmtDate(r.startDate), fmtDate(r.endDate), r.days])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 18, color: muted),
                const SizedBox(width: 6),
                Expanded(child: Text(tr('Thuê {0} · Cọc {1}', [formatVnd(r.totalPrice), formatVnd(r.depositAmount)]))),
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
                  Expanded(child: Text(tr('Bồi thường {0}: {1}', [formatVnd(r.damageAmount), r.damageNote]))),
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
        'Pending' => tr('Có người muốn thuê. Duyệt hoặc từ chối yêu cầu.'),
        'Approved' => r.ownerCanCancel
            ? tr('Người thuê chưa thanh toán sau {0} giờ. Bạn có thể hủy đơn.', [AppConfig.paymentTimeoutHours])
            : tr('Chờ người thuê thanh toán (trong {0} giờ). Bạn có thể lập biên bản trước.', [AppConfig.paymentTimeoutHours]),
        'WaitingForPickup' => !r.isShipping
            ? tr('Người thuê đã thanh toán. Chụp ảnh biên bản lúc giao rồi hẹn gặp người thuê để giao đồ.')
            : r.shippingOrderCode == null
                ? tr('Người thuê đã thanh toán. Chụp ảnh biên bản lúc giao, đóng gói rồi bấm "Gửi hàng GHN".')
                : tr('Đã gửi GHN (mã {0}). Chờ người thuê nhận hàng.', [r.shippingOrderCode]),
        'Rented' => tr('Đang cho thuê, hạn trả {0}.{1}', [fmtDate(r.endDate), r.shiftedDays > 0 ? ' Hạn trả đã lùi ${r.shiftedDays} ngày vì đồ đến tay trễ.' : '']),
        'Cancelled' => r.cancelReason == null ? null : tr('Đơn đã hủy. Lý do: {0}', [r.cancelReason]),
        'Returned' => tr('Người thuê đã trả đồ. Trong {0} ngày, chụp ảnh lập biên bản nhận lại (AI so sánh với lúc giao) rồi bấm "Hoàn tất".', [AppConfig.ownerInspectionDays]),
        'DamageClaimed' => r.ownerCanFinalizeDamage
            ? tr('Người thuê không phản hồi sau {0} ngày. Bạn có thể chốt mức bồi thường.', [AppConfig.renterResponseDays])
            : tr('Chờ người thuê đồng ý hoặc khiếu nại mức bồi thường (tối đa {0} ngày).', [AppConfig.renterResponseDays]),
        'Disputed' => tr('Người thuê khiếu nại: {0}. Quản trị viên đang phân xử.', [r.disputeReason ?? '']),
        'Completed' => r.damageAmount > 0
            ? tr('Đã hoàn tất. Tiền thuê (trừ {2}% phí) và {0} bồi thường đã vào ví.{1}', [formatVnd(r.damageAmount), r.resolutionNote != null ? ' Kết luận: ${r.resolutionNote}' : '', r.feeText])
            : tr('Đã hoàn tất. Tiền thuê (trừ {0}% phí) đã vào ví của bạn.', [r.feeText]),
        _ => null,
      };
    }
    return switch (r.status) {
      'Pending' => tr('Đang chờ chủ đồ duyệt.'),
      'Approved' => tr('Chủ đồ đã duyệt! Thanh toán {0} trong {1} giờ để giữ đơn.', [formatVnd(r.amountToPay), AppConfig.paymentTimeoutHours]),
      'WaitingForPickup' =>
        tr('{0}Khi nhận: vào "Biên bản" chụp ảnh đối chiếu, đúng đồ thì bấm "Đã nhận đồ"; sai món hoặc hư hỏng thì bấm "Từ chối nhận" để được hoàn 100%.', [r.isShipping ? (r.shippingOrderCode == null ? 'Chờ chủ đồ gửi hàng GHN. ' : 'Đang giao (mã ${r.shippingOrderCode}). ') : 'Hẹn gặp chủ đồ để nhận đồ. ']),
      'Rented' => tr('Bạn đang thuê, hạn trả {0}. Trả đồ xong bấm "Đã trả đồ".{1}{2}', [fmtDate(r.endDate), r.shiftedDays > 0 ? ' Hạn trả đã lùi ${r.shiftedDays} ngày vì đồ đến tay trễ.' : '', r.lateDeliveryRefund > 0 ? ' Đã hoàn ${formatVnd(r.lateDeliveryRefund)} tiền thuê vì đồ đến trễ.' : '']),
      'Cancelled' => r.cancelReason == null ? null : tr('Đơn đã hủy. Lý do: {0}', [r.cancelReason]),
      'Returned' => r.renterCanForceComplete
          ? tr('Chủ đồ chưa kiểm tra sau {0} ngày. Bạn có thể tự hoàn tất để nhận lại đủ cọc.', [AppConfig.ownerInspectionDays])
          : tr('Chờ chủ đồ kiểm tra (tối đa {0} ngày). Tiền cọc sẽ hoàn vào ví khi đơn hoàn tất.', [AppConfig.ownerInspectionDays]),
      'DamageClaimed' => tr('Chủ đồ đề nghị trừ {0} tiền cọc. Xem ảnh biên bản rồi đồng ý hoặc khiếu nại trong {1} ngày.', [formatVnd(r.damageAmount), AppConfig.renterResponseDays]),
      'Disputed' => tr('Bạn đã khiếu nại. Quản trị viên đang xem ảnh biên bản để phân xử.'),
      'Completed' => r.damageAmount > 0
          ? tr('Đã hoàn tất. Trừ {0} bồi thường, hoàn {1} cọc vào ví.{2}', [formatVnd(r.damageAmount), formatVnd(r.depositAmount - r.damageAmount), r.resolutionNote != null ? ' Kết luận: ${r.resolutionNote}' : ''])
          : tr('Đã hoàn tất. Tiền cọc {0} đã hoàn vào ví.', [formatVnd(r.depositAmount)]),
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
          label: Text(tr('Biên bản')),
          onPressed: guard(() async {
            final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => ConditionReportScreen(rental: r, isOwner: isOwner)));
            if (created == true) await _reload();
          }),
        ),
      if (['WaitingForPickup', 'Rented', 'Returned', 'DamageClaimed', 'Disputed', 'Completed'].contains(s))
        TextButton.icon(
          icon: Icon(r.isShipping ? Icons.local_shipping_outlined : Icons.timeline, size: 18),
          label: Text(tr('Giao nhận')),
          onPressed: guard(() => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ShippingScreen(rental: r)))),
        ),

      // ===== Người thuê =====
      if (!isOwner && s == 'WaitingForPickup')
        OutlinedButton(onPressed: guard(() => _rejectPickup(r)), child: Text(tr('Từ chối nhận'))),
      if (!isOwner && ['Pending', 'Approved'].contains(s))
        OutlinedButton(
          onPressed: guard(() => _confirmAndAct(r, 'cancel', tr('Đã hủy đơn'),
              title: tr('Hủy đơn #{0}?', [r.id]),
              message: s == 'WaitingForPickup'
                  ? tr('Bạn đã thanh toán, {0} sẽ được hoàn 100% vào ví.', [formatVnd(r.amountToPay)])
                  : tr('Yêu cầu thuê sẽ bị hủy.'),
              confirmText: tr('Hủy đơn'),
              danger: true)),
          child: Text(tr('Hủy đơn')),
        ),
      if (!isOwner && s == 'Approved')
        FilledButton(onPressed: guard(() => _pay(r)), child: Text(tr('Thanh toán'))),
      if (!isOwner && s == 'WaitingForPickup')
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'pickup', tr('Đã xác nhận nhận đồ. Nhớ trả đúng hạn.'),
              title: tr('Bạn đã nhận đồ?'),
              message: tr('Chỉ bấm khi đã cầm đồ trên tay và thấy đúng như ảnh biên bản lúc giao. Không đúng thì đừng nhận, có thể hủy đơn để được hoàn tiền.'),
              confirmText: tr('Đã nhận đồ'))),
          child: Text(tr('Đã nhận đồ')),
        ),
      if (!isOwner && r.renterCanForceComplete)
        FilledButton(
          onPressed: guard(() => _run(r, () => RentalService().complete(r.id), tr('Đơn đã hoàn tất, tiền cọc đã hoàn vào ví.'))),
          child: Text(tr('Tự hoàn tất')),
        ),
      if (!isOwner && s == 'DamageClaimed') ...[
        OutlinedButton(onPressed: guard(() => _dispute(r)), child: Text(tr('Khiếu nại'))),
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'accept-damage', tr('Đã đồng ý. Phần cọc còn lại đã hoàn vào ví.'),
              title: tr('Đồng ý trừ {0}?', [formatVnd(r.damageAmount)]),
              message: tr('Bạn nhận lại {0} tiền cọc. Không hoàn tác được.', [formatVnd(r.depositAmount - r.damageAmount)]),
              confirmText: tr('Đồng ý'))),
          child: Text(tr('Đồng ý')),
        ),
      ],
      if (!isOwner && s == 'Rented')
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'return', tr('Đã báo trả đồ. Chờ chủ đồ kiểm tra.'),
              title: tr('Bạn đã trả đồ?'), message: tr('Chỉ bấm khi đã giao lại đồ cho chủ đồ.'), confirmText: tr('Đã trả'))),
          child: Text(tr('Đã trả đồ')),
        ),

      // ===== Chủ đồ =====
      if (isOwner && s == 'Pending') ...[
        OutlinedButton(
          onPressed: guard(() => _confirmAndAct(r, 'reject', tr('Đã từ chối yêu cầu'),
              title: tr('Từ chối yêu cầu?'), message: tr('Người thuê sẽ thấy đơn bị từ chối.'), confirmText: tr('Từ chối'), danger: true)),
          child: Text(tr('Từ chối')),
        ),
        FilledButton(onPressed: guard(() => _act(r, 'approve', tr('Đã duyệt. Chờ người thuê thanh toán.'))), child: Text(tr('Duyệt'))),
      ],
      if (isOwner && r.ownerCanCancel)
        OutlinedButton(
          onPressed: guard(() => _confirmAndAct(r, 'cancel', tr('Đã hủy đơn'),
              title: tr('Hủy đơn #{0}?', [r.id]), message: tr('Người thuê chưa thanh toán sau {0} giờ.', [AppConfig.paymentTimeoutHours]), confirmText: tr('Hủy đơn'), danger: true)),
          child: Text(tr('Hủy đơn')),
        ),
      if (isOwner && s == 'Returned')
        FilledButton(onPressed: guard(() => _complete(r)), child: Text(tr('Hoàn tất'))),
      if (isOwner && s == 'WaitingForPickup' && r.isShipping && r.shippingOrderCode == null)
        FilledButton.icon(
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          onPressed: guard(() => _ship(r)),
          label: Text(tr('Gửi hàng GHN')),
        ),
      if (isOwner && r.ownerCanFinalizeDamage)
        FilledButton(
          onPressed: guard(() => _confirmAndAct(r, 'complete', tr('Đã chốt bồi thường. Tiền đã vào ví.'),
              title: tr('Chốt bồi thường {0}?', [formatVnd(r.damageAmount)]),
              message: tr('Người thuê không phản hồi sau {0} ngày nên áp dụng mức bạn đã đề nghị.', [AppConfig.renterResponseDays]),
              confirmText: tr('Chốt'))),
          child: Text(tr('Chốt bồi thường')),
        ),
    ];
    if (buttons.isEmpty) return [];
    return [
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: buttons),
    ];
  }
}

/// Bảng hoàn tất đơn của chủ đồ. Tự giữ ô nhập để không bị hủy khi bảng đang đóng
/// (hủy sớm sẽ gây lỗi "dependents.isEmpty").
class _CompleteSheet extends StatefulWidget {
  final Rental rental;
  final ConditionReport report;
  const _CompleteSheet({required this.rental, required this.report});

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  late final _amount = TextEditingController(text: moneyText(_suggested));
  late final _note = TextEditingController(text: _suggested > 0 ? widget.report.aiDamages.join('; ') : '');

  num get _suggested => widget.report.aiSuggestedDeduction ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Hoàn tất đơn #{0}', [r.id]), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (widget.report.hasAi) ...[AiReviewBox(report: widget.report), const SizedBox(height: 12)],
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: InputDecoration(
                labelText: tr('Trừ cọc bồi thường'),
                suffixText: tr('đ'),
                helperText: tr('Từ 0 đến {0}. Nhập 0 nếu đồ không hư hỏng.', [formatVnd(r.depositAmount)]),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(labelText: tr('Lý do trừ cọc (bắt buộc nếu trừ)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, (parseMoney(_amount.text) ?? 0, _note.text.trim())),
              child: Text(tr('Xác nhận')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại nhập lý do (khiếu nại, từ chối nhận đồ).
class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmText;
  const _ReasonDialog({required this.title, required this.hint, required this.confirmText});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _reason,
        maxLines: 3,
        maxLength: 500,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Đóng'))),
        FilledButton(onPressed: () => Navigator.pop(context, _reason.text.trim()), child: Text(widget.confirmText)),
      ],
    );
  }
}
