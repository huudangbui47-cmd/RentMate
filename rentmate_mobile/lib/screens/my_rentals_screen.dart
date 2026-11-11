import 'package:flutter/material.dart';

import '../services/item_service.dart';
import '../services/rental_service.dart';

class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen> {
  late Future<List<Rental>> _future = RentalService().getMyRentals();

  Future<void> _reload() async {
    setState(() => _future = RentalService().getMyRentals());
    await _future;
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _statusColor(String s) => switch (s) {
        'Pending' => Colors.orange.shade100,
        'Rejected' || 'Cancelled' => Colors.red.shade100,
        'Completed' || 'Returned' => Colors.grey.shade300,
        _ => Colors.green.shade100,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn thuê của tôi')),
      body: FutureBuilder<List<Rental>>(
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
          final rentals = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: rentals.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Bạn chưa có đơn thuê nào')),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rentals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = rentals[i];
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  Chip(
                                    label: Text(rentalStatusLabels[r.status] ?? r.status),
                                    backgroundColor: _statusColor(r.status),
                                  ),
                                ],
                              ),
                              Text('${_fmt(r.startDate)}  →  ${_fmt(r.endDate)}'),
                              Text('Tiền thuê: ${formatVnd(r.totalPrice)} · Cọc: ${formatVnd(r.depositAmount)}'),
                              Text('Chủ đồ: ${r.ownerName}',
                                  style: const TextStyle(color: Colors.grey)),
                              if (r.requestNote != null && r.requestNote!.isNotEmpty)
                                Text('Ghi chú: ${r.requestNote}',
                                    style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
