import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../services/rental_service.dart';

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

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // API tính cả ngày nhận lẫn ngày trả: thuê 12 → 14 = 3 ngày.
  int get _days =>
      _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;

  Future<void> _pickDates() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Chọn ngày thuê',
      saveText: 'Xong',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _submit() async {
    if (_range == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày thuê')));
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final rentTotal = item.pricePerDay * _days;
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt thuê')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(item.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${formatVnd(item.pricePerDay)} / ngày'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(_range == null
                ? 'Chọn ngày nhận – ngày trả'
                : '${_fmt(_range!.start)}  →  ${_fmt(_range!.end)}'),
            onPressed: _loading ? null : _pickDates,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho chủ đồ (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (_range != null) ...[
            _row('Số ngày thuê', '$_days ngày'),
            _row('Tiền thuê', formatVnd(rentTotal)),
            _row('Tiền cọc', formatVnd(item.depositAmount)),
            const Divider(),
            _row('Tổng dự kiến', formatVnd(rentTotal + item.depositAmount), bold: true),
            const Text('Số tiền chính xác do hệ thống tính khi chủ đồ duyệt.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
          ],
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Gửi yêu cầu thuê'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
