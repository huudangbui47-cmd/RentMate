import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import 'item_detail_screen.dart';
import 'login_screen.dart';
import 'my_items_screen.dart';
import 'my_rentals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = ItemService();
  List<Item> _items = [];
  List<Category> _categories = [];
  int? _selectedCategoryId; // null = tất cả
  String _search = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_service.getItems(), _service.getCategories()]);
      setState(() {
        _items = results[0] as List<Item>;
        _categories = results[1] as List<Category>;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Chọn danh mục cha thì hiện cả đồ thuộc danh mục con của nó.
  bool _matchesCategory(Item item) {
    if (_selectedCategoryId == null) return true;
    if (item.categoryId == _selectedCategoryId) return true;
    final cat = _categories.where((c) => c.id == item.categoryId).firstOrNull;
    return cat?.parentId == _selectedCategoryId;
  }

  List<Item> get _visibleItems => _items
      .where(_matchesCategory)
      .where((i) => i.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RentMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Đồ của tôi',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyItemsScreen()),
              );
              _load(); // đồ vừa đăng/sửa/xóa hiện ngay ở trang chủ
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Đơn thuê',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyRentalsScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Đăng xuất', onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm đồ cho thuê...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Tất cả', null),
                // Chỉ hiện danh mục cấp 1 làm bộ lọc.
                for (final c in _categories.where((c) => c.parentId == null)) _chip(c.name, c.id),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _chip(String label, int? id) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _selectedCategoryId == id,
          onSelected: (_) => setState(() => _selectedCategoryId = id),
        ),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final items = _visibleItems;
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('Không có đồ nào')),
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _itemCard(items[i]),
            ),
    );
  }

  Widget _itemCard(Item item) {
    final available = item.status == 'Available';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: const CircleAvatar(radius: 28, child: Icon(Icons.inventory_2_outlined)),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${formatVnd(item.pricePerDay)} / ngày',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            Text('${item.categoryName} · ${conditionLabels[item.condition] ?? item.condition}'),
          ],
        ),
        trailing: Chip(
          label: Text(available ? 'Còn trống' : 'Đang thuê'),
          backgroundColor: available ? Colors.green.shade100 : Colors.grey.shade300,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)),
        ),
      ),
    );
  }
}