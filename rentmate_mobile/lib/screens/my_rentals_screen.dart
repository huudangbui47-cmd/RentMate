import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/condition_report_service.dart';
import '../services/item_service.dart';
import '../services/payment_service.dart';
import '../services/shipping_service.dart';
import '../services/rental_service.dart';
import '../services/wallet_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import 'notifications_screen.dart';
import 'condition_report_screen.dart';
import 'shipping_screen.dart';
import 'vnpay_screen.dart';
import 'wallet_screen.dart';
import 'main_shell.dart';
import '../l10n/l10n.dart';
import '../services/config_service.dart';

/// Danh sách đơn thuê: nút gạt "Tôi đi thuê / Đồ tôi cho thuê" trong đầu trang, hàng lọc theo trạng thái,
/// mỗi đơn là một thẻ kiểu "Deals" của mẫu (nhãn trạng thái, ảnh giữa, tên giữa, mô tả xám, nút "Xem chi tiết").
class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen> with SingleTickerProviderStateMixin {
  late Future<(List<Rental>, String)> _future = _load();
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {
          _filter = 'all';
        });
      }
    });
  String _filter = 'all';

  // Nhóm trạng thái cho hàng lọc
  static const _groups = <String, List<String>>{
    'waiting': ['Pending', 'Approved', 'WaitingForPickup'],
    'renting': ['Rented', 'Returned', 'DamageClaimed', 'Disputed'],
    'done': ['Completed'],
    'closed': ['Cancelled', 'Rejected'],
  };

  Map<String, String> get _groupTitles => {
    'all': tr('Tất cả'),
    'waiting': tr('Đang chờ'),
    'renting': tr('Đang thuê'),
    'done': tr('Hoàn tất'),
    'closed': tr('Đã hủy'),
  };

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<(List<Rental>, String)> _load() async {
    final userId = await AuthService().getUserId();
    if (userId == null) throw Exception(tr('Bạn cần đăng nhập lại'));
    return (await RentalService().getMyRentals(), userId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _open(Rental r, bool isOwner) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RentalDetailScreen(rental: r, isOwner: isOwner),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(
        title: Text(tr('Đơn thuê')),
        actions: const [NotificationBell()],
        bottom: SegmentTabs([tr('Tôi đi thuê'), tr('Đồ tôi cho thuê')], controller: _tabs),
      ),
      body: FutureBuilder<(List<Rental>, String)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final (rentals, userId) = snap.data!;
          final isOwner = _tabs.index == 1;
          final mine = rentals.where((r) => isOwner ? r.ownerId == userId : r.renterId == userId).toList();
          final shown = _filter == 'all' ? mine : mine.where((r) => _groups[_filter]!.contains(r.status)).toList();
          int count(String g) => g == 'all' ? mine.length : mine.where((r) => _groups[g]!.contains(r.status)).length;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: EdgeInsets.only(top: 12, bottom: navPillSpace(context)),
              children: [
                // Hàng lọc viên thuốc như hàng danh mục ở Trang chủ
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final g in _groupTitles.keys) ...[
                        if (g != 'all') const SizedBox(width: 8),
                        RcChip(
                          label: '${_groupTitles[g]} ${count(g)}',
                          selected: _filter == g,
                          onTap: () => setState(() {
                            _filter = g;
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  RcCard(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    child: mine.isEmpty
                        ? EmptyView(
                            icon: isOwner ? Icons.handshake_outlined : Icons.shopping_bag_outlined,
                            title: isOwner ? tr('Chưa có ai thuê đồ của bạn') : tr('Bạn chưa thuê đồ nào'),
                            subtitle: isOwner
                                ? tr('Đăng thêm đồ trong tab "Đồ của tôi" để có người thuê.')
                                : tr('Vào tab Khám phá để tìm đồ cần thuê.'),
                          )
                        : EmptyView(icon: Icons.filter_alt_off_outlined, title: tr('Không có đơn nào ở mục này')),
                  )
                else
                  for (final r in shown) _card(r, isOwner),
              ],
            ),
          );
        },
      ),
    );
  }

  // Đơn đang chờ chính mình làm bước tiếp theo
  static bool needsMe(Rental r, bool isOwner) {
    if (isOwner) {
      return r.status == 'Pending' ||
          r.status == 'Returned' ||
          r.ownerCanFinalizeDamage ||
          r.ownerCanCancel ||
          (r.status == 'WaitingForPickup' && (!r.isShipping || r.shippingOrderCode == null));
    }
    return r.status == 'Approved' ||
        r.status == 'WaitingForPickup' ||
        r.status == 'Rented' ||
        r.status == 'DamageClaimed' ||
        r.renterCanForceComplete;
  }

  // Thẻ kiểu "Deals": nhãn trạng thái · ảnh giữa · tên giữa · mô tả xám · giá · nút đen "Xem chi tiết"
  Widget _card(Rental r, bool isOwner) {
    return RcCard(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      onTap: () => _open(r, isOwner),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusBadge(rentalStatusLabels[r.status] ?? r.status, statusColor(r.status)),
              const Spacer(),
              if (needsMe(r, isOwner))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: Text(tr('Cần bạn xử lý'), style: kText(12, FontWeight.w400, color: Colors.white)),
                )
              else
                Text(tr('Đơn #{0}', [r.id]), style: kSub12),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: ItemThumb(
              categoryName: r.categoryName,
              imageUrl: r.itemImageUrl,
              size: 168,
              height: 140,
              radius: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            r.itemName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kText(18, FontWeight.w400),
          ),
          const SizedBox(height: 4),
          Text(
            '${fmtDate(r.startDate)} – ${fmtDate(r.endDate)} · ${tr('{0} ngày', [r.days])}\n'
            '${isOwner ? tr('Người thuê: {0}', [r.renterName]) : tr('Chủ đồ: {0}', [r.ownerName])}',
            textAlign: TextAlign.center,
            style: kText(13, FontWeight.w300, lh: 19, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: formatVnd(r.totalPrice), style: kText(18, FontWeight.w600)),
                TextSpan(
                  text: '  ${tr('Cọc {0}', [formatVnd(r.depositAmount)])}',
                  style: kText(12, FontWeight.w300, color: AppColors.muted),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => _open(r, isOwner), child: Text(tr('Xem chi tiết'))),
        ],
      ),
    );
  }
}

