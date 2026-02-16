import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // ตัวควบคุม TextField
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController(); // เฉพาะร้านค้า

  String _selectedRole = 'user'; // ค่าเริ่มต้นเป็น User
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. เช็คว่า Username ซ้ำไหม
      final check = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (check.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username นี้มีคนใช้แล้ว กรุณาเปลี่ยนใหม่")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. เตรียมข้อมูลพื้นฐาน (Common Data)
      Map<String, dynamic> userData = {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'name': _nameController.text.trim(),
        'role': _selectedRole,
        'created_at': FieldValue.serverTimestamp(),
      };

      // 3. กำหนดค่าเริ่มต้นตามบทบาท (Logic ที่คุณขอมา)
      if (_selectedRole == 'staff') {
        // --- กรณีเป็นเจ้าหน้าที่ (Staff) ---
        userData['budget'] = 10000;          // เงินตั้งต้น 10,000 บาท
        userData['collected_tokens'] = 0;    // แต้มที่รับซื้อมาเริ่มที่ 0
        userData['ocean_tokens'] = 0;        // กันเหนียวไว้เผื่อ UI เรียกใช้
      } else {
        // --- กรณีเป็นลูกค้า (User) หรือ ร้านค้า (Merchant) ---
        userData['ocean_tokens'] = 0;        // แต้มเริ่มที่ 0
      }

      // 4. กรณีร้านค้า ต้องมีชื่อร้าน
      if (_selectedRole == 'merchant') {
        userData['shop_name'] = _shopNameController.text.isNotEmpty
            ? _shopNameController.text.trim()
            : _nameController.text.trim(); // ถ้าไม่กรอกชื่อร้าน ให้ใช้ชื่อคนแทน
      }

      // 5. บันทึกลง Firebase
      await FirebaseFirestore.instance.collection('users').add(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ สมัครสมาชิกสำเร็จ!")),
        );
        Navigator.pop(context); // กลับไปหน้า Login
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("สมัครสมาชิกใหม่"),
        backgroundColor: const Color(0xFF0077B6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Icon(Icons.person_add, size: 80, color: Color(0xFF0077B6)),
              const SizedBox(height: 20),

              // Username
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username (สำหรับเข้าระบบ)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.isEmpty ? "กรุณากรอก Username" : null,
              ),
              const SizedBox(height: 15),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) => v == null || v.isEmpty ? "กรุณากรอก Password" : null,
              ),
              const SizedBox(height: 15),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "ชื่อ-นามสกุล (Display Name)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => v == null || v.isEmpty ? "กรุณากรอกชื่อ" : null,
              ),
              const SizedBox(height: 15),

              // Role Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: "เลือกบทบาท",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text("ผู้ใช้งานทั่วไป (User)")),
                  DropdownMenuItem(value: 'staff', child: Text("เจ้าหน้าที่ (Staff)")),
                  DropdownMenuItem(value: 'merchant', child: Text("ร้านค้า (Merchant)")),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedRole = v!;
                  });
                },
              ),

              // ถ้าเลือกเป็นร้านค้า ให้แสดงช่องกรอกชื่อร้านเพิ่ม
              if (_selectedRole == 'merchant') ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: _shopNameController,
                  decoration: const InputDecoration(
                    labelText: "ชื่อร้านค้า",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "กรุณากรอกชื่อร้านค้า" : null,
                ),
              ],

              const SizedBox(height: 30),

              // ปุ่มสมัครสมาชิก
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF0077B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ลงทะเบียน (Register)", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}