import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/shipping_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';
import '../l10n/l10n.dart';
import '../services/config_service.dart';

class RentalScreen extends StatefulWidget {
  final Item item;
  const RentalScreen({super.key, required this.item});

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen> {
  final _note = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  DateTimeRange? _range;
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
    WalletService().getSummary().then((w) {
      if (mounted) setState(() => _wallet = w);
    }).catchError((_) {});
    ShippingService().isEnabled().then((on) {
      if (mounted) setState(() => _shippingEnabled = on);
    });
    // Điền sẵn tên và số điện thoại của tài khoản
    AccountService().getProfile().then((p) {
      if (!mounted) return;
      if (_name.text.isEmpty) _name.text = p.fullName;
      if (_phone.text.isEmpty) _phone.text = p.phoneNumber;
    }).catchError((_) {});
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      // Khớp giới hạn của Api: bắt đầu trong 90 ngày tới, mỗi đơn tối đa 30 ngày
      lastDate: today.add(Duration(days: AppConfig.maxDaysAhead + AppConfig.maxRentalDays - 1)),
      initialDateRange: _range,
      helpText: tr('Chọn ngày nhận và ngày trả'),
      saveText: 'Xong',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _chooseShip(bool ship) async {
    setState(() { _ship = ship; });
    if (ship && _provinces.isEmpty) {
      try {
        final list = await ShippingService().provinces();
        if (mounted) setState(() { _provinces = list; });
      } catch (e) {
        if (mounted) showSnack(context, errorText(e), error: true);
      }
    }
  }

  Future<void> _pickProvince(AddressOption? p) async {
    setState(() { _province = p; _district = null; _ward = null; _districts = []; _wards = []; });
    if (p == null) return;
    try {
      final list = await ShippingService().districts(p.id);
      if (mounted) setState(() { _districts = list; });
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _pickDistrict(AddressOption? d) async {
    setState(() { _district = d; _ward = null; _wards = []; });
    if (d == null) return;
    try {
      final list = await ShippingService().wards(d.id);
      if (mounted) setState(() { _wards = list; });
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    final rentTotal = item.pricePerDay * _days;
    final total = rentTotal + item.depositAmount;
    final notEnough = _wallet != null && _range != null && _wallet!.availableBalance < total;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Đặt thuê'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ItemThumb(categoryName: item.categoryName, imageUrl: item.imageUrl, size: 56),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(tr('{0} / ngày · cọc {1}', [formatVnd(item.pricePerDay), formatVnd(item.depositAmount)])),
            ),
          ),
          const SizedBox(height: 16),
          Text(tr('Thời gian thuê'), style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(_range == null
                ? tr('Chọn ngày nhận – ngày trả')
                : tr('{0}  →  {1}  ({2} ngày)', [fmtDate(_range!.start), fmtDate(_range!.end), _days])),
            onPressed: _loading ? null : _pickDates,
          ),
          if (item.status == 'Rented') ...[
            const SizedBox(height: 8),
            NoticeBox(tr('Đồ đang có người thuê. Hãy chọn khoảng ngày sau khi họ trả; chủ đồ sẽ xác nhận lịch.'),
                color: Color(0xFFE08A00)),
          ],
          const SizedBox(height: 16),
          Text(tr('Nhận đồ'), style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, icon: Icon(Icons.handshake_outlined), label: Text(tr('Gặp trực tiếp'))),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(tr('Giao qua GHN')),
                enabled: _shippingEnabled,
              ),
            ],
            selected: {_ship},
            onSelectionChanged: _loading ? null : (v) => _chooseShip(v.first),
          ),
          const SizedBox(height: 8),
          if (!_shippingEnabled)
            NoticeBox(tr('Giao hàng GHN chưa được bật, hai bên hẹn gặp để giao nhận.'))
          else if (!_ship)
            NoticeBox(tr('Hai bên hẹn gặp để giao nhận. Ngày thuê tính từ lúc bạn bấm "Đã nhận đồ".'))
          else ...[
            NoticeBox(tr('Chủ đồ gửi hàng qua GHN, RentMate trả phí ship. Ngày thuê tính từ lúc bạn nhận được hàng.')),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: InputDecoration(labelText: tr('Tên người nhận'))),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('Số điện thoại')),
            ),
            const SizedBox(height: 12),
            _dropdown(tr('Tỉnh / thành'), _provinces, _province, _pickProvince),
            const SizedBox(height: 12),
            _dropdown(tr('Quận / huyện'), _districts, _district, _pickDistrict),
            const SizedBox(height: 12),
            _dropdown(tr('Phường / xã'), _wards, _ward, (w) async => setState(() { _ward = w; })),
            const SizedBox(height: 12),
            TextField(controller: _street, decoration: InputDecoration(labelText: tr('Số nhà, tên đường'))),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('Lời nhắn cho chủ đồ (không bắt buộc)'),
              hintText: tr('Ví dụ: Mình nhận đồ ở quận 1 được không?'),
            ),
          ),
          if (_range != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InfoRow(tr('Tiền thuê ({0} ngày)', [_days]), formatVnd(rentTotal)),
                    InfoRow(tr('Tiền cọc (được hoàn lại)'), formatVnd(item.depositAmount)),
                    const Divider(height: 20),
                    InfoRow(tr('Cần thanh toán'), formatVnd(total), bold: true, valueColor: scheme.primary),
                    if (_wallet != null)
                      InfoRow(tr('Số dư ví hiện tại'), formatVnd(_wallet!.availableBalance),
                          valueColor: notEnough ? scheme.error : null),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            NoticeBox(
              notEnough
                  ? tr('Số dư ví chưa đủ. Sau khi chủ đồ duyệt, bạn có thể thanh toán phần còn thiếu qua VNPay.')
                  : tr('Chưa trừ tiền lúc này. Sau khi chủ đồ duyệt, bạn thanh toán bằng ví trong {0} giờ.', [AppConfig.paymentTimeoutHours]),
              color: notEnough ? const Color(0xFFE08A00) : const Color(0xFF2563EB),
            ),
          ],
          const SizedBox(height: 24),
          BusyButton(busy: _loading, onPressed: _submit, label: tr('Gửi yêu cầu thuê')),
        ],
      ),
    );
  }

  Widget _dropdown(String label, List<AddressOption> options, AddressOption? value,
      Future<void> Function(AddressOption?) onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-${options.length}-${value?.id}'),
      initialValue: value?.id,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [for (final o in options) DropdownMenuItem(value: o.id, child: Text(o.name, overflow: TextOverflow.ellipsis))],
      onChanged: options.isEmpty || _loading
          ? null
          : (id) => onChanged(options.firstWhere((o) => o.id == id)),
    );
  }
}
