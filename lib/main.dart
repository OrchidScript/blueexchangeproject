import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

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
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0077B6)),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // รวมหน้าจอหลักตาม Proposal [cite: 26, 27, 60]
  final List<Widget> _screens = [
    const UserHome(),      // หน้า 7.1 - 7.4 สำหรับผู้ใช้
    const StaffScreen(),   // หน้า 7.5 - 7.6 สำหรับเจ้าหน้าที่
    const MerchantScreen(),// หน้า 7.7 - 7.8 สำหรับร้านค้า
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'User'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Staff'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Merchant'),
        ],
      ),
    );
  }
}

// --- 1. ส่วนของผู้ใช้ (User Section: 7.1 - 7.4) ---

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blue Exchange"), actions: [IconButton(icon: const Icon(Icons.notifications), onPressed: (){})]),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 7.1 หน้าจอหลัก & ยอด Ocean Token [cite: 37, 41]
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0077B6), Color(0xFF00B4D8)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Text("ยอด Ocean Token ของคุณ", style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 8),
                  Text("1,250", style: TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold)),
                  Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.eco, color: Colors.greenAccent), Text(" รักษ์โลกกับเราวันนี้", style: TextStyle(color: Colors.white))],
                  )
                ],
              ),
            ),

            // 7.2 หน้าจอคู่มือแลก [cite: 42, 44]
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: GuideCard(icon: Icons.cleaning_services, text: "ล้าง-แยก")),
                  Expanded(child: GuideCard(icon: Icons.location_on, text: "ไปจุดรับ")),
                  Expanded(child: GuideCard(icon: Icons.qr_code, text: "รับแต้ม")),
                ],
              ),
            ),

            // 7.1 Interactive Map (Mockup) 
            const ListTile(title: Text("จุดรับขยะใกล้คุณ (Nearest Collection Points)", style: TextStyle(fontWeight: FontWeight.bold))),
            Container(
              height: 150,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: const Center(child: Icon(Icons.map_outlined, size: 50, color: Colors.blue)),
            ),

            // 7.3 ค้นหาร้านค้า (Partner Directory) [cite: 48]
            const ListTile(title: Text("ร้านค้าพาร์ทเนอร์แนะนำ", style: TextStyle(fontWeight: FontWeight.bold))),
            const ShopItem(name: "Green Leaf Cafe", promo: "ลด 20.- (ใช้ 100 Tokens)"),
            const ShopItem(name: "Eco Mart", promo: "แลกถุงผ้าฟรี (ใช้ 500 Tokens)"),
          ],
        ),
      ),
    );
  }
}

// --- 2. ส่วนของเจ้าหน้าที่ (Staff Section: 7.5 - 7.6) ---

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String selectedType = "Plastic";
  double weight = 0.0;
  int calculatedTokens = 0;

  // 7.2 อัตราแลกเปลี่ยนขยะ [cite: 44, 45]
  final Map<String, int> rates = {"Plastic": 10, "Glass": 15, "Aluminum": 25};

  void _calculate() {
    setState(() {
      calculatedTokens = (weight * (rates[selectedType] ?? 0)).toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Staff: จุดรับแลก Blue Station")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("บันทึกการรับขยะเพื่อโอน Ocean Token [cite: 29]", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            // 7.6 เลือกประเภทขยะ 
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "ประเภทขยะ"),
              items: rates.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) { selectedType = v!; _calculate(); },
            ),
            const SizedBox(height: 15),
            // 7.6 กรอกน้ำหนัก 
            TextField(
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "น้ำหนัก (กิโลกรัม)", suffixText: "kg"),
              keyboardType: TextInputType.number,
              onChanged: (v) { weight = double.tryParse(v) ?? 0.0; _calculate(); },
            ),
            const Spacer(),
            // 7.6 แสดงผลคำนวณอัตโนมัติ 
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  const Text("คะแนนที่จะได้รับ"),
                  Text("$calculatedTokens Tokens", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("โอน Tokens สำเร็จ! [cite: 29]"))),
              child: const Text("ยืนยันการโอน Token (Confirm)"),
            )
          ],
        ),
      ),
    );
  }
}

// --- 3. ส่วนของร้านค้า (Merchant Section: 7.7 - 7.8) ---

class MerchantScreen extends StatelessWidget {
  const MerchantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Merchant: จัดการร้านค้า")),
      body: Column(
        children: [
          // 7.8 Shop Dashboard [cite: 65]
          const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatBox(label: "ลูกค้าวันนี้", value: "15"),
                  StatBox(label: "Tokens ที่ได้รับ", value: "256"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.qr_code_scanner, size: 100, color: Colors.blueGrey),
          const SizedBox(height: 10),
          ElevatedButton.icon(
              onPressed: (){},
              icon: const Icon(Icons.camera_alt),
              label: const Text("สแกนเพื่อรับสิทธิ์ส่วนลด [cite: 65]")
          ),
          const ListTile(title: Text("ประวัติการแลกสิทธิ์ล่าสุด", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView(
              children: const [
                ListTile(leading: Icon(Icons.history), title: Text("คุณจิรพันธุ์ ใช้ 100 Tokens"), subtitle: Text("2 นาทีที่แล้ว"), trailing: Text("-20฿", style: TextStyle(color: Colors.red))),
                ListTile(leading: Icon(Icons.history), title: Text("คุณนิสาชล ใช้ 100 Tokens"), subtitle: Text("15 นาทีที่แล้ว"), trailing: Text("-20฿", style: TextStyle(color: Colors.red))),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- Widgets เสริมเพื่อความเป็นระเบียบ ---

class GuideCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const GuideCard({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(8.0), child: Column(children: [Icon(icon, color: Colors.blue), Text(text, style: const TextStyle(fontSize: 12))])));
  }
}

class ShopItem extends StatelessWidget {
  final String name, promo;
  const ShopItem({super.key, required this.name, required this.promo});
  @override
  Widget build(BuildContext context) {
    return ListTile(leading: const CircleAvatar(child: Icon(Icons.restaurant)), title: Text(name), subtitle: Text(promo), trailing: const Icon(Icons.chevron_right));
  }
}

class StatBox extends StatelessWidget {
  final String label, value;
  const StatBox({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]);
  }
}