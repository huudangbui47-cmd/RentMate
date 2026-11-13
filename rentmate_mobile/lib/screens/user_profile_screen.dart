import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/item_service.dart';
import '../widgets/ui.dart';
import 'item_detail_screen.dart';

/// Hồ sơ công khai của chủ đồ: ảnh đại diện, tên, ngày tham gia và các món đang cho thuê.
class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<(PublicProfile, List<Item>)> _future = _load();

  Future<(PublicProfile, List<Item>)> _load() async {
    final results = await Future.wait([
      AccountService().getPublicProfile(widget.userId),
      ItemService().getItems(),
    ]);
    final items = (results[1] as List<Item>).where((i) => i.ownerId == widget.userId).toList();
    return (results[0] as PublicProfile, items);
  }

  void _reload() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: FutureBuilder<(PublicProfile, List<Item>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final (profile, items) = snap.data!;
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: profile.avatarUrl == null ? null : () => showImageViewer(context, profile.avatarUrl!),
                  child: UserAvatar(name: profile.fullName, url: profile.avatarUrl, radius: 48),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(profile.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text('Thành viên từ ${fmtDate(profile.createdAt)}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 24),
              Text('Đồ đang cho thuê (${items.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Chưa có đồ nào đang cho thuê.', style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
              for (final item in items)
                Card(
                  child: ListTile(
                    leading: ItemThumb(categoryName: item.categoryName, imageUrl: item.imageUrl, size: 56, radius: 10),
                    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${formatVnd(item.pricePerDay)} /ngày'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
