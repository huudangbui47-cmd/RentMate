import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import 'item_form_screen.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  late Future<List<Item>> _future = _load();

  // shortcut: API chưa có "GET đồ của tôi" nên lấy hết rồi lọc theo ownerId; nhóm thêm API riêng thì đổi sang gọi API đó.
  Future<List<Item>> _load() async {
    final userId = await AuthService().getUserId();
    final items = await ItemService().getItems();
    return items.where((i) => i.ownerId == userId).toList();
  }

  Future<void> _reload() async {
    setState(() { _future = _load(); });
    await _future;
  }

  Future<void> _openForm([Item? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItemFormScreen(item: item)),
    );
    if (saved == true) await _reload();
  }

  Future<void> _delete(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa đồ?'),
        content: Text('Bạn chắc chắn muốn xóa "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ItemService().deleteItem(item.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đồ của tôi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Đăng đồ'),
      ),
      body: FutureBuilder<List<Item>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString().replaceFirst('Exception: ', '')));
          }
          final items = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: items.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Bạn chưa đăng đồ nào.\nBấm "Đăng đồ" để bắt đầu.',
                        textAlign: TextAlign.center)),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Card(
                        child: ListTile(
                          title: Text(item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${formatVnd(item.pricePerDay)} / ngày · ${conditionLabels[item.condition] ?? item.condition}'),
                          onTap: () => _openForm(item),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Xóa',
                            onPressed: () => _delete(item),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
