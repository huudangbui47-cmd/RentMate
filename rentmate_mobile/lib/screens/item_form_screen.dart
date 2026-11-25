import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/item_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import '../l10n/l10n.dart';

/// item == null: đăng đồ mới; có item: sửa đồ. Cả hai đều phải chờ quản lý duyệt.
class ItemFormScreen extends StatefulWidget {
  final Item? item;
  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _description = TextEditingController(text: widget.item?.description);
  late final _price = TextEditingController(text: widget.item == null ? null : moneyText(widget.item!.pricePerDay));
  late final _deposit = TextEditingController(text: widget.item == null ? null : moneyText(widget.item!.depositAmount));
  late int? _categoryId = widget.item?.categoryId;
  late String _condition = widget.item?.condition ?? 'Good';
  late String? _province = widget.item?.province;
  late final _area = TextEditingController(text: widget.item?.area);
  // Ưu đãi thuê dài ngày: để trống = không giảm
  late final _dealPercent = TextEditingController(
    text: (widget.item?.discountPercent ?? 0) > 0 ? '${widget.item!.discountPercent}' : null,
  );
  late final _dealDays = TextEditingController(
    text: (widget.item?.discountPercent ?? 0) > 0 ? '${widget.item!.discountMinDays}' : null,
  );
  late final Future<List<Category>> _categories = ItemService().getCategories();
  late final Future<List<String>> _provinces = ItemService().getProvinces();
  bool _saving = false;

  // Ảnh: ảnh cũ đang giữ, ảnh cũ bấm xóa, ảnh mới chọn từ máy. Chỉ gửi lên khi bấm Lưu.
  late final List<ItemImage> _existing = [...?widget.item?.images];
  final List<ItemImage> _removed = [];
  final List<XFile> _picked = [];
  late int? _primaryId = _existing.where((i) => i.isPrimary).map((i) => i.id).firstOrNull;

  int get _imageCount => _existing.length + _picked.length;

