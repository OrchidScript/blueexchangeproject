import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();

  String _selectedRole = 'user';
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // เช็ค username ซ้ำ
      final check = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (check.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username นี้มีคนใช้แล้ว")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // เตรียมข้อมูล
      Map<String, dynamic> userData = {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'name': _nameController.text.trim(),
        'role': _selectedRole,
        'ocean_tokens': 0,
        'created_at': FieldValue.serverTimestamp(),
      };

      // ถ้าเป็นร้านค้า
      if (_selectedRole == 'merchant') {
        userData['shop_name'] = _shopNameController.text.isNotEmpty
            ? _shopNameController.text.trim()
            : _nameController.text.trim();
      }

      // ถ้าเป็น Staff
      if (_selectedRole == 'staff') {
        userData['budget'] = 10000;
        userData['collected_tokens'] = 0;
      }

      await FirebaseFirestore.instance.collection('users').add(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("สมัครสมาชิกสำเร็จ!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
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
      appBar: AppBar(title: const Text("สมัครสมาชิกใหม่")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Username
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? "กรุณากรอก Username" : null,
              ),
              const SizedBox(height: 15),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? "กรุณากรอก Password" : null,
              ),
              const SizedBox(height: 15),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "ชื่อ-นามสกุล (Display Name)",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                v == null || v.isEmpty ? "กรุณากรอกชื่อ" : null,
              ),
              const SizedBox(height: 15),

              // Role
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: "เลือกบทบาท",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'user',
                    child: Text("ผู้ใช้งานทั่วไป (User)"),
                  ),
                  DropdownMenuItem(
                    value: 'staff',
                    child: Text("เจ้าหน้าที่ (Staff)"),
                  ),
                  DropdownMenuItem(
                    value: 'merchant',
                    child: Text("ร้านค้า (Merchant)"),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedRole = v!;
                  });
                },
              ),

              // ถ้าเป็นร้านค้า ให้กรอกชื่อร้าน
              if (_selectedRole == 'merchant') ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: _shopNameController,
                  decoration: const InputDecoration(
                    labelText: "ชื่อร้านค้า",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // ปุ่มสมัคร
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ลงทะเบียน (Register)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
