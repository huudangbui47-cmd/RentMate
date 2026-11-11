import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';

/// Hai tab: đơn mình đi thuê, và đơn người khác thuê đồ của mình.
class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen> {
  late Future<(List<Rental>, String)> _future = _load();

  Future<(List<Rental>, String)> _load() async {
    final userId = await AuthService().getUserId();
    if (userId == null) throw Exception('Bạn cần đăng nhập lại');
    return (await RentalService().getMyRentals(), userId);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _act(Rental r, String action, String doneText) async {
    try {
      await RentalService().updateStatus(r.id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneText)));
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn thuê'),
          bottom: const TabBar(tabs: [Tab(text: 'Tôi đi thuê'), Tab(text: 'Đồ tôi cho thuê')]),
        ),
        body: FutureBuilder<(List<Rental>, String)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snap.error.toString().replaceFirst('Exception: ', '')),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _reload, child: const Text('Thử lại')),
                  ],
                ),
              );
            }
            final (rentals, userId) = snap.data!;
            return TabBarView(children: [
              _list(rentals.where((r) => r.renterId == userId).toList(), isOwner: false,
                  empty: 'Bạn chưa thuê đồ nào'),
              _list(rentals.where((r) => r.ownerId == userId).toList(), isOwner: true,
                  empty: 'Chưa có ai thuê đồ của bạn'),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(List<Rental> rentals, {required bool isOwner, required String empty}) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: rentals.isEmpty
          ? ListView(children: [const SizedBox(height: 120), Center(child: Text(empty))])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rentals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _card(rentals[i], isOwner),
            ),
    );
  }

  Widget _card(Rental r, bool isOwner) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Chip(
                  label: Text(rentalStatusLabels[r.status] ?? r.status),
                  backgroundColor: _statusColor(r.status),
                ),
              ],
            ),
            Text('${_fmt(r.startDate)}  →  ${_fmt(r.endDate)}'),
            Text('Tiền thuê: ${formatVnd(r.totalPrice)} · Cọc: ${formatVnd(r.depositAmount)}'),
            Text(isOwner ? 'Người thuê: ${r.renterName}' : 'Chủ đồ: ${r.ownerName}',
                style: const TextStyle(color: Colors.grey)),
            if (r.requestNote != null && r.requestNote!.isNotEmpty)
              Text('Ghi chú: ${r.requestNote}', style: const TextStyle(color: Colors.grey)),
            ..._actions(r, isOwner),
          ],
        ),
      ),
    );
  }

  // Ai được bấm nút nào: theo kiểm tra quyền trong RentalService.cs.
  List<Widget> _actions(Rental r, bool isOwner) {
    final buttons = <Widget>[
      if (isOwner && r.status == 'Pending') ...[
        OutlinedButton(
            onPressed: () => _act(r, 'reject', 'Đã từ chối yêu cầu'), child: const Text('Từ chối')),
        FilledButton(
            onPressed: () => _act(r, 'approve', 'Đã duyệt yêu cầu'), child: const Text('Duyệt')),
      ],
      if (isOwner && (r.status == 'Approved' || r.status == 'WaitingForPickup'))
        FilledButton(
            onPressed: () => _act(r, 'pickup', 'Đã xác nhận giao đồ'),
            child: const Text('Đã giao đồ')),
      if (!isOwner && r.status == 'Rented')
        FilledButton(
            onPressed: () => _act(r, 'return', 'Đã báo trả đồ'), child: const Text('Trả đồ')),
      if (isOwner && r.status == 'Returned')
        FilledButton(
            onPressed: () => _act(r, 'complete', 'Đơn đã hoàn tất'), child: const Text('Hoàn tất')),
    ];
    if (buttons.isEmpty) return [];
    return [
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.end, spacing: 8, children: buttons),
    ];
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _statusColor(String s) => switch (s) {
        'Pending' => Colors.orange.shade100,
        'Rejected' => Colors.red.shade100,
        'Completed' || 'Returned' => Colors.grey.shade300,
        _ => Colors.green.shade100,
      };
}