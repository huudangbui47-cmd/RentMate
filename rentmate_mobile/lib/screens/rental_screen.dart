import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ui.dart';

class RentalScreen extends StatefulWidget {
  final Item item;
  const RentalScreen({super.key, required this.item});

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen> {
  final _note = TextEditingController();
  DateTimeRange? _range;
  bool _loading = false;
  WalletSummary? _wallet;

  @override
  void initState() {
    super.initState();
    // Số dư chỉ để tham khảo; lỗi thì bỏ qua
    WalletService().getSummary().then((w) {
      if (mounted) setState(() => _wallet = w);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // API tính cả ngày nhận lẫn ngày trả: thuê 12 → 14 = 3 ngày.
  int get _days => _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;

  Future<void> _pickDates() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Chọn ngày nhận và ngày trả',
      saveText: 'Xong',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _submit() async {
    if (_range == null) {
      showSnack(context, 'Vui lòng chọn ngày thuê', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await RentalService().createRental(
        itemId: widget.item.id,
        startDate: _range!.start,
        endDate: _range!.end,
        note: _note.text.trim(),
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
      appBar: AppBar(title: const Text('Đặt thuê')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ItemThumb(categoryName: item.categoryName, imageUrl: item.imageUrl, size: 56),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${formatVnd(item.pricePerDay)} / ngày · cọc ${formatVnd(item.depositAmount)}'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Thời gian thuê', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(_range == null
                ? 'Chọn ngày nhận – ngày trả'
                : '${fmtDate(_range!.start)}  →  ${fmtDate(_range!.end)}  ($_days ngày)'),
            onPressed: _loading ? null : _pickDates,
          ),
          if (item.status == 'Rented') ...[
            const SizedBox(height: 8),
            const NoticeBox('Đồ đang có người thuê. Hãy chọn khoảng ngày sau khi họ trả; chủ đồ sẽ xác nhận lịch.',
                color: Color(0xFFE08A00)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lời nhắn cho chủ đồ (không bắt buộc)',
              hintText: 'Ví dụ: Mình nhận đồ ở quận 1 được không?',
            ),
          ),
          if (_range != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InfoRow('Tiền thuê ($_days ngày)', formatVnd(rentTotal)),
                    InfoRow('Tiền cọc (được hoàn lại)', formatVnd(item.depositAmount)),
                    const Divider(height: 20),
                    InfoRow('Cần thanh toán', formatVnd(total), bold: true, valueColor: scheme.primary),
                    if (_wallet != null)
                      InfoRow('Số dư ví hiện tại', formatVnd(_wallet!.availableBalance),
                          valueColor: notEnough ? scheme.error : null),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            NoticeBox(
              notEnough
                  ? 'Số dư ví chưa đủ. Bạn vẫn gửi yêu cầu được; sau khi chủ đồ duyệt, hãy nạp thêm tiền rồi thanh toán trong 24 giờ.'
                  : 'Chưa trừ tiền lúc này. Sau khi chủ đồ duyệt, bạn thanh toán bằng ví trong 24 giờ.',
              color: notEnough ? const Color(0xFFE08A00) : const Color(0xFF2563EB),
            ),
          ],
          const SizedBox(height: 24),
          BusyButton(busy: _loading, onPressed: _submit, label: 'Gửi yêu cầu thuê'),
        ],
      ),
    );
  }
}
