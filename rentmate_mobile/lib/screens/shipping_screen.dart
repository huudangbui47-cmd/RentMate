import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/shipping_service.dart';
import '../widgets/ui.dart';
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
    setState(() { _future = ShippingService().tracking(widget.rental.id); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Giao nhận · Đơn #{0}', [widget.rental.id]))),
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
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(ship ? Icons.local_shipping_outlined : Icons.handshake_outlined),
                          const SizedBox(width: 8),
                          Text(ship ? tr('Giao Hàng Nhanh (GHN)') : tr('Gặp trực tiếp'),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ]),
                        if (t.statusText != null) ...[
                          const SizedBox(height: 8),
                          Text(t.statusText!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                        ],
                        if (t.orderCode != null) InfoRow(tr('Mã vận đơn'), t.orderCode!),
                        if (t.expectedDeliveryAt != null) InfoRow(tr('Dự kiến giao'), fmtDate(t.expectedDeliveryAt!.toLocal())),
                        if (t.shippingFee != null) InfoRow(tr('Phí ship (RentMate trả)'), formatVnd(t.shippingFee!)),
                        if (t.shipToText != null) ...[
                          const SizedBox(height: 6),
                          Text(tr('Giao đến: {0}', [t.shipToText])),
                        ],
                      ],
                    ),
                  ),
                ),
                if (t.warning != null) ...[
                  const SizedBox(height: 8),
                  NoticeBox(t.warning!, color: const Color(0xFFE08A00)),
                ],
                const SizedBox(height: 16),
                for (var i = 0; i < t.steps.length; i++) _step(t.steps[i], isLast: i == t.steps.length - 1),
                const SizedBox(height: 12),
                NoticeBox(tr('Ngày thuê tính từ lúc người thuê bấm "Đã nhận đồ". Đồ đến trễ thì hạn trả tự lùi lại, hoặc hoàn tiền những ngày bị mất nếu đã có người thuê sau.')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _step(ShippingStep s, {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;
    final color = s.done ? scheme.primary : scheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              Icon(s.done ? Icons.check_circle : Icons.radio_button_unchecked, color: color, size: 22),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      style: TextStyle(fontWeight: FontWeight.w600, color: s.done ? null : scheme.onSurfaceVariant)),
                  if (s.detail != null) Text(s.detail!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  if (s.time != null)
                    Text(fmtDateTime(s.time!), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
