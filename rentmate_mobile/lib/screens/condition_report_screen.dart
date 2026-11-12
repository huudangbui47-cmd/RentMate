import 'package:flutter/material.dart';

import '../services/condition_report_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';

/// Xem biên bản của một đơn; chủ đồ lập biên bản khi đơn đúng trạng thái.
class ConditionReportScreen extends StatefulWidget {
  final Rental rental;
  final bool isOwner;
  const ConditionReportScreen({super.key, required this.rental, required this.isOwner});

  @override
  State<ConditionReportScreen> createState() => _ConditionReportScreenState();
}

class _ConditionReportScreenState extends State<ConditionReportScreen> {
  late Future<List<ConditionReport>> _future =
      ConditionReportService().getReports(widget.rental.id);
  final _description = TextEditingController();
  final _imageUrls = TextEditingController();
  String _condition = 'Good';
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _imageUrls.dispose();
    super.dispose();
  }

  // Loại biên bản chủ đồ được lập lúc này, theo kiểm tra trong ConditionReportService.cs.
  String? _typeToCreate(List<ConditionReport> existing) {
    if (!widget.isOwner) return null;
    final s = widget.rental.status;
    final has = existing.map((r) => r.reportType).toSet();
    if ((s == 'Approved' || s == 'WaitingForPickup') && !has.contains('BeforeRental')) {
      return 'BeforeRental';
    }
    if (s == 'Returned' && !has.contains('AfterRental')) return 'AfterRental';
    return null;
  }

  Future<void> _submit(String type) async {
    setState(() => _saving = true);
    try {
      await ConditionReportService().create(
        rentalId: widget.rental.id,
        reportType: type,
        condition: _condition,
        description: _description.text.trim(),
        imageUrls: _imageUrls.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(type == 'BeforeRental'
              ? 'Đã lập biên bản. Giờ có thể bấm "Đã giao đồ".'
              : 'Đã lập biên bản. Giờ có thể bấm "Hoàn tất".')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Biên bản · ${widget.rental.itemName}')),
      body: FutureBuilder<List<ConditionReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snap.error.toString().replaceFirst('Exception: ', '')),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => setState(() {
                      _future = ConditionReportService().getReports(widget.rental.id);
                    }),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          final reports = snap.data!;
          final type = _typeToCreate(reports);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (reports.isEmpty && type == null)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('Đơn này chưa có biên bản nào')),
                ),
              for (final r in reports) _reportCard(r),
              if (type != null) ..._form(type),
            ],
          );
        },
      ),
    );
  }

  Widget _reportCard(ConditionReport r) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reportTypeLabels[r.reportType] ?? r.reportType,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_fmt(r.createdAt), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text('Tình trạng: ${conditionLabels[r.condition] ?? r.condition}'),
              if (r.description.isNotEmpty) Text('Mô tả: ${r.description}'),
              for (final url in r.imageUrls)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text('Không mở được ảnh: $url',
                          style: const TextStyle(color: Colors.grey)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  List<Widget> _form(String type) {
    const border = OutlineInputBorder();
    return [
      const SizedBox(height: 8),
      Text('Lập ${reportTypeLabels[type]!.toLowerCase()}',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        type == 'BeforeRental'
            ? 'Ghi lại tình trạng đồ trước khi giao cho người thuê. Bắt buộc trước khi bấm "Đã giao đồ".'
            : 'Ghi lại tình trạng đồ khi nhận lại. Bắt buộc trước khi bấm "Hoàn tất".',
        style: const TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _condition,
        decoration: const InputDecoration(labelText: 'Tình trạng', border: border),
        items: [
          for (final e in conditionLabels.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => _condition = v!),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _description,
        maxLines: 3,
        decoration: const InputDecoration(
            labelText: 'Mô tả (vết xước, phụ kiện đi kèm...)', border: border),
      ),
      const SizedBox(height: 16),
      // shortcut: API chỉ nhận link ảnh, chưa có upload; khi nhóm thêm API upload thì đổi sang chọn ảnh từ máy.
      TextField(
        controller: _imageUrls,
        maxLines: 3,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Link ảnh (không bắt buộc, mỗi dòng một link)',
          border: border,
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _saving ? null : () => _submit(type),
        child: _saving
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Lưu biên bản'),
      ),
    ];
  }
}