  Future<void> _addImages() async {
    final remaining = maxItemImages - _imageCount;
    if (remaining <= 0) {
      showSnack(context, tr('Mỗi món đồ tối đa {0} ảnh', [maxItemImages]), error: true);
      return;
    }
    final source = await pickImageSource(context, galleryLabel: tr('Chọn từ thư viện (chọn được nhiều ảnh)'));
    if (source == null) return;

    // Thu nhỏ ảnh trước khi gửi: Api chỉ nhận ảnh JPG/PNG tối đa 2MB
    const maxSide = 1600.0;
    const quality = 80;
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
        _picked.addAll(files.take(remaining));
      });
    } catch (e) {
      if (mounted) showSnack(context, tr('Không mở được ảnh: {0}', [errorText(e)]), error: true);
    }
  }

  void _removeExisting(ItemImage image) {
    setState(() {
      _existing.remove(image);
      _removed.add(image);
      if (_primaryId == image.id) _primaryId = null;
    });
  }

  /// Gửi các thay đổi về ảnh sau khi đã lưu thông tin đồ.
  Future<void> _syncImages(int itemId) async {
    final service = ItemService();
    for (final image in _removed) {
      await service.deleteImage(itemId, image.id);
    }
    final originalPrimary = widget.item?.images.where((i) => i.isPrimary).map((i) => i.id).firstOrNull;
    if (_primaryId != null && _primaryId != originalPrimary) {
      await service.setPrimaryImage(itemId, _primaryId!);
    }
    if (_picked.isNotEmpty) {
      await service.uploadImages(itemId, _picked);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _deposit, _area, _dealPercent, _dealDays]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _money(String? v, {bool allowZero = false}) {
    final n = parseMoney(v);
    if (n == null) return tr('Nhập số tiền');
    if (!allowZero && n <= 0) return tr('Phải lớn hơn 0');
    return null;
  }

  // Đơn vị luôn hiện ở cuối ô (suffixText chỉ hiện khi đang gõ)
  Widget _unit(String text) => Padding(
    padding: const EdgeInsets.only(right: 18),
    child: Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      child: Text(text, style: kText(15, FontWeight.w300, color: AppColors.muted)),
    ),
  );

  int get _percentValue => int.tryParse(_dealPercent.text.trim()) ?? 0;

  String? _percentError(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 0 || n > 50) return tr('Từ 1 đến 50');
    return null;
  }

  String? _dealDaysError(String? v) {
    if (_percentValue == 0) return null;
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 2) return tr('Từ 2 ngày trở lên');
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await ItemService().saveItem(
        id: widget.item?.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        pricePerDay: parseMoney(_price.text)!,
        depositAmount: parseMoney(_deposit.text)!,
        categoryId: _categoryId!,
        condition: _condition,
        province: _province!,
        area: _area.text.trim().isEmpty ? null : _area.text.trim(),
        discountPercent: _percentValue,
        discountMinDays: _percentValue > 0 ? int.parse(_dealDays.text.trim()) : 0,
      );
      final itemId = saved.id;
      var status = saved.status;
      try {
        await _syncImages(itemId);
        // Thêm ảnh mới cũng phải duyệt lại, lấy trạng thái cuối cùng để báo đúng
        if (_picked.isNotEmpty) status = (await ItemService().getItem(itemId)).status;
      } catch (e) {
        // Thông tin đồ đã lưu rồi, chỉ phần ảnh lỗi: vẫn quay lại danh sách và báo để sửa lại
        if (mounted) {
          showSnack(
            context,
            tr('Đã lưu thông tin đồ nhưng ảnh chưa cập nhật được: {0}. Bấm Sửa để thử lại.', [errorText(e)]),
            error: true,
          );
        }
      }
      final message = widget.item == null
          ? tr('Đã đăng. Đồ sẽ hiện trên app sau khi được duyệt.')
          : widget.item!.status == 'Rejected'
          ? tr('Đã lưu và gửi duyệt lại.')
          : status == 'PendingApproval' && widget.item!.status != 'PendingApproval'
          ? tr('Đã lưu. Bạn đổi tên, mô tả, danh mục hoặc ảnh nên đồ đang chờ duyệt lại.')
          : tr('Đã lưu thay đổi.');
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final digits = [MoneyInputFormatter()];
    return Scaffold(
      appBar: RcAppBar(title: Text(editing ? tr('Sửa đồ') : tr('Đăng đồ cho thuê'))),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  NoticeBox(
                    editing
                        ? tr(
                            'Đổi giá, tiền cọc, tình trạng hoặc nơi nhận đồ thì lưu ngay. Đổi tên, mô tả, danh mục hoặc thêm ảnh thì đồ tạm ẩn để quản lý duyệt lại.',
                          )
                        : tr('Đồ mới sẽ được quản lý duyệt trước khi hiện trên trang Khám phá (thường trong ngày).'),
                  ),
                  if (widget.item?.status == 'Rejected' && (widget.item?.rejectionReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    NoticeBox(
                      tr('Lý do bị từ chối lần trước: {0}', [widget.item!.rejectionReason]),
                      icon: Icons.feedback_outlined,
                      color: statusColor('Rejected'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  RcCard(padding: const EdgeInsets.fromLTRB(16, 16, 16, 18), child: _imagesSection()),
                  const SizedBox(height: 12),
                  RcCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabeledField(
                          label: tr('Tên đồ'),
                          child: TextFormField(
                            controller: _name,
                            maxLength: 200,
                            decoration: InputDecoration(hintText: tr('Ví dụ: Máy ảnh Sony A7 III'), counterText: ''),
                            validator: (v) => (v == null || v.trim().isEmpty) ? tr('Vui lòng nhập tên đồ') : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LabeledField(
                          label: tr('Danh mục'),
                          child: FutureBuilder<List<Category>>(
                            future: _categories,
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return Text(tr('Không tải được danh mục: {0}', [errorText(snap.error!)]));
                              }
                              final cats = snap.data ?? [];
                              // Danh mục cha đã có danh mục con thì chỉ làm tiêu đề nhóm, không chọn được (theo ItemService.cs)
                              final parentsWithChildren = cats
                                  .where((c) => c.parentId != null)
                                  .map((c) => c.parentId)
                                  .toSet();
                              final selectable = cats
                                  .where((c) => !parentsWithChildren.contains(c.id))
                                  .map((c) => c.id)
                                  .toSet();
                              return DropdownButtonFormField<int>(
                                key: ValueKey(cats.length),
                                initialValue: selectable.contains(_categoryId) ? _categoryId : null,
                                isExpanded: true,
                                hint: Text(snap.hasData ? tr('Chọn danh mục') : tr('Đang tải danh mục...')),
                                items: [
                                  for (final c in cats)
                                    DropdownMenuItem(
                                      value: c.id,
                                      enabled: selectable.contains(c.id),
                                      child: Text(
                                        c.parentId == null ? tr(c.name) : '    ${tr(c.name)}',
                                        style: selectable.contains(c.id)
                                            ? null
                                            : const TextStyle(fontWeight: FontWeight.w500, color: AppColors.muted),
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                                validator: (v) => v == null ? tr('Vui lòng chọn danh mục') : null,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LabeledField(
                                label: tr('Giá thuê / ngày'),
                                child: TextFormField(
                                  controller: _price,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: digits,
                                  decoration: InputDecoration(suffixText: tr('đ')),
                                  validator: _money,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LabeledField(
                                label: tr('Tiền cọc'),
                                child: TextFormField(
                                  controller: _deposit,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: digits,
                                  decoration: InputDecoration(suffixText: tr('đ')),
                                  validator: (v) => _money(v, allowZero: true),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LabeledField(
                          label: tr('Tình trạng'),
                          child: DropdownButtonFormField<String>(
                            initialValue: _condition,
                            items: [
                              for (final e in conditionLabels.entries)
                                DropdownMenuItem(value: e.key, child: Text(e.value)),
                            ],
                            onChanged: (v) => setState(() => _condition = v!),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Ưu đãi thuê dài ngày (thẻ "Deals" ở Trang chủ): giảm X% khi thuê từ N ngày
                        Text(
                          tr('Ưu đãi thuê dài ngày (không bắt buộc)'),
                          style: kText(14, FontWeight.w300, color: AppColors.muted),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LabeledField(
                                label: tr('Giảm'),
                                child: TextFormField(
                                  controller: _dealPercent,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  decoration: InputDecoration(hintText: '10', suffixIcon: _unit('%')),
                                  validator: _percentError,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LabeledField(
                                label: tr('Khi thuê từ'),
                                child: TextFormField(
                                  controller: _dealDays,
                                  enabled: _percentValue > 0,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  decoration: InputDecoration(hintText: '7', suffixIcon: _unit(tr('ngày'))),
                                  validator: _dealDaysError,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  RcCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _locationFields(),
                        const SizedBox(height: 16),
                        LabeledField(
                          label: tr('Mô tả'),
                          child: TextFormField(
                            controller: _description,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: tr('Tình trạng chi tiết, phụ kiện kèm theo, nơi nhận đồ...'),
                            ),
                            validator: (v) => (v == null || v.trim().length < 10)
                                ? tr('Mô tả ít nhất 10 ký tự để dễ được duyệt')
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: SizedBox(
                width: double.infinity,
                child: BusyButton(
                  busy: _saving,
                  onPressed: _save,
                  label: editing ? tr('Lưu và gửi duyệt lại') : tr('Đăng đồ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nơi nhận đồ: tỉnh/thành (bắt buộc, để khách lọc) + khu vực tự ghi. Không ghi số nhà.
  Widget _locationFields() {
    return FutureBuilder<List<String>>(
      future: _provinces,
      builder: (context, snap) {
        if (snap.hasError) return Text(tr('Không tải được danh sách tỉnh/thành: {0}', [errorText(snap.error!)]));
        final provinces = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledField(
              label: tr('Tỉnh/thành nơi nhận đồ'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(provinces.length),
                initialValue: provinces.contains(_province) ? _province : null,
                isExpanded: true,
                menuMaxHeight: 400,
                hint: Text(snap.hasData ? tr('Chọn tỉnh/thành') : tr('Đang tải danh sách...')),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined)),
                items: [for (final p in provinces) DropdownMenuItem(value: p, child: Text(p))],
                onChanged: (v) => setState(() {
                  _province = v;
                }),
                validator: (v) => v == null ? tr('Vui lòng chọn tỉnh/thành') : null,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: tr('Khu vực (không bắt buộc)'),
              child: TextFormField(
                controller: _area,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: tr('Ví dụ: Phường Bến Thành, gần chợ Bến Thành'),
                  helperText: tr('Không cần ghi số nhà, hai bên trao đổi khi nhận đồ.'),
                  counterText: '',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _imagesSection() {
    // Ảnh chính: ảnh cũ được chọn làm chính; nếu không có thì ảnh đầu tiên trong danh sách
    final firstIsPrimary = _primaryId == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('Ảnh'), actionText: '$_imageCount/$maxItemImages'),
        const SizedBox(height: 6),
        Text(
          _existing.isEmpty
              ? tr('Ảnh đầu tiên là ảnh chính. Đồ có ảnh rõ ràng được duyệt nhanh hơn.')
              : tr('Chạm vào ảnh đã đăng để đặt làm ảnh chính.'),
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, image) in _existing.indexed)
                _tile(
                  Image.network(
                    image.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                  ),
                  primary: image.id == _primaryId || (firstIsPrimary && i == 0),
                  onTap: () => setState(() {
                    _primaryId = image.id;
                  }),
                  onRemove: () => _removeExisting(image),
                ),
              for (final (i, file) in _picked.indexed)
                _tile(
                  Image.file(File(file.path), fit: BoxFit.cover),
                  primary: firstIsPrimary && _existing.isEmpty && i == 0,
                  onRemove: () => setState(() {
                    _picked.remove(file);
                  }),
                ),
              if (_imageCount < maxItemImages)
                SizedBox(
                  width: 96,
                  child: DashedBox(
                    height: 96,
                    onTap: _saving ? null : _addImages,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                        const SizedBox(height: 4),
                        Text(
                          tr('Thêm ảnh'),
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w400, fontSize: 13),
                        ),
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

  Widget _tile(Widget image, {required bool primary, VoidCallback? onTap, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: _saving ? null : onTap,
        child: Stack(
          children: [
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary ? AppColors.primary : AppColors.border, width: primary ? 2.5 : 1),
              ),
              child: image,
            ),
            if (primary)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  margin: const EdgeInsets.all(2.5),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                  ),
                  child: Text(
                    tr('Ảnh chính'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: _saving ? null : onRemove,
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
