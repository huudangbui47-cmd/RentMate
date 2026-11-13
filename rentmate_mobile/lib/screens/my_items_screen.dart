import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../widgets/ui.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  late Future<List<Item>> _future = ItemService().getMyItems();

  Future<void> _reload() async {
    setState(() { _future = ItemService().getMyItems(); });
    await _future;
  }

  Future<void> _openForm([Item? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItemFormScreen(item: item)),
    );
    if (saved == true) {
      if (mounted) showSnack(context, 'Đã gửi. Đồ sẽ hiện trên app sau khi được duyệt.');
      await _reload();
    }
  }

  Future<void> _delete(Item item) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa đồ?',
      message: '"${item.name}" sẽ bị gỡ khỏi RentMate. Lịch sử đơn thuê vẫn được giữ.',
      confirmText: 'Xóa',
      danger: true,
    );
    if (!ok) return;
    try {
      await ItemService().deleteItem(item.id);
      if (mounted) showSnack(context, 'Đã xóa "${item.name}"');
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
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
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final items = snap.data!;
          final pending = items.where((i) => i.status == 'PendingApproval').length;
          final rejected = items.where((i) => i.status == 'Rejected').length;
          return RefreshIndicator(
            onRefresh: _reload,
            child: items.isEmpty
                ? ListView(children: [
                    EmptyView(
                      icon: Icons.add_business_outlined,
                      title: 'Bạn chưa đăng đồ nào',
                      subtitle: 'Cho thuê đồ ít dùng để kiếm thêm thu nhập.',
                      action: FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Đăng đồ đầu tiên'),
                      ),
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (rejected > 0) ...[
                        NoticeBox('$rejected món bị từ chối. Xem lý do bên dưới, sửa lại rồi lưu để được duyệt lại.',
                            icon: Icons.error_outline, color: statusColor('Rejected')),
                        const SizedBox(height: 8),
                      ],
                      if (pending > 0) ...[
                        NoticeBox('$pending món đang chờ quản lý duyệt. Đồ sẽ hiện trên trang Khám phá sau khi được duyệt.',
                            icon: Icons.hourglass_top_rounded, color: statusColor('PendingApproval')),
                        const SizedBox(height: 8),
                      ],
                      for (final item in items) ...[_card(item), const SizedBox(height: 12)],
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _card(Item item) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final rented = item.status == 'Rented';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Đồ đang có người thuê thì không sửa được, chỉ xem
        onTap: () => rented
            ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)))
            : _openForm(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ItemThumb(categoryName: item.categoryName, imageUrl: item.imageUrl, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('${formatVnd(item.pricePerDay)}/ngày · ${item.categoryName}',
                            style: TextStyle(color: muted, fontSize: 13)),
                        const SizedBox(height: 6),
                        StatusBadge(itemStatusLabels[item.status] ?? item.status, statusColor(item.status)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? _openForm(item) : _delete(item),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', enabled: !rented, child: const Text('Sửa')),
                      PopupMenuItem(value: 'delete', enabled: !rented, child: const Text('Xóa')),
                    ],
                  ),
                ],
              ),
              if (item.status == 'Rejected' && (item.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                NoticeBox('Lý do từ chối: ${item.rejectionReason}', icon: Icons.feedback_outlined, color: statusColor('Rejected')),
              ],
              if (item.status == 'Unavailable') ...[
                const SizedBox(height: 10),
                NoticeBox('Quản lý đã tạm ngưng đồ này. Liên hệ RentMate nếu cần hỗ trợ.',
                    icon: Icons.pause_circle_outline, color: statusColor('Unavailable')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
