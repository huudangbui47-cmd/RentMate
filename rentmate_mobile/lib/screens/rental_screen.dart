import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/shipping_service.dart';
import '../services/wallet_service.dart';
import '../theme.dart';
import '../widgets/range_calendar.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import '../l10n/l10n.dart';
import '../services/config_service.dart';

class RentalScreen extends StatefulWidget {
  final Item item;
  final DateTimeRange? initialRange; // ngày đã chọn ở màn chi tiết
  const RentalScreen({super.key, required this.item, this.initialRange});

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen> {
  final _note = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  late DateTimeRange? _range = widget.initialRange;
  bool _loading = false;
  WalletSummary? _wallet;

  // Giao nhận
  bool _shippingEnabled = false;
  bool _ship = false;
  List<AddressOption> _provinces = [];
  List<AddressOption> _districts = [];
  List<AddressOption> _wards = [];
  AddressOption? _province;
  AddressOption? _district;
  AddressOption? _ward;

  @override
  void initState() {
    super.initState();
    // Số dư chỉ để tham khảo; lỗi thì bỏ qua
    WalletService()
        .getSummary()
        .then((w) {
          if (mounted) setState(() => _wallet = w);
        })
        .catchError((_) {});
    ShippingService().isEnabled().then((on) {
      if (mounted) setState(() => _shippingEnabled = on);
    });
    // Điền sẵn tên và số điện thoại của tài khoản
    AccountService()
        .getProfile()
        .then((p) {
          if (!mounted) return;
          if (_name.text.isEmpty) _name.text = p.fullName;
          if (_phone.text.isEmpty) _phone.text = p.phoneNumber;
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_note, _name, _phone, _street]) {
      c.dispose();
    }
    super.dispose();
  }

  // API tính cả ngày nhận lẫn ngày trả: thuê 12 → 14 = 3 ngày.
  int get _days => _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;

  Future<void> _pickDates() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showRangeCalendar(
      context,
      firstDate: today,
      // Khớp giới hạn của Api: bắt đầu trong 90 ngày tới, mỗi đơn tối đa 30 ngày
      lastDate: today.add(Duration(days: AppConfig.maxDaysAhead + AppConfig.maxRentalDays - 1)),
      initial: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _chooseShip(bool ship) async {
    setState(() {
      _ship = ship;
    });
    if (ship && _provinces.isEmpty) {
      try {
        final list = await ShippingService().provinces();
        if (mounted) {
          setState(() {
            _provinces = list;
          });
        }
      } catch (e) {
        if (mounted) showSnack(context, errorText(e), error: true);
      }
    }
  }

  Future<void> _pickProvince(AddressOption? p) async {
    setState(() {
      _province = p;
      _district = null;
      _ward = null;
      _districts = [];
      _wards = [];
    });
    if (p == null) return;
    try {
      final list = await ShippingService().districts(p.id);
      if (mounted) {
        setState(() {
          _districts = list;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _pickDistrict(AddressOption? d) async {
    setState(() {
      _district = d;
      _ward = null;
      _wards = [];
    });
    if (d == null) return;
    try {
      final list = await ShippingService().wards(d.id);
      if (mounted) {
        setState(() {
          _wards = list;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _submit() async {
    if (_range == null) {
      showSnack(context, tr('Vui lòng chọn ngày thuê'), error: true);
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    if (_range!.start.isAfter(today.add(Duration(days: AppConfig.maxDaysAhead)))) {
      showSnack(context, tr('Chỉ đặt thuê trước tối đa {0} ngày', [AppConfig.maxDaysAhead]), error: true);
      return;
    }
    if (_days > AppConfig.maxRentalDays) {
      showSnack(context, tr('Mỗi đơn thuê tối đa {0} ngày', [AppConfig.maxRentalDays]), error: true);
      return;
    }
    ShipTo? shipTo;
    if (_ship) {
      final phone = _phone.text.trim();
      if (_name.text.trim().isEmpty || _street.text.trim().isEmpty || _ward == null) {
        showSnack(context, tr('Nhập đủ tên, số nhà/đường và chọn tỉnh, quận, phường'), error: true);
        return;
      }
      if (!RegExp(r'^0\d{9,10}$').hasMatch(phone)) {
        showSnack(context, tr('Số điện thoại người nhận không hợp lệ'), error: true);
        return;
      }
      shipTo = ShipTo(
        name: _name.text.trim(),
        phone: phone,
        address: _street.text.trim(),
        districtId: int.parse(_district!.id),
        wardCode: _ward!.id,
        areaText: '${_ward!.name}, ${_district!.name}, ${_province!.name}',
      );
    }
    setState(() => _loading = true);
    try {
      await RentalService().createRental(
        itemId: widget.item.id,
        startDate: _range!.start,
        endDate: _range!.end,
        note: _note.text.trim(),
        shipTo: shipTo,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Theo tờ "Pickup & Return" của mẫu: các khối trắng có nhãn xám, ô ngày viền bo tròn,
  // thanh đáy trắng có tổng tiền + nút đen.
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final discount = item.discountFor(_days);
    final rentTotal = item.rentFor(_days);
    final total = rentTotal + item.depositAmount;
    final notEnough = _wallet != null && _range != null && _wallet!.availableBalance < total;
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Đặt thuê'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                // Món đồ: ảnh vuông hiện trọn, tên, khu vực, giá đậm
                RcCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ItemThumb(categoryName: item.categoryName, imageUrl: item.imageUrl, size: 84, radius: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kText(17, FontWeight.w400),
                            ),
                            const SizedBox(height: 4),
                            if (item.locationText != null) LocationText(item.locationText!, fontSize: 12),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: PriceText(formatVnd(item.pricePerDay), unit: tr(' /ngày'), fontSize: 16),
                                ),
                                Text(tr('Cọc {0}', [formatVnd(item.depositAmount)]), style: kSub12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Thời gian thuê: 2 ô viền "Ngày nhận" / "Ngày trả" như ô ngày giờ của mẫu
                _section(tr('Thời gian thuê'), [
                  Row(
                    children: [
                      Expanded(child: _dateBox(tr('Ngày nhận'), _range?.start)),
                      const SizedBox(width: 10),
                      Expanded(child: _dateBox(tr('Ngày trả'), _range?.end)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _range == null
                        ? tr('Kiểm tra kỹ ngày thuê trước khi gửi yêu cầu.')
                        : tr('{0} ngày · Kiểm tra kỹ ngày thuê trước khi gửi yêu cầu.', [_days]),
                    style: kBody12Hint,
                  ),
                  if (item.status == 'Rented') ...[
                    const SizedBox(height: 10),
                    NoticeBox(
                      tr('Đồ đang có người thuê. Hãy chọn khoảng ngày sau khi họ trả; chủ đồ sẽ xác nhận lịch.'),
                      color: AppColors.warning,
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                _section(tr('Nhận đồ'), [
                  _shipOption(false, Icons.handshake_outlined, tr('Gặp trực tiếp'), true),
                  _shipOption(true, Icons.local_shipping_outlined, tr('Giao qua GHN'), _shippingEnabled),
                  const SizedBox(height: 8),
                  if (!_shippingEnabled)
                    NoticeBox(tr('Giao hàng GHN chưa được bật, hai bên hẹn gặp để giao nhận.'))
                  else if (!_ship)
                    NoticeBox(tr('Hai bên hẹn gặp để giao nhận. Ngày thuê tính từ lúc bạn bấm "Đã nhận đồ".'))
                  else ...[
                    NoticeBox(
                      tr('Chủ đồ gửi hàng qua GHN, RentMate trả phí ship. Ngày thuê tính từ lúc bạn nhận được hàng.'),
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: tr('Tên người nhận'),
                      child: TextField(controller: _name),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: tr('Số điện thoại'),
                      child: TextField(controller: _phone, keyboardType: TextInputType.phone),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: tr('Tỉnh / thành'),
                      child: _dropdown(tr('Tỉnh / thành'), _provinces, _province, _pickProvince),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: tr('Quận / huyện'),
                      child: _dropdown(tr('Quận / huyện'), _districts, _district, _pickDistrict),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: tr('Phường / xã'),
                      child: _dropdown(tr('Phường / xã'), _wards, _ward, (w) async {
                        setState(() {
                          _ward = w;
                        });
                      }),
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: tr('Số nhà, tên đường'),
                      child: TextField(controller: _street),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                _section(tr('Lời nhắn cho chủ đồ (không bắt buộc)'), [
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    decoration: InputDecoration(hintText: tr('Ví dụ: Mình nhận đồ ở quận 1 được không?')),
                  ),
                ]),
                if (_range != null) ...[
                  const SizedBox(height: 12),
                  _section(tr('Chi tiết giá'), [
                    InfoRow(tr('Thời gian thuê'), tr('{0} ngày', [_days])),
                    InfoRow(tr('Giá thuê / ngày'), formatVnd(item.pricePerDay)),
                    InfoRow(tr('Tiền thuê ({0} ngày)', [_days]), formatVnd(item.pricePerDay * _days)),
                    if (discount > 0)
                      InfoRow(tr('Ưu đãi thuê dài ngày (-{0}%)', [item.discountPercent]), '-${formatVnd(discount)}'),
                    InfoRow(tr('Tiền cọc (được hoàn lại)'), formatVnd(item.depositAmount)),
                    if (_wallet != null)
                      InfoRow(
                        tr('Số dư ví hiện tại'),
                        formatVnd(_wallet!.availableBalance),
                        valueColor: notEnough ? AppColors.error : null,
                      ),
                    const Divider(height: 18),
                    InfoRow(tr('Cần thanh toán'), formatVnd(total), bold: true),
                    const SizedBox(height: 10),
                    NoticeBox(
                      notEnough
                          ? tr(
                              'Số dư ví chưa đủ. Sau khi chủ đồ duyệt, bạn có thể thanh toán phần còn thiếu qua VNPay.',
                            )
                          : tr('Chưa trừ tiền lúc này. Sau khi chủ đồ duyệt, bạn thanh toán bằng ví trong {0} giờ.', [
                              AppConfig.paymentTimeoutHours,
                            ]),
                      color: notEnough ? AppColors.warning : AppColors.primary,
                    ),
                  ]),
                ],
              ],
            ),
          ),
          _bottomBar(total),
        ],
      ),
    );
  }

  // Khối trắng có nhãn xám phía trên (như "Pickup & Return" của mẫu)
  Widget _section(String label, List<Widget> children) {
    return RcCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: kText(13, FontWeight.w300, color: AppColors.muted)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  // Ô ngày có viền bo tròn: nhãn xám nhỏ + ngày; chạm để mở lịch
  Widget _dateBox(String label, DateTime? date) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: _loading ? null : _pickDates,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kSub12),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null ? tr('Chọn ngày') : fmtDate(date),
                      style: kText(
                        15,
                        date == null ? FontWeight.w300 : FontWeight.w400,
                        color: date == null ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 17),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Thanh đáy trắng bo góc trên: tổng tiền + nút đen "Gửi yêu cầu thuê"
  Widget _bottomBar(num total) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_range == null ? tr('Chưa chọn ngày thuê') : tr('Tổng {0} ngày', [_days]), style: kSub12),
                    Text(_range == null ? '—' : formatVnd(total), style: kText(19, FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(
                width: 190,
                child: BusyButton(busy: _loading, onPressed: _submit, label: tr('Gửi yêu cầu thuê')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dòng chọn cách nhận đồ: icon tròn nền nhạt, chữ, nút chọn tròn đen.
  Widget _shipOption(bool value, IconData icon, String label, bool enabled) {
    final selected = _ship == value;
    return InkWell(
      onTap: !enabled || _loading ? null : () => _chooseShip(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Row(
            children: [
              RcIconCircle(icon, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: kText(15, FontWeight.w400))),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.border,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    List<AddressOption> options,
    AddressOption? value,
    Future<void> Function(AddressOption?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-${options.length}-${value?.id}'),
      initialValue: value?.id,
      isExpanded: true,
      hint: Text(tr('Chọn')),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o.id,
            child: Text(o.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: options.isEmpty || _loading ? null : (id) => onChanged(options.firstWhere((o) => o.id == id)),
    );
  }
}
