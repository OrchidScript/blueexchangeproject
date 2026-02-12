import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart'; // เรียกใช้หน้า Login ที่เราแยกไว้

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BlueExchangeApp());
}

class BlueExchangeApp extends StatelessWidget {
  const BlueExchangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blue Exchange',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0077B6)),
        scaffoldBackgroundColor: const Color(0xFFF5F9FC),
      ),
      home: const LoginScreen(), // เริ่มต้นที่หน้า Login
    );
  }
}