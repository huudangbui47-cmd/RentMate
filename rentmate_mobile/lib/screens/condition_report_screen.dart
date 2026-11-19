import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/condition_report_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../widgets/ui.dart';

/// Xem biên bản của một đơn; chủ đồ chụp ảnh lập biên bản, AI nhận xét ảnh.
class ConditionReportScreen extends StatefulWidget {
  final Rental rental;
  final bool isOwner;
  const ConditionReportScreen({super.key, required this.rental, required this.isOwner});

  @override
  State<ConditionReportScreen> createState() => _ConditionReportScreenState();
}

class _ConditionReportScreenState extends State<ConditionReportScreen> {
  late Future<List<ConditionReport>> _future = ConditionReportService().getReports(widget.rental.id);
  final _description = TextEditingController();
  final _images = <XFile>[];
  String _condition = 'Good';
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  // Loại biên bản chủ đồ được lập lúc này, theo kiểm tra trong ConditionReportService.cs.
  String? _typeToCreate(List<ConditionReport> existing) {
    if (!widget.isOwner) return null;
    final s = widget.rental.status;
    final has = existing.map((r) => r.reportType).toSet();
    if ((s == 'Approved' || s == 'WaitingForPickup') && !has.contains('BeforeRental')) return 'BeforeRental';
    if (s == 'Returned' && !has.contains('AfterRental')) return 'AfterRental';
    return null;
  }

  Future<void> _pickImages() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Thu nhỏ ảnh trước khi gửi: Api nhận JPG/PNG tối đa 2MB
    const maxSide = 1600.0;
    const quality = 80;
    final remaining = maxReportImages - _images.length;
    try {
      final picker = ImagePicker();
      final files = source == ImageSource.gallery
          ? await picker.pickMultiImage(
              maxWidth: maxSide, maxHeight: maxSide, imageQuality: quality, limit: remaining >= 2 ? remaining : null)
          : [?await picker.pickImage(source: source, maxWidth: maxSide, maxHeight: maxSide, imageQuality: quality)];
      if (files.isEmpty || !mounted) return;
      if (files.length > remaining) showSnack(context, 'Chỉ thêm được $remaining ảnh nữa, đã bỏ bớt ảnh thừa');
      setState(() { _images.addAll(files.take(remaining)); });
    } catch (e) {
      if (mounted) showSnack(context, 'Không mở được ảnh: ${errorText(e)}', error: true);
    }
  }

  Future<void> _submit(String type) async {
    if (_images.isEmpty) {
      showSnack(context, 'Chụp ít nhất 1 ảnh món đồ', error: true);
      return;
    }
    setState(() { _saving = true; });
    try {
      final report = await ConditionReportService().create(
        rentalId: widget.rental.id,
        reportType: type,
        condition: _condition,
        description: _description.text.trim(),
        images: _images,
      );
      if (!mounted) return;
      final next = type == 'BeforeRental'
          ? 'Khi giao đồ, người thuê sẽ bấm "Đã nhận đồ".'
          : 'Giờ bấm "Hoàn tất" để chốt tiền cọc.';
      showSnack(context, report.hasAi ? 'Đã lưu biên bản, AI đã nhận xét. $next' : 'Đã lưu biên bản. $next');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Biên bản · ${widget.rental.itemName}')),
      body: FutureBuilder<List<ConditionReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(
              message: errorText(snap.error!),
              onRetry: () => setState(() { _future = ConditionReportService().getReports(widget.rental.id); }),
            );
          }
          final reports = snap.data!;
          final type = _typeToCreate(reports);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (reports.isEmpty && type == null)
                const EmptyView(
                  icon: Icons.fact_check_outlined,
                  title: 'Chưa có biên bản',
                  subtitle: 'Chủ đồ chụp ảnh lập biên bản trước khi giao và khi nhận lại đồ.',
                ),
              for (final r in reports) _reportCard(r),
              if (type != null) ..._form(type),
            ],
          );
        },
      ),
    );
  }

  Widget _reportCard(ConditionReport r) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reportTypeLabels[r.reportType] ?? r.reportType,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(fmtDateTime(r.createdAt), style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Chủ đồ ghi: ${conditionLabels[r.condition] ?? r.condition}'),
            if (r.description.isNotEmpty) Text(r.description, style: TextStyle(color: muted)),
            if (r.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.imageUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _openImage(r.imageUrls[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageFullUrl(r.imageUrls[i]),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                            width: 96, height: 96, color: Colors.black12, child: const Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (r.hasAi) ...[
              const SizedBox(height: 12),
              AiReviewBox(report: r),
            ],
          ],
        ),
      ),
    );
  }

  void _openImage(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(child: Image.network(imageFullUrl(url)))),
      ),
    ));
  }

  List<Widget> _form(String type) {
    const border = OutlineInputBorder();
    final isBefore = type == 'BeforeRental';
    return [
      const SizedBox(height: 8),
      Text('Lập ${reportTypeLabels[type]!.toLowerCase()}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      NoticeBox(
        isBefore
            ? 'Chụp rõ các mặt của món đồ và phụ kiện. AI sẽ ghi lại khuyết điểm có sẵn để làm mốc khi nhận lại.'
            : 'Chụp cùng các góc như lúc giao. AI so sánh với ảnh lúc giao và gợi ý mức trừ cọc nếu có hư hỏng mới.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in _images)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(f.path), width: 88, height: 88, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: _saving ? null : () => setState(() { _images.remove(f); }),
                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ],
            ),
          if (_images.length < maxReportImages)
            InkWell(
              onTap: _saving ? null : _pickImages,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined),
                    Text('${_images.length}/$maxReportImages', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _condition,
        decoration: const InputDecoration(labelText: 'Tình trạng theo bạn', border: border),
        items: [for (final e in conditionLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: _saving ? null : (v) => setState(() { _condition = v!; }),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _description,
        maxLines: 3,
        enabled: !_saving,
        decoration: const InputDecoration(labelText: 'Ghi chú (phụ kiện đi kèm, vết xước có sẵn...)', border: border),
      ),
      const SizedBox(height: 20),
      BusyButton(busy: _saving, onPressed: () => _submit(type), label: 'Lưu biên bản', icon: Icons.check),
      if (_saving)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('AI đang xem ảnh, có thể mất 10-30 giây...', textAlign: TextAlign.center),
        ),
    ];
  }
}

/// Khung nhận xét của AI, dùng ở màn hình biên bản và hộp thoại hoàn tất đơn.
class AiReviewBox extends StatelessWidget {
  final ConditionReport report;
  const AiReviewBox({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = report;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'AI nhận xét${r.aiSuggestedCondition != null ? ' · ${conditionLabels[r.aiSuggestedCondition] ?? r.aiSuggestedCondition}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(r.aiSummary!),
          for (final d in r.aiDamages)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $d')),
          if (r.aiSuggestedDeduction != null) ...[
            const SizedBox(height: 6),
            Text(
              r.aiSuggestedDeduction == 0
                  ? 'Không thấy hư hỏng mới, gợi ý hoàn đủ cọc.'
                  : 'Gợi ý trừ cọc: ${formatVnd(r.aiSuggestedDeduction!)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 6),
          Text('Chỉ là gợi ý, có thể sai do ánh sáng hoặc góc chụp.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
