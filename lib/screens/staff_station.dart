import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart'; // ใช้สำหรับปุ่ม Logout

class StaffStation extends StatefulWidget {
  final String userId; // Staff ID
  const StaffStation({super.key, required this.userId});

  @override
  State<StaffStation> createState() => _StaffStationState();
}

class _StaffStationState extends State<StaffStation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Tab 1: Buy Waste
  final _usernameController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedType = 'Plastic';
  int _calculatedTokens = 0;
  final Map<String, int> _rates = {
    'Plastic': 10,
    'Glass': 15,
    'Paper': 5,
    'Aluminum': 25,
  };

  // Tab 2: Cash Out
  final _merchantSearchController = TextEditingController();
  final _cashOutPointsController = TextEditingController();

  Map<String, dynamic>? _foundMerchantData;
  String? _foundMerchantId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _weightController.dispose();
    _merchantSearchController.dispose();
    _cashOutPointsController.dispose();
    super.dispose();
  }

  // --- Logic ---

  void _calculateTokens() {
    double weight = double.tryParse(_weightController.text) ?? 0.0;
    setState(() {
      _calculatedTokens = (weight * (_rates[_selectedType] ?? 0)).toInt();
    });
  }

  Future<void> _searchMerchant() async {
    String username = _merchantSearchController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundMerchantData = null;
      _foundMerchantId = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .where('role', isEqualTo: 'merchant')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception("ไม่พบร้านค้าชื่อ '$username'");
      }

      setState(() {
        _foundMerchantData = query.docs.first.data();
        _foundMerchantId = query.docs.first.id;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buyWaste() async {
    if (_calculatedTokens <= 0 || _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบ")));
      return;
    }
    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;
    try {
      final userQuery = await db.collection('users').where('username', isEqualTo: _usernameController.text.trim()).limit(1).get();
      if (userQuery.docs.isEmpty) throw Exception("ไม่พบผู้ใช้");
      final userDoc = userQuery.docs.first;

      await db.runTransaction((transaction) async {
        final staffRef = db.collection('users').doc(widget.userId);
        final userSnap = await transaction.get(userDoc.reference);
        final staffSnap = await transaction.get(staffRef);

        int newBalance = (userSnap.get('ocean_tokens') ?? 0) + _calculatedTokens;
        transaction.update(userDoc.reference, {'ocean_tokens': newBalance});

        transaction.set(db.collection('transactions').doc(), {
          'userId': userDoc.id,
          'staffId': widget.userId,
          'type': 'Sell Waste: $_selectedType',
          'weight': double.tryParse(_weightController.text) ?? 0.0,
          'amount': _calculatedTokens,
          'is_income': true,
          'timestamp': FieldValue.serverTimestamp(),
          'customerName': userSnap.get('name') ?? _usernameController.text,
          'staffName': staffSnap.get('name') ?? 'Staff',
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ทำรายการสำเร็จ"), backgroundColor: Colors.green));
        _usernameController.clear();
        _weightController.clear();
        setState(() => _calculatedTokens = 0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _merchantCashOut() async {
    if (_foundMerchantData == null || _foundMerchantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณาค้นหาร้านค้าก่อน")));
      return;
    }

    final points = int.tryParse(_cashOutPointsController.text) ?? 0;
    if (points <= 0) return;

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;
    final staffRef = db.collection('users').doc(widget.userId);
    final merchantRef = db.collection('users').doc(_foundMerchantId);

    try {
      await db.runTransaction((transaction) async {
        final staffSnap = await transaction.get(staffRef);
        final merchantSnap = await transaction.get(merchantRef);

        int currentBudget = staffSnap.get('budget') ?? 0;
        int collected = staffSnap.get('collected_tokens') ?? 0;
        int merchantTokens = merchantSnap.get('ocean_tokens') ?? 0;
        int cashToPay = points;

        if (merchantTokens < points) throw Exception("ร้านค้ามีแต้มไม่พอ");
        if (currentBudget < cashToPay) throw Exception("งบ Staff ไม่พอจ่าย");

        transaction.update(merchantRef, {'ocean_tokens': merchantTokens - points});
        transaction.update(staffRef, {
          'budget': currentBudget - cashToPay,
          'collected_tokens': collected + points,
        });

        transaction.set(db.collection('transactions').doc(), {
          'type': 'Merchant Cash Out',
          'staffId': widget.userId,
          'merchantId': _foundMerchantId,
          'amount': points,
          'cash_paid': cashToPay,
          'timestamp': FieldValue.serverTimestamp(),
          'staffName': staffSnap.get('name') ?? 'Staff',
          'shopName': merchantSnap.get('shop_name') ?? 'Shop',
        });
      });

      if (mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text("✅ จ่ายเงินสดสำเร็จ"),
          // แก้ไขตรงนี้: ใช้ตัวแปร points แทน cashToPay ที่มองไม่เห็น
          content: Text("จ่ายเงิน $points บาท\nให้ร้าน ${_foundMerchantData!['shop_name']}"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("ปิด"))],
        ));
        _cashOutPointsController.clear();
        _merchantSearchController.clear();
        setState(() {
          _foundMerchantData = null;
          _foundMerchantId = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff System"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.eco), text: "รับซื้อขยะ"),
            Tab(icon: Icon(Icons.currency_exchange), text: "แลกเงินร้านค้า"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuyWasteTab(),
          _buildCashOutTab(),
        ],
      ),
    );
  }

  Widget _buildBuyWasteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("คำนวณราคาขยะ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TextField(controller: _usernameController, decoration: const InputDecoration(labelText: "Username ลูกค้า", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField(
                  value: _selectedType,
                  items: _rates.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (v) { setState(() => _selectedType = v!); _calculateTokens(); },
                  decoration: const InputDecoration(labelText: "ประเภท", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "นน. (kg)", border: OutlineInputBorder()),
                  onChanged: (_) => _calculateTokens(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("ได้รับแต้ม:", style: TextStyle(fontSize: 16)),
                Text("$_calculatedTokens Tokens", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _buyWaste,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("ยืนยันการโอน"),
          )
        ],
      ),
    );
  }

  Widget _buildCashOutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBudgetStatus(),
          const SizedBox(height: 20),
          const Text("1. ค้นหาร้านค้า", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(child: TextField(controller: _merchantSearchController, decoration: const InputDecoration(labelText: "Username ร้านค้า", border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)))),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _isLoading ? null : _searchMerchant, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 55)), child: const Icon(Icons.search))
            ],
          ),
          if (_foundMerchantData != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(10), color: Colors.orange.shade50),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 40),
                  Text(_foundMerchantData!['shop_name'] ?? 'ร้านค้า', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("แต้มสะสม: ${NumberFormat('#,##0').format(_foundMerchantData!['ocean_tokens'] ?? 0)} Tokens", style: const TextStyle(color: Colors.deepOrange)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("2. ระบุจำนวนเงิน", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _cashOutPointsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "จำนวนแต้ม (1:1)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _merchantCashOut,
              icon: const Icon(Icons.payments),
              label: const Text("ยืนยันจ่ายเงินสด"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var data = snapshot.data!.data() as Map<String, dynamic>;
        return Row(
          children: [
            Expanded(child: _statCard("งบคงเหลือ", "${NumberFormat('#,##0').format(data['budget'] ?? 0)} ฿", Colors.red)),
            const SizedBox(width: 10),
            Expanded(child: _statCard("แต้มเข้าระบบ", "${NumberFormat('#,##0').format(data['collected_tokens'] ?? 0)} P", Colors.blue)),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [Text(title, style: TextStyle(color: color)), Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))]),
    );
  }
}