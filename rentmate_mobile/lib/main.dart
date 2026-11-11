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
      // Đã có token thì vào thẳng trang chủ, chưa có thì vào đăng nhập.
      home: FutureBuilder<String?>(
        future: AuthService().getToken(),
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
