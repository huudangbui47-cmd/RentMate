import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/item_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import 'account_screen.dart';
import 'item_detail_screen.dart';
import '../l10n/l10n.dart';

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
    final results = await Future.wait([AccountService().getPublicProfile(widget.userId), ItemService().getItems()]);
    final items = (results[1] as List<Item>).where((i) => i.ownerId == widget.userId).toList();
    return (results[0] as PublicProfile, items);
  }

  void _reload() => setState(() {
    _future = _load();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<(PublicProfile, List<Item>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(
              children: [
                RcHeroBar(title: tr('Hồ sơ')),
                const Expanded(child: LoadingView()),
              ],
            );
          }
          if (snap.hasError) {
            return Column(
              children: [
                RcHeroBar(title: tr('Hồ sơ')),
                Expanded(
                  child: ErrorView(message: errorText(snap.error!), onRetry: _reload),
                ),
              ],
            );
          }
          final (profile, items) = snap.data!;
          return ListView(
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
            children: [
              ProfileHeroHeader(
                title: tr('Hồ sơ'),
                name: profile.fullName,
                avatarUrl: profile.avatarUrl,
                onAvatar: profile.avatarUrl == null ? null : () => showImageViewer(context, profile.avatarUrl!),
                showCamera: false,
              ),
              const SizedBox(height: 10),
              Text(profile.fullName, textAlign: TextAlign.center, style: kText(20, FontWeight.w400)),
              Text(tr('Thành viên từ {0}', [fmtDate(profile.createdAt)]), textAlign: TextAlign.center, style: kSub12),
              const SizedBox(height: 16),
              RcCard(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('Đồ đang cho thuê ({0})', [items.length]),
                      style: kText(13, FontWeight.w300, color: AppColors.muted),
                    ),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(tr('Chưa có đồ nào đang cho thuê.'), style: kBody12Hint),
                      ),
                    for (var i = 0; i < items.length; i++)
                      ItemRow(
                        divider: i < items.length - 1,
                        thumb: ItemThumb(
                          categoryName: items[i].categoryName,
                          imageUrl: items[i].imageUrl,
                          size: 76,
                          radius: 14,
                        ),
                        title: items[i].name,
                        subtitle: Text(tr(items[i].categoryName), style: kSub12),
                        bottom: PriceText(formatVnd(items[i].pricePerDay), unit: tr(' /ngày'), fontSize: 15),
                        onTap: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: items[i].id))),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
