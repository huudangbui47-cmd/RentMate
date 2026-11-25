import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';
import '../l10n/l10n.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  late Future<List<Item>> _future = ItemService().getMyItems();

  Future<void> _reload() async {
    setState(() {
      _future = ItemService().getMyItems();
    });
    await _future;
  }

  Future<void> _openForm([Item? item]) async {
    // Màn hình sửa đồ trả về câu thông báo (đã lưu luôn / đang chờ duyệt lại)
    final message = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => ItemFormScreen(item: item)));
    if (message != null) {
      if (mounted) showSnack(context, message);
      await _reload();
    }
  }

  Future<void> _delete(Item item) async {
    final ok = await confirmDialog(
      context,
      title: tr('Xóa đồ?'),
      message: tr('"{0}" sẽ bị gỡ khỏi RentMate. Lịch sử đơn thuê vẫn được giữ.', [item.name]),
      confirmText: tr('Xóa'),
      danger: true,
    );
    if (!ok) return;
    try {
      await ItemService().deleteItem(item.id);
      if (mounted) showSnack(context, tr('Đã xóa "{0}"', [item.name]));
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(
        title: Text(tr('Đồ của tôi')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            tooltip: tr('Đăng đồ'),
            onPressed: () => _openForm(),
          ),
        ],
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
                ? ListView(
                    children: [
                      EmptyView(
                        icon: Icons.add_business_outlined,
                        title: tr('Bạn chưa đăng đồ nào'),
                        subtitle: tr('Cho thuê đồ ít dùng để kiếm thêm thu nhập.'),
                        action: FilledButton.icon(
                          onPressed: () => _openForm(),
                          icon: const Icon(Icons.add),
                          label: Text(tr('Đăng đồ đầu tiên')),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      // Nút đen viên thuốc thay nút nổi, như nút "Search" của mẫu
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(tr('Đăng đồ')),
                      ),
                      const SizedBox(height: 12),
                      if (rejected > 0) ...[
                        NoticeBox(
                          tr('{0} món bị từ chối. Xem lý do bên dưới, sửa lại rồi lưu để được duyệt lại.', [rejected]),
                          icon: Icons.error_outline,
                          color: statusColor('Rejected'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (pending > 0) ...[
                        NoticeBox(
                          tr('{0} món đang chờ quản lý duyệt. Đồ sẽ hiện trên trang Khám phá sau khi được duyệt.', [
                            pending,
                          ]),
                          icon: Icons.hourglass_top_rounded,
                          color: statusColor('PendingApproval'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final item in items) _card(item),
                    ],
                  ),
          );
        },
      ),
    );
  }

  // Khối trắng bo tròn: nhãn trạng thái, ảnh vuông hiện trọn, tên, giá, nút ba chấm
  Widget _card(Item item) {
    final rented = item.status == 'Rented';
    return RcCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ItemRow(
            // Đồ đang có người thuê thì không sửa được, chỉ xem
            onTap: () => rented
                ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)))
                : _openForm(item),
            divider: false,
            thumb: ItemThumb(categoryName: item.categoryName, imageUrl: item.imageUrl, size: 84, radius: 14),
            title: item.name,
            subtitle: Text(tr(item.categoryName), style: kSub12),
            bottom: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PriceText(formatVnd(item.pricePerDay), unit: tr(' /ngày'), fontSize: 16),
                const SizedBox(height: 6),
                StatusBadge(itemStatusLabels[item.status] ?? item.status, statusColor(item.status)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
              onSelected: (v) => v == 'edit' ? _openForm(item) : _delete(item),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', enabled: !rented, child: Text(tr('Sửa'))),
                PopupMenuItem(value: 'delete', enabled: !rented, child: Text(tr('Xóa'))),
              ],
            ),
          ),
          if (item.status == 'Rejected' && (item.rejectionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            NoticeBox(
              tr('Lý do từ chối: {0}', [item.rejectionReason]),
              icon: Icons.feedback_outlined,
              color: statusColor('Rejected'),
            ),
          ],
          if (item.status == 'Unavailable') ...[
            const SizedBox(height: 4),
            NoticeBox(
              tr('Quản lý đã tạm ngưng đồ này. Liên hệ RentMate nếu cần hỗ trợ.'),
              icon: Icons.pause_circle_outline,
              color: statusColor('Unavailable'),
            ),
          ],
        ],
      ),
    );
  }
}
