import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/shipping_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import '../l10n/l10n.dart';

/// Dòng thời gian giao nhận của một đơn: mốc của RentMate + các mốc GHN báo về.
class ShippingScreen extends StatefulWidget {
  final Rental rental;
  const ShippingScreen({super.key, required this.rental});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  late Future<ShippingTracking> _future = ShippingService().tracking(widget.rental.id);

  Future<void> _reload() async {
    setState(() {
      _future = ShippingService().tracking(widget.rental.id);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Giao nhận'))),
      body: FutureBuilder<ShippingTracking>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final t = snap.data!;
          final ship = t.deliveryMethod == 'Ghn';
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                RcCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RcIconCircle(ship ? Icons.local_shipping_outlined : Icons.handshake_outlined, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ship ? tr('Giao Hàng Nhanh (GHN)') : tr('Gặp trực tiếp'),
                                  style: kText(16, FontWeight.w400),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr('Đơn #{0}', [widget.rental.id]),
                                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (t.statusText != null) ...[
                        const SizedBox(height: 12),
                        StatusBadge(t.statusText!, AppColors.info),
                      ],
                      if (t.orderCode != null || t.expectedDeliveryAt != null || t.shippingFee != null)
                        const Divider(height: 24),
                      if (t.orderCode != null) InfoRow(tr('Mã vận đơn'), t.orderCode!),
                      if (t.expectedDeliveryAt != null)
                        InfoRow(tr('Dự kiến giao'), fmtDate(t.expectedDeliveryAt!.toLocal())),
                      if (t.shippingFee != null) InfoRow(tr('Phí ship (RentMate trả)'), formatVnd(t.shippingFee!)),
                      if (t.shipToText != null) ...[
                        const SizedBox(height: 8),
                        LocationText(tr('Giao đến: {0}', [t.shipToText])),
                      ],
                    ],
                  ),
                ),
                if (t.warning != null) ...[const SizedBox(height: 12), NoticeBox(t.warning!, color: AppColors.warning)],
                const SizedBox(height: 12),
                // Dòng thời gian trong khối trắng có nhãn xám
                RcCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tr('Tiến trình'), style: kText(13, FontWeight.w300, color: AppColors.muted)),
                      const SizedBox(height: 14),
                      for (var i = 0; i < t.steps.length; i++) _step(t.steps[i], isLast: i == t.steps.length - 1),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NoticeBox(
                  tr(
                    'Ngày thuê tính từ lúc người thuê bấm "Đã nhận đồ". Đồ đến trễ thì hạn trả tự lùi lại, hoặc hoàn tiền những ngày bị mất nếu đã có người thuê sau.',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _step(ShippingStep s, {required bool isLast}) {
    final color = s.done ? AppColors.primary : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.done ? AppColors.primary : Colors.white,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: s.done ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      color: s.done ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                  if (s.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(s.detail!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                  if (s.time != null) ...[
                    const SizedBox(height: 2),
                    Text(fmtDateTime(s.time!), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
