import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart'; // อย่าลืม import ไฟล์สมัครสมาชิก
import 'user_dashboard.dart';
import 'staff_station.dart';
import 'merchant_shop.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _login() async {
    setState(() => isLoading = true);
    try {
      // ค้นหา User จาก Username
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text)
          .where('password', isEqualTo: _passwordController.text)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception("Username หรือ Password ไม่ถูกต้อง");
      }

      var userDoc = query.docs.first;
      String role = userDoc['role'];
      String userId = userDoc.id; // ใช้ Document ID เป็น User ID จริงๆ

      if (!mounted) return;

      // แยกทางตาม Role
      if (role == 'user') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserDashboard(userId: userId)),
        );
      } else if (role == 'staff') {
        // Pass userId to StaffStation
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StaffStation(userId: userId)),
        );
      } else if (role == 'merchant') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MerchantShop(userId: userId)),
        );
      } else {
        throw Exception("Role ไม่ถูกต้อง");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(
                Icons.recycling_rounded,
                size: 80,
                color: Color(0xFF0077B6),
              ),
              const SizedBox(height: 10),
              const Text(
                "Blue Exchange",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0077B6),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF0077B6),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("เข้าสู่ระบบ"),
                    ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text("ยังไม่มีบัญชี? สมัครสมาชิกใหม่"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
