import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../widgets/ui.dart';
import 'rental_screen.dart';
import 'user_profile_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final int itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Future<(Item, String?)> _future = _load();

  Future<(Item, String?)> _load() async =>
      (await ItemService().getItem(widget.itemId), await AuthService().getUserId());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đồ')),
      body: FutureBuilder<(Item, String?)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(
              message: errorText(snap.error!),
              onRetry: () => setState(() { _future = _load(); }),
            );
          }
          final (item, userId) = snap.data!;
          return _content(item, item.ownerId == userId);
        },
      ),
    );
  }

  Widget _content(Item item, bool mine) {
    final scheme = Theme.of(context).colorScheme;
    final rented = item.status == 'Rented';
    final canRent = !mine && (item.status == 'Available' || rented);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              item.images.isEmpty
                  ? LayoutBuilder(
                      builder: (_, c) => ItemThumb(categoryName: item.categoryName, size: c.maxWidth, radius: 20),
                    )
                  : _Gallery(images: item.images),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(item.categoryName, scheme.primary),
                  StatusBadge('Tình trạng: ${conditionLabels[item.condition] ?? item.condition}', const Color(0xFF6B7280)),
                  if (rented) StatusBadge('Đang có người thuê', statusColor('Rented')),
                  if (mine) StatusBadge(itemStatusLabels[item.status] ?? item.status, statusColor(item.status)),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text.rich(TextSpan(children: [
                TextSpan(
                  text: formatVnd(item.pricePerDay),
                  style: TextStyle(fontSize: 22, color: scheme.primary, fontWeight: FontWeight.w800),
                ),
                TextSpan(text: ' / ngày', style: TextStyle(color: scheme.onSurfaceVariant)),
              ])),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    children: [
                      InfoRow('Tiền cọc', formatVnd(item.depositAmount)),
                      InfoRow('Đăng ngày', fmtDate(item.createdAt)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: UserAvatar(name: item.ownerName, url: item.ownerAvatarUrl),
                  title: Text(item.ownerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(mine ? 'Đây là đồ của bạn' : 'Chủ đồ'),
                  trailing: mine ? null : const Icon(Icons.chevron_right),
                  onTap: mine
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: item.ownerId)),
                          ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(item.description.isEmpty ? '(Chủ đồ chưa viết mô tả)' : item.description,
                  style: const TextStyle(height: 1.45)),
              const SizedBox(height: 16),
              const NoticeBox(
                'Tiền cọc được giữ trong ví RentMate và hoàn lại đầy đủ khi bạn trả đồ đúng tình trạng.',
                icon: Icons.verified_user_outlined,
                color: Color(0xFF16A34A),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.event_available_rounded),
                label: Text(mine
                    ? 'Đây là đồ của bạn'
                    : rented
                        ? 'Đặt lịch thuê ngày khác'
                        : 'Đặt thuê'),
                onPressed: canRent
                    ? () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => RentalScreen(item: item)),
                        );
                        if (ok == true && mounted) {
                          showSnack(context, 'Đã gửi yêu cầu thuê. Theo dõi trong tab "Đơn thuê".');
                        }
                      }
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ảnh vuốt ngang + chấm vị trí; chạm để xem toàn màn hình.
class _Gallery extends StatefulWidget {
  final List<ItemImage> images;
  const _Gallery({required this.images});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() { _page = i; }),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _FullScreenGallery(images: images, initialPage: i),
                )),
                child: Image.network(
                  images[i].url,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, p) =>
                      p == null ? child : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF1F5F9),
                    child: Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey)),
                  ),
                ),
              ),
            ),
            if (images.length > 1) ...[
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text('${_page + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < images.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white70,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<ItemImage> images;
  final int initialPage;
  const _FullScreenGallery({required this.images, required this.initialPage});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_page + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() { _page = i; }),
        // Chụm 2 ngón để phóng to
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(child: Image.network(widget.images[i].url, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
