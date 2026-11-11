import 'package:flutter/material.dart';

import '../services/item_service.dart';

/// item == null: đăng đồ mới; có item: sửa đồ.
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
  late final _price = TextEditingController(text: widget.item?.pricePerDay.round().toString());
  late final _deposit =
      TextEditingController(text: widget.item?.depositAmount.round().toString());
  late int? _categoryId = widget.item?.categoryId;
  late String _condition = widget.item?.condition ?? 'Good';
  late final Future<List<Category>> _categories = ItemService().getCategories();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _deposit]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _money(String? v) {
    final n = num.tryParse(v ?? '');
    if (n == null) return 'Nhập số tiền (chỉ chữ số)';
    if (n < 0) return 'Số tiền không được âm';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ItemService().saveItem(
        id: widget.item?.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        pricePerDay: num.parse(_price.text),
        depositAmount: num.parse(_deposit.text),
        categoryId: _categoryId!,
        condition: _condition,
      );
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder();
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Đăng đồ cho thuê' : 'Sửa đồ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên đồ', border: border),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên đồ' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả', border: border),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Giá thuê / ngày (đ)', border: border),
              validator: _money,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deposit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tiền cọc (đ)', border: border),
              validator: _money,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Category>>(
              future: _categories,
              builder: (context, snap) {
                if (snap.hasError) return const Text('Không tải được danh mục');
                final cats = snap.data ?? [];
                return DropdownButtonFormField<int>(
                  value: cats.any((c) => c.id == _categoryId) ? _categoryId : null,
                  decoration: const InputDecoration(labelText: 'Danh mục', border: border),
                  items: [
                    for (final c in cats)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.parentId == null ? c.name : '   ↳ ${c.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
                );
              },
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.item == null ? 'Đăng đồ' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
