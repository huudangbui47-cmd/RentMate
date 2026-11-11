import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const RentMateApp());
}

class RentMateApp extends StatelessWidget {
  const RentMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RentMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      // Kiểm tra userId (lưu cùng token khi đăng nhập): phiên cũ chưa có userId sẽ phải đăng nhập lại.
      home: FutureBuilder<String?>(
        future: AuthService().getUserId(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.data == null ? const LoginScreen() : const HomeScreen();
        },
      ),
    );
  }
}