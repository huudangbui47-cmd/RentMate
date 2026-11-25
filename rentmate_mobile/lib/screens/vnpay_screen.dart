import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/payment_service.dart';
import '../widgets/ui.dart';
import '../l10n/l10n.dart';

/// Mở trang thanh toán VNPay ngay trong app. Khi VNPay chuyển về trang kết quả của RentMate
/// thì hiện kết quả đó, người dùng bấm "Xong" để quay lại (trả về true).
///
/// Thẻ test sandbox: ngân hàng NCB, số thẻ 9704198526191432198, tên NGUYEN VAN A,
/// ngày phát hành 07/15, OTP 123456.
class VnPayScreen extends StatefulWidget {
  final String paymentUrl;
  const VnPayScreen({super.key, required this.paymentUrl});

  @override
  State<VnPayScreen> createState() => _VnPayScreenState();
}

class _VnPayScreenState extends State<VnPayScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _loading = true; }),
        onPageFinished: (url) => setState(() {
          _loading = false;
          if (url.contains(PaymentService.returnPath)) _finished = true;
        }),
        onWebResourceError: (e) {
          if (mounted && e.isForMainFrame == true) showSnack(context, tr('Không tải được trang thanh toán: {0}', [e.description]), error: true);
        },
      ))
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_finished);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Thanh toán VNPay')),
          actions: [
            if (_finished)
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(tr('Xong'))),
          ],
          bottom: _loading ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator()) : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
