import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/favorite_service.dart';
import '../services/item_service.dart';
import '../theme.dart';
import '../widgets/kit.dart';
import '../widgets/ui.dart';
import 'item_detail_screen.dart';

/// Đồ đã bấm tim: lưới 2 cột thẻ trắng như "Popular vehicles" của mẫu. Bỏ tim là món biến mất khỏi danh sách.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Item>> _future = FavoriteService().getFavorites();

  Future<void> _reload() async {
    setState(() {
      _future = FavoriteService().getFavorites();
    });
    await _future;
  }

  Future<void> _open(Item item) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)));
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Yêu thích'))),
      body: FutureBuilder<List<Item>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          return ValueListenableBuilder<Set<int>>(
            valueListenable: FavoriteCenter.ids,
            builder: (context, ids, _) {
              final list = snap.data!.where((i) => ids.contains(i.id)).toList();
              return RefreshIndicator(
                onRefresh: _reload,
                child: list.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          RcCard(
                            child: EmptyView(
                              icon: Icons.favorite_border_rounded,
                              title: tr('Chưa có món yêu thích'),
                              subtitle: tr('Bấm hình trái tim ở món đồ để lưu lại xem sau.'),
                            ),
                          ),
                        ],
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 250,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _card(list[i]),
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _card(Item item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  RcSquareImage(url: item.imageUrl, categoryName: item.categoryName, radius: 10, inset: 0),
                  Positioned(top: -2, right: -2, child: FavoriteHeart(itemId: item.id)),
                  if (item.hasDeal)
                    Positioned(left: 0, bottom: 0, child: RcTag(tr('-{0}%', [item.discountPercent]), dark: true)),
                ],
              ),
              const Spacer(),
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kText(15, FontWeight.w400, lh: 20)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: formatVnd(item.pricePerDay), style: kText(15, FontWeight.w600, lh: 20)),
                    TextSpan(
                      text: tr('/ngày'),
                      style: kText(11, FontWeight.w300, color: AppColors.muted),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
