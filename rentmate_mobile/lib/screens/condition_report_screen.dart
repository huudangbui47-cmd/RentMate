import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/condition_report_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import '../l10n/l10n.dart';

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

  // Loại biên bản được lập lúc này, theo kiểm tra trong ConditionReportService.cs.
  // Chủ đồ: lúc giao + lúc nhận lại. Người thuê: lúc nhận (sau khi chủ đồ đã chụp lúc giao).
  String? _typeToCreate(List<ConditionReport> existing) {
    final s = widget.rental.status;
    final has = existing.map((r) => r.reportType).toSet();
    if (!widget.isOwner) {
      return s == 'WaitingForPickup' && has.contains('BeforeRental') && !has.contains('RenterReceived')
          ? 'RenterReceived'
          : null;
    }
    if ((s == 'Approved' || s == 'WaitingForPickup') && !has.contains('BeforeRental')) return 'BeforeRental';
    if (s == 'Returned' && !has.contains('AfterRental')) return 'AfterRental';
    return null;
  }

  Future<void> _pickImages() async {
    final source = await pickImageSource(context);
    if (source == null) return;

    // Thu nhỏ ảnh trước khi gửi: Api nhận JPG/PNG tối đa 2MB
    const maxSide = 1600.0;
    const quality = 80;
    final remaining = maxReportImages - _images.length;
    try {
      final picker = ImagePicker();
      final files = source == ImageSource.gallery
          ? await picker.pickMultiImage(
              maxWidth: maxSide,
              maxHeight: maxSide,
              imageQuality: quality,
              limit: remaining >= 2 ? remaining : null,
            )
          : [?await picker.pickImage(source: source, maxWidth: maxSide, maxHeight: maxSide, imageQuality: quality)];
      if (files.isEmpty || !mounted) return;
      if (files.length > remaining) {
        showSnack(context, tr('Chỉ thêm được {0} ảnh nữa, đã bỏ bớt ảnh thừa', [remaining]));
      }
      setState(() {
        _images.addAll(files.take(remaining));
      });
    } catch (e) {
      if (mounted) showSnack(context, tr('Không mở được ảnh: {0}', [errorText(e)]), error: true);
    }
  }

  Future<void> _submit(String type) async {
    if (_images.isEmpty) {
      showSnack(context, tr('Chụp ít nhất 1 ảnh món đồ'), error: true);
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final report = await ConditionReportService().create(
        rentalId: widget.rental.id,
        reportType: type,
        condition: _condition,
        description: _description.text.trim(),
        images: _images,
      );
      if (!mounted) return;
      final next = switch (type) {
        'BeforeRental' =>
          widget.rental.isShipping
              ? tr('Giờ bấm "Gửi hàng GHN".')
              : tr('Khi giao đồ, người thuê sẽ chụp ảnh đối chiếu.'),
        'RenterReceived' =>
          report.aiSameItem == false
              ? tr('AI thấy đồ có thể KHÁC tin đăng, hãy kiểm tra kỹ trước khi bấm "Đã nhận đồ".')
              : tr('Đúng đồ thì bấm "Đã nhận đồ".'),
        _ => tr('Giờ bấm "Hoàn tất" để chốt tiền cọc.'),
      };
      showSnack(
        context,
        report.hasAi ? tr('Đã lưu biên bản, AI đã nhận xét. {0}', [next]) : tr('Đã lưu biên bản. {0}', [next]),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Biên bản'))),
      body: FutureBuilder<List<ConditionReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(
              message: errorText(snap.error!),
              onRetry: () => setState(() {
                _future = ConditionReportService().getReports(widget.rental.id);
              }),
            );
          }
          final reports = snap.data!;
          final type = _typeToCreate(reports);
          final r = widget.rental;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              // Món đồ của đơn trong khối trắng
              RcCard(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: ItemRow(
                  divider: false,
                  thumb: ItemThumb(categoryName: r.categoryName, imageUrl: r.itemImageUrl, size: 72, radius: 14),
                  title: r.itemName,
                  subtitle: Text(tr('Đơn #{0}', [r.id]), style: kSub12),
                  bottom: Text('${fmtDate(r.startDate)} - ${fmtDate(r.endDate)}', style: kSub12),
                ),
              ),
              const SizedBox(height: 12),
              if (reports.isEmpty && type == null)
                RcCard(
                  child: EmptyView(
                    icon: Icons.fact_check_outlined,
                    title: tr('Chưa có biên bản'),
                    subtitle: tr('Chủ đồ chụp lúc giao, người thuê chụp lúc nhận, chủ đồ chụp lúc nhận lại.'),
                  ),
                ),
              for (final r in reports) _reportCard(r),
              if (type != null)
                RcCard(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _form(type)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _reportCard(ConditionReport r) {
    return RcCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(reportTypeLabels[r.reportType] ?? r.reportType, style: kText(17, FontWeight.w400))),
              Text(fmtDateTime(r.createdAt), style: kSub12),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('Chủ đồ ghi: {0}', [conditionLabels[r.condition] ?? r.condition]), style: kText(14, FontWeight.w400)),
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.description, style: const TextStyle(color: AppColors.muted, height: 1.45)),
          ],
          if (r.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.imageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _openImage(r.imageUrls[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageFullUrl(r.imageUrls[i]),
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 96,
                        height: 96,
                        color: const Color(0xFFF2F3F5),
                        child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (r.hasAi) ...[const SizedBox(height: 14), AiReviewBox(report: r)],
        ],
      ),
    );
  }

  void _openImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: InteractiveViewer(child: Image.network(imageFullUrl(url)))),
        ),
      ),
    );
  }

  // Mẫu "Write a review": khung tải ảnh viền đứt, ô ghi chú, nút chính
  List<Widget> _form(String type) {
    return [
      const SizedBox(height: 20),
      SectionTitle(tr('Lập {0}', [reportTypeLabels[type]!.toLowerCase()])),
      const SizedBox(height: 12),
      NoticeBox(switch (type) {
        'BeforeRental' => tr(
          'Chụp rõ các mặt của món đồ và phụ kiện. AI so với ảnh tin đăng và ghi lại khuyết điểm có sẵn để làm mốc.',
        ),
        'RenterReceived' => tr(
          'Chụp món đồ bạn vừa nhận. AI so với ảnh tin đăng và ảnh chủ đồ chụp lúc giao: đồ khác món hoặc hư hỏng thì đừng bấm "Đã nhận đồ", hãy bấm "Từ chối nhận" để được hoàn tiền.',
        ),
        _ => tr(
          'Chụp cùng các góc như lúc giao. AI so với ảnh lúc người thuê nhận và gợi ý mức trừ cọc nếu có hư hỏng mới.',
        ),
      }),
      const SizedBox(height: 24),
      SectionTitle(tr('Ảnh món đồ'), actionText: '${_images.length}/$maxReportImages'),
      const SizedBox(height: 12),
      if (_images.isEmpty)
        DashedBox(
          onTap: _saving ? null : _pickImages,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(tr('Bấm để chụp hoặc chọn ảnh'), style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        )
      else
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final f in _images)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(f.path), width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () => setState(() {
                              _images.remove(f);
                            }),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (_images.length < maxReportImages)
              SizedBox(
                width: 96,
                child: DashedBox(
                  height: 96,
                  onTap: _saving ? null : _pickImages,
                  child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                ),
              ),
          ],
        ),
      const SizedBox(height: 24),
      LabeledField(
        label: tr('Tình trạng theo bạn'),
        child: DropdownButtonFormField<String>(
          initialValue: _condition,
          items: [for (final e in conditionLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: _saving
              ? null
              : (v) => setState(() {
                  _condition = v!;
                }),
        ),
      ),
      const SizedBox(height: 20),
      LabeledField(
        label: tr('Ghi chú'),
        child: TextField(
          controller: _description,
          maxLines: 4,
          enabled: !_saving,
          decoration: InputDecoration(hintText: tr('Ghi chú (phụ kiện đi kèm, vết xước có sẵn...)')),
        ),
      ),
      const SizedBox(height: 28),
      BusyButton(busy: _saving, onPressed: () => _submit(type), label: tr('Lưu biên bản')),
      if (_saving)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            tr('AI đang xem ảnh, có thể mất 10-30 giây...'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('AI nhận xét{0}', [
                    r.aiSuggestedCondition != null
                        ? ' · ${conditionLabels[r.aiSuggestedCondition] ?? r.aiSuggestedCondition}'
                        : '',
                  ]),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (r.aiSameItem == false) ...[
            const SizedBox(height: 6),
            Text(
              tr('⚠ Đồ trong ảnh có thể KHÁC món đã đăng / đã giao'),
              style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 6),
          Text(r.aiSummary!),
          for (final d in r.aiDamages) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $d')),
          if (r.aiSuggestedDeduction != null) ...[
            const SizedBox(height: 6),
            Text(
              r.aiSuggestedDeduction == 0
                  ? tr('Không thấy hư hỏng mới, gợi ý hoàn đủ cọc.')
                  : tr('Gợi ý trừ cọc: {0}', [formatVnd(r.aiSuggestedDeduction!)]),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            tr('Chỉ là gợi ý, có thể sai do ánh sáng hoặc góc chụp.'),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
