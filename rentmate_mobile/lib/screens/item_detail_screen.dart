import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/item_service.dart';
import 'rental_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final int itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  Future<Item> _load() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Items/$itemId'));
    if (res.statusCode != 200) throw Exception('Không tải được thông tin đồ (${res.statusCode})');
    return Item.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết')),
      body: FutureBuilder<Item>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString().replaceFirst('Exception: ', '')));
          }
          final item = snap.data!;
          final available = item.status == 'Available';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 80),
              ),
              const SizedBox(height: 16),
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${formatVnd(item.pricePerDay)} / ngày',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
              const Divider(height: 32),
              _row('Tiền cọc', formatVnd(item.depositAmount)),
              _row('Danh mục', item.categoryName),
              _row('Tình trạng', conditionLabels[item.condition] ?? item.condition),
              _row('Trạng thái', available ? 'Còn trống' : 'Đang được thuê'),
              _row('Chủ đồ', item.ownerName),
              const Divider(height: 32),
              const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(item.description.isEmpty ? '(Không có mô tả)' : item.description),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Đặt thuê'),
                onPressed: available
                    ? () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => RentalScreen(item: item)),
                        );
                        if (ok == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Đã gửi yêu cầu thuê, chờ chủ đồ duyệt')));
                        }
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