/// Chi tiết một đơn thuê (mở từ thẻ ở danh sách): các khối trắng như "Pickup & Return" của mẫu,
/// các nút thao tác theo bước nằm ở thanh đáy.
class RentalDetailScreen extends StatefulWidget {
  final Rental rental;
  final bool isOwner;
  const RentalDetailScreen({super.key, required this.rental, required this.isOwner});

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  late Rental _rental = widget.rental;
  final _busy = <int>{}; // đơn đang gửi thao tác, khóa nút để không bấm 2 lần

  // Api chưa có lấy riêng 1 đơn: tải danh sách đơn của mình rồi lấy đúng đơn này
  Future<void> _reload() async {
    try {
      final list = await RentalService().getMyRentals();
      final fresh = list.where((x) => x.id == _rental.id).firstOrNull;
      if (fresh != null && mounted) {
        setState(() {
          _rental = fresh;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
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

  Future<void> _confirmAndAct(
    Rental r,
    String action,
    String doneText, {
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) async {
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
          message: tr(
            'Cần {0}, ví của bạn có {1}.\nThanh toán phần còn thiếu qua VNPay (thẻ ATM / QR ngân hàng). Xong, đơn được trả tiền tự động.',
            [formatVnd(r.amountToPay), formatVnd(wallet.availableBalance)],
          ),
          confirmText: tr('Trả qua VNPay'),
        );
        if (ok) await _payWithVnPay(r);
        return;
      }
      if (!mounted) return;
      final topUp = await confirmDialog(
        context,
        title: tr('Số dư không đủ'),
        message: tr('Cần {0}, ví của bạn có {1}.\nNạp thêm ít nhất {2} để thanh toán.', [
          formatVnd(r.amountToPay),
          formatVnd(wallet.availableBalance),
          formatVnd(r.amountToPay - wallet.availableBalance),
        ]),
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
      message: tr('Trừ {0} từ ví (thuê {1} + cọc {2}).\nSố dư sau thanh toán: {3}.', [
        formatVnd(r.amountToPay),
        formatVnd(r.totalPrice),
        formatVnd(r.depositAmount),
        formatVnd(wallet.availableBalance - r.amountToPay),
      ]),
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
      damage > 0
          ? tr('Đã gửi yêu cầu bồi thường. Chờ người thuê đồng ý (tối đa {0} ngày).', [AppConfig.renterResponseDays])
          : tr('Đơn đã hoàn tất. Tiền đã vào ví.'),
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
    await _run(
      r,
      () => RentalService().dispute(r.id, text),
      tr('Đã gửi khiếu nại. Quản trị viên sẽ xem ảnh biên bản và phân xử.'),
    );
  }

  Future<void> _payWithVnPay(Rental r) async {
    setState(() => _busy.add(r.id));
    try {
      final payment = await PaymentService().createVnPay(rentalId: r.id);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => VnPayScreen(paymentUrl: payment.paymentUrl)));
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
    await _run(
      r,
      () => ShippingService().createShipment(r.id, grams),
      tr('Đã tạo đơn GHN. Shipper sẽ đến lấy hàng tại địa chỉ cửa hàng.'),
    );
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
    await _run(
      r,
      () => RentalService().cancel(r.id, reason: reason),
      tr('Đã từ chối nhận. {0} đã hoàn vào ví.', [formatVnd(r.amountToPay)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _rental;
    final isOwner = widget.isOwner;
    final hint = _hint(r, isOwner);
    final all = _actions(r, isOwner);
    final rows = all.whereType<ActionRow>().toList();
    final buttons = all.where((b) => b is! ActionRow).toList();
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Đơn #{0}', [r.id]))),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            _itemCard(r, isOwner),
            if (hint != null) ...[
              const SizedBox(height: 12),
              _section(tr('Bước tiếp theo'), [NoticeBox(hint, color: statusColor(r.status))]),
            ],
            const SizedBox(height: 12),
            _section(tr('Tiến trình'), [_timeline(r)]),
            const SizedBox(height: 12),
            _section(tr('Thời gian thuê'), [
              Row(
                children: [
                  Expanded(child: _dateBox(tr('Ngày nhận'), r.startDate)),
                  const SizedBox(width: 10),
                  Expanded(child: _dateBox(tr('Ngày trả'), r.endDate)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [
                  tr('{0} ngày', [r.days]),
                  r.isShipping ? tr('Giao qua GHN') : tr('Gặp trực tiếp'),
                  if (r.shiftedDays > 0) tr('Hạn trả đã lùi {0} ngày', [r.shiftedDays]),
                ].join(' · '),
                style: kBody12Hint,
              ),
            ]),
            const SizedBox(height: 12),
            _section(tr('Chi tiết giá'), [
              InfoRow(tr('Giá thuê / ngày'), formatVnd(r.pricePerDay)),
              InfoRow(
                tr('Tiền thuê ({0} ngày)', [r.days]),
                formatVnd(r.totalPrice + r.discountAmount + r.lateDeliveryRefund),
              ),
              if (r.discountAmount > 0)
                InfoRow(tr('Ưu đãi thuê dài ngày (-{0}%)', [r.discountPercent]), '-${formatVnd(r.discountAmount)}'),
              InfoRow(tr('Tiền cọc (được hoàn lại)'), formatVnd(r.depositAmount)),
              if (r.lateDeliveryRefund > 0) InfoRow(tr('Hoàn vì đồ đến trễ'), '-${formatVnd(r.lateDeliveryRefund)}'),
              if (r.damageAmount > 0)
                InfoRow(tr('Trừ cọc bồi thường'), formatVnd(r.damageAmount), valueColor: AppColors.error),
              if (isOwner) InfoRow(tr('Phí nền tảng'), '${r.feeText}%'),
              const Divider(height: 18),
              InfoRow(
                isOwner ? tr('Tổng tiền thuê') : tr('Tổng thanh toán'),
                formatVnd(isOwner ? r.totalPrice : r.amountToPay),
                bold: true,
              ),
            ]),
            if ((r.requestNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(tr('Lời nhắn của người thuê'), [
                Text(r.requestNote!, style: kText(14, FontWeight.w300, lh: 21)),
              ]),
            ],
            if (r.damageAmount > 0 || (r.disputeReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(tr('Bồi thường'), [
                if ((r.damageNote ?? '').isNotEmpty)
                  Text(tr('Lý do trừ cọc: {0}', [r.damageNote]), style: kText(14, FontWeight.w300, lh: 21)),
                if ((r.disputeReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(tr('Khiếu nại: {0}', [r.disputeReason]), style: kText(14, FontWeight.w300, lh: 21)),
                ],
                if ((r.resolutionNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(tr('Kết luận: {0}', [r.resolutionNote]), style: kText(14, FontWeight.w400, lh: 21)),
                ],
              ]),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              RcMenuGroup(
                label: tr('Biên bản và giao nhận'),
                children: [for (final a in rows) RcMenuItem(icon: a.icon, title: a.label, onTap: a.onTap)],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: buttons.isEmpty
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: buttons[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Khối trắng có nhãn xám phía trên
  Widget _section(String label, List<Widget> children) {
    return RcCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: kText(14, FontWeight.w300, color: AppColors.muted)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  // Món đồ: nhãn trạng thái, ảnh lớn ở giữa, tên, người còn lại của đơn
  Widget _itemCard(Rental r, bool isOwner) {
    return RcCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusBadge(rentalStatusLabels[r.status] ?? r.status, statusColor(r.status)),
              const Spacer(),
              Text(fmtDateTime(r.requestedAt), style: kSub12),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: ItemThumb(
              categoryName: r.categoryName,
              imageUrl: r.itemImageUrl,
              size: 210,
              height: 170,
              radius: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(r.itemName, textAlign: TextAlign.center, style: kText(20, FontWeight.w400, lh: 26)),
          const SizedBox(height: 4),
          Text(
            isOwner ? tr('Người thuê: {0}', [r.renterName]) : tr('Chủ đồ: {0}', [r.ownerName]),
            textAlign: TextAlign.center,
            style: kText(13, FontWeight.w300, color: AppColors.muted),
          ),
          if ((r.cancelReason ?? '').isNotEmpty && ['Cancelled', 'Rejected'].contains(r.status)) ...[
            const SizedBox(height: 10),
            NoticeBox(tr('Lý do: {0}', [r.cancelReason]), color: AppColors.error),
          ],
        ],
      ),
    );
  }

  // Ô ngày viền bo tròn như ô ngày giờ của "Pickup & Return"
  Widget _dateBox(String label, DateTime date) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kSub12),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(fmtDate(date), style: kText(15, FontWeight.w400))),
              const Icon(Icons.calendar_today_outlined, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  // Dòng tiến trình: chấm đen là bước đã qua, chấm viền là bước chưa tới
  Widget _timeline(Rental r) {
    final closed = ['Cancelled', 'Rejected'].contains(r.status);
    final stage = switch (r.status) {
      'Pending' => 1,
      'Approved' => 2,
      'WaitingForPickup' => 3,
      'Rented' => 4,
      'Returned' || 'DamageClaimed' || 'Disputed' => 5,
      'Completed' => 6,
      _ => 1,
    };
    final steps = closed
        ? [(tr('Gửi yêu cầu'), r.requestedAt), (rentalStatusLabels[r.status] ?? r.status, null)]
        : [
            (tr('Gửi yêu cầu'), r.requestedAt),
            (tr('Chủ đồ duyệt'), r.approvedAt),
            (tr('Thanh toán'), null),
            (tr('Nhận đồ'), r.receivedAt),
            (tr('Trả đồ'), r.returnedAt),
            (tr('Hoàn tất'), null),
          ];
    final doneCount = closed ? steps.length : stage;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < doneCount
                              ? (closed && i == steps.length - 1 ? AppColors.error : AppColors.primary)
                              : Colors.white,
                          border: Border.all(color: i < doneCount ? Colors.transparent : AppColors.border, width: 2),
                        ),
                        child: i < doneCount ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(width: 2, color: i < doneCount - 1 ? AppColors.primary : AppColors.border),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 14 : 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            steps[i].$1,
                            style: kText(
                              14,
                              i < doneCount ? FontWeight.w400 : FontWeight.w300,
                              color: i < doneCount ? AppColors.ink : AppColors.muted,
                            ),
                          ),
                        ),
                        if (steps[i].$2 != null) Text(fmtDateTime(steps[i].$2!), style: kSub12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Câu hướng dẫn bước tiếp theo, theo luồng trong RentalService.cs.
  String? _hint(Rental r, bool isOwner) {
    if (isOwner) {
      return switch (r.status) {
        'Pending' => tr('Có người muốn thuê. Duyệt hoặc từ chối yêu cầu.'),
        'Approved' =>
          r.ownerCanCancel
              ? tr('Người thuê chưa thanh toán sau {0} giờ. Bạn có thể hủy đơn.', [AppConfig.paymentTimeoutHours])
              : tr('Chờ người thuê thanh toán (trong {0} giờ). Bạn có thể lập biên bản trước.', [
                  AppConfig.paymentTimeoutHours,
                ]),
        'WaitingForPickup' =>
          !r.isShipping
              ? tr('Người thuê đã thanh toán. Chụp ảnh biên bản lúc giao rồi hẹn gặp người thuê để giao đồ.')
              : r.shippingOrderCode == null
              ? tr('Người thuê đã thanh toán. Chụp ảnh biên bản lúc giao, đóng gói rồi bấm "Gửi hàng GHN".')
              : tr('Đã gửi GHN (mã {0}). Chờ người thuê nhận hàng.', [r.shippingOrderCode]),
        'Rented' => tr('Đang cho thuê, hạn trả {0}.{1}', [
          fmtDate(r.endDate),
          r.shiftedDays > 0 ? tr(' Hạn trả đã lùi {0} ngày vì đồ đến tay trễ.', [r.shiftedDays]) : '',
        ]),
        'Cancelled' => r.cancelReason == null ? null : tr('Đơn đã hủy. Lý do: {0}', [r.cancelReason]),
        'Returned' => tr(
          'Người thuê đã trả đồ. Trong {0} ngày, chụp ảnh lập biên bản nhận lại (AI so sánh với lúc giao) rồi bấm "Hoàn tất".',
          [AppConfig.ownerInspectionDays],
        ),
        'DamageClaimed' =>
          r.ownerCanFinalizeDamage
              ? tr('Người thuê không phản hồi sau {0} ngày. Bạn có thể chốt mức bồi thường.', [
                  AppConfig.renterResponseDays,
                ])
              : tr('Chờ người thuê đồng ý hoặc khiếu nại mức bồi thường (tối đa {0} ngày).', [
                  AppConfig.renterResponseDays,
                ]),
        'Disputed' => tr('Người thuê khiếu nại: {0}. Quản trị viên đang phân xử.', [r.disputeReason ?? '']),
        'Completed' =>
          r.damageAmount > 0
              ? tr('Đã hoàn tất. Tiền thuê (trừ {2}% phí) và {0} bồi thường đã vào ví.{1}', [
                  formatVnd(r.damageAmount),
                  r.resolutionNote != null ? tr(' Kết luận: {0}', [r.resolutionNote]) : '',
                  r.feeText,
                ])
              : tr('Đã hoàn tất. Tiền thuê (trừ {0}% phí) đã vào ví của bạn.', [r.feeText]),
        _ => null,
      };
    }
    return switch (r.status) {
      'Pending' => tr('Đang chờ chủ đồ duyệt.'),
      'Approved' => tr('Chủ đồ đã duyệt! Thanh toán {0} trong {1} giờ để giữ đơn.', [
        formatVnd(r.amountToPay),
        AppConfig.paymentTimeoutHours,
      ]),
      'WaitingForPickup' => tr(
        '{0}Khi nhận: vào "Biên bản" chụp ảnh đối chiếu, đúng đồ thì bấm "Đã nhận đồ"; sai món hoặc hư hỏng thì bấm "Từ chối nhận" để được hoàn 100%.',
        [
          r.isShipping
              ? (r.shippingOrderCode == null
                    ? tr('Chờ chủ đồ gửi hàng GHN. ')
                    : tr('Đang giao (mã {0}). ', [r.shippingOrderCode]))
              : tr('Hẹn gặp chủ đồ để nhận đồ. '),
        ],
      ),
      'Rented' => tr('Bạn đang thuê, hạn trả {0}. Trả đồ xong bấm "Đã trả đồ".{1}{2}', [
        fmtDate(r.endDate),
        r.shiftedDays > 0 ? tr(' Hạn trả đã lùi {0} ngày vì đồ đến tay trễ.', [r.shiftedDays]) : '',
        r.lateDeliveryRefund > 0 ? tr(' Đã hoàn {0} tiền thuê vì đồ đến trễ.', [formatVnd(r.lateDeliveryRefund)]) : '',
      ]),
      'Cancelled' => r.cancelReason == null ? null : tr('Đơn đã hủy. Lý do: {0}', [r.cancelReason]),
      'Returned' =>
        r.renterCanForceComplete
            ? tr('Chủ đồ chưa kiểm tra sau {0} ngày. Bạn có thể tự hoàn tất để nhận lại đủ cọc.', [
                AppConfig.ownerInspectionDays,
              ])
            : tr('Chờ chủ đồ kiểm tra (tối đa {0} ngày). Tiền cọc sẽ hoàn vào ví khi đơn hoàn tất.', [
                AppConfig.ownerInspectionDays,
              ]),
      'DamageClaimed' => tr(
        'Chủ đồ đề nghị trừ {0} tiền cọc. Xem ảnh biên bản rồi đồng ý hoặc khiếu nại trong {1} ngày.',
        [formatVnd(r.damageAmount), AppConfig.renterResponseDays],
      ),
      'Disputed' => tr('Bạn đã khiếu nại. Quản trị viên đang xem ảnh biên bản để phân xử.'),
      'Completed' =>
        r.damageAmount > 0
            ? tr('Đã hoàn tất. Trừ {0} bồi thường, hoàn {1} cọc vào ví.{2}', [
                formatVnd(r.damageAmount),
                formatVnd(r.depositAmount - r.damageAmount),
                r.resolutionNote != null ? tr(' Kết luận: {0}', [r.resolutionNote]) : '',
              ])
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
        ActionRow(
          icon: Icons.fact_check_outlined,
          label: tr('Biên bản'),
          onTap: guard(() async {
            final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => ConditionReportScreen(rental: r, isOwner: isOwner),
              ),
            );
            if (created == true) await _reload();
          }),
        ),
      if (['WaitingForPickup', 'Rented', 'Returned', 'DamageClaimed', 'Disputed', 'Completed'].contains(s))
        ActionRow(
          icon: r.isShipping ? Icons.local_shipping_outlined : Icons.timeline,
          label: tr('Giao nhận'),
          onTap: guard(() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShippingScreen(rental: r)))),
        ),

      // ===== Người thuê =====
      if (!isOwner && s == 'WaitingForPickup')
        OutlinedButton(onPressed: guard(() => _rejectPickup(r)), child: Text(tr('Từ chối nhận'))),
      if (!isOwner && ['Pending', 'Approved'].contains(s))
        OutlinedButton(
          onPressed: guard(
            () => _confirmAndAct(
              r,
              'cancel',
              tr('Đã hủy đơn'),
              title: tr('Hủy đơn #{0}?', [r.id]),
              message: s == 'WaitingForPickup'
                  ? tr('Bạn đã thanh toán, {0} sẽ được hoàn 100% vào ví.', [formatVnd(r.amountToPay)])
                  : tr('Yêu cầu thuê sẽ bị hủy.'),
              confirmText: tr('Hủy đơn'),
              danger: true,
            ),
          ),
          child: Text(tr('Hủy đơn')),
        ),
      if (!isOwner && s == 'Approved') FilledButton(onPressed: guard(() => _pay(r)), child: Text(tr('Thanh toán'))),
      if (!isOwner && s == 'WaitingForPickup')
        FilledButton(
          onPressed: guard(
            () => _confirmAndAct(
              r,
              'pickup',
              tr('Đã xác nhận nhận đồ. Nhớ trả đúng hạn.'),
              title: tr('Bạn đã nhận đồ?'),
              message: tr(
                'Chỉ bấm khi đã cầm đồ trên tay và thấy đúng như ảnh biên bản lúc giao. Không đúng thì đừng nhận, có thể hủy đơn để được hoàn tiền.',
              ),
              confirmText: tr('Đã nhận đồ'),
            ),
          ),
          child: Text(tr('Đã nhận đồ')),
        ),
      if (!isOwner && r.renterCanForceComplete)
        FilledButton(
          onPressed: guard(
            () => _run(r, () => RentalService().complete(r.id), tr('Đơn đã hoàn tất, tiền cọc đã hoàn vào ví.')),
          ),
          child: Text(tr('Tự hoàn tất')),
        ),
      if (!isOwner && s == 'DamageClaimed') ...[
        OutlinedButton(onPressed: guard(() => _dispute(r)), child: Text(tr('Khiếu nại'))),
        FilledButton(
          onPressed: guard(
            () => _confirmAndAct(
              r,
              'accept-damage',
              tr('Đã đồng ý. Phần cọc còn lại đã hoàn vào ví.'),
              title: tr('Đồng ý trừ {0}?', [formatVnd(r.damageAmount)]),
              message: tr('Bạn nhận lại {0} tiền cọc. Không hoàn tác được.', [
                formatVnd(r.depositAmount - r.damageAmount),
              ]),
              confirmText: tr('Đồng ý'),
            ),
          ),
          child: Text(tr('Đồng ý')),
        ),
      ],
      if (!isOwner && s == 'Rented')
        FilledButton(
          onPressed: guard(
            () => _confirmAndAct(
              r,
              'return',
              tr('Đã báo trả đồ. Chờ chủ đồ kiểm tra.'),
              title: tr('Bạn đã trả đồ?'),
              message: tr('Chỉ bấm khi đã giao lại đồ cho chủ đồ.'),
              confirmText: tr('Đã trả'),
            ),
          ),
          child: Text(tr('Đã trả đồ')),
        ),

      // ===== Chủ đồ =====
      if (isOwner && s == 'Pending') ...[
        OutlinedButton(
          onPressed: guard(
            () => _confirmAndAct(
              r,
              'reject',
              tr('Đã từ chối yêu cầu'),
              title: tr('Từ chối yêu cầu?'),
              message: tr('Người thuê sẽ thấy đơn bị từ chối.'),
              confirmText: tr('Từ chối'),
              danger: true,
            ),
          ),
          child: Text(tr('Từ chối')),
        ),
        FilledButton(
          onPressed: guard(() => _act(r, 'approve', tr('Đã duyệt. Chờ người thuê thanh toán.'))),
          child: Text(tr('Duyệt')),
        ),
      ],
      if (isOwner && r.ownerCanCancel)
        OutlinedButton(
          onPressed: guard(
            () => _confirmAndAct(
              r,
              'cancel',
              tr('Đã hủy đơn'),
              title: tr('Hủy đơn #{0}?', [r.id]),
              message: tr('Người thuê chưa thanh toán sau {0} giờ.', [AppConfig.paymentTimeoutHours]),
              confirmText: tr('Hủy đơn'),
              danger: true,
            ),
          ),
          child: Text(tr('Hủy đơn')),
        ),
      if (isOwner && s == 'Returned') FilledButton(onPressed: guard(() => _complete(r)), child: Text(tr('Hoàn tất'))),
      if (isOwner && s == 'WaitingForPickup' && r.isShipping && r.shippingOrderCode == null)
        FilledButton.icon(
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          onPressed: guard(() => _ship(r)),
          label: Text(tr('Gửi hàng GHN')),
        ),
      if (isOwner && r.ownerCanFinalizeDamage)
        FilledButton(
          onPressed: guard(
            () => _confirmAndAct(
              r,
              'complete',
              tr('Đã chốt bồi thường. Tiền đã vào ví.'),
              title: tr('Chốt bồi thường {0}?', [formatVnd(r.damageAmount)]),
              message: tr('Người thuê không phản hồi sau {0} ngày nên áp dụng mức bạn đã đề nghị.', [
                AppConfig.renterResponseDays,
              ]),
              confirmText: tr('Chốt'),
            ),
          ),
          child: Text(tr('Chốt bồi thường')),
        ),
    ];
    return buttons;
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
      padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Text(tr('Hoàn tất đơn #{0}', [r.id]), style: kText(20, FontWeight.w400))),
            const SizedBox(height: 16),
            if (widget.report.hasAi) ...[AiReviewBox(report: widget.report), const SizedBox(height: 12)],
            LabeledField(
              label: tr('Trừ cọc bồi thường'),
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  suffixText: tr('đ'),
                  helperText: tr('Từ 0 đến {0}. Nhập 0 nếu đồ không hư hỏng.', [formatVnd(r.depositAmount)]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: tr('Lý do trừ cọc (bắt buộc nếu trừ)'),
              child: TextField(controller: _note, maxLines: 2),
            ),
            const SizedBox(height: 24),
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
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Đóng'))),
        FilledButton(onPressed: () => Navigator.pop(context, _reason.text.trim()), child: Text(widget.confirmText)),
      ],
    );
  }
}
