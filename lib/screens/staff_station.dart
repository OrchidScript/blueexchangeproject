import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffStation extends StatefulWidget {
  final String userId; // Staff ID (ใช้ตัด budget)
  const StaffStation({super.key, required this.userId});

  @override
  State<StaffStation> createState() => _StaffStationState();
}

class _StaffStationState extends State<StaffStation>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // ---------------- BUY WASTE ----------------
  final _usernameController = TextEditingController();
  final _weightController = TextEditingController();
  String selectedType = 'Plastic';
  int calculatedTokens = 0;
  bool isLoading = false;

  final Map<String, int> rates = {
    'Plastic': 10,
    'Glass': 15,
    'Paper': 5,
    'Aluminum': 25,
  };

  // ---------------- CASH OUT ----------------
  final _merchantUsernameController = TextEditingController();
  final _cashOutPointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // ==============================
  // 1️⃣ คำนวณแต้มจากน้ำหนัก
  // ==============================
  void _calculate() {
    double weight = double.tryParse(_weightController.text) ?? 0.0;
    setState(() {
      calculatedTokens =
          (weight * (rates[selectedType] ?? 0)).toInt();
    });
  }

  // ==============================
  // 2️⃣ รับซื้อขยะ (Mint Tokens)
  // ==============================
  Future<void> _buyWaste() async {
    if (calculatedTokens <= 0 ||
        _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรอกข้อมูลให้ครบ")),
      );
      return;
    }

    setState(() => isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      final userQuery = await db
          .collection('users')
          .where('username',
          isEqualTo: _usernameController.text)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception("ไม่พบผู้ใช้");
      }

      final userDoc = userQuery.docs.first;
      final userRef = userDoc.reference;

      await db.runTransaction((transaction) async {
        DocumentSnapshot snapshot =
        await transaction.get(userRef);

        int newBalance =
            (snapshot.get('ocean_tokens') ?? 0) +
                calculatedTokens;

        transaction.update(userRef,
            {'ocean_tokens': newBalance});

        transaction.set(
            db.collection('transactions').doc(), {
          'userId': userDoc.id,
          'staffId': widget.userId,
          'type': 'Sell Waste: $selectedType',
          'weight':
          double.tryParse(_weightController.text) ??
              0.0,
          'amount': calculatedTokens,
          'is_income': true,
          'timestamp':
          FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(
                "โอน $calculatedTokens แต้มสำเร็จ")));
        _usernameController.clear();
        _weightController.clear();
        setState(() => calculatedTokens = 0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text("$e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ==============================
  // 3️⃣ ร้านค้า Cash Out
  // ==============================
  Future<void> _merchantCashOut() async {
    int points =
        int.tryParse(_cashOutPointsController.text) ??
            0;
    String merchantName =
        _merchantUsernameController.text;

    if (points <= 0 || merchantName.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final staffRef =
    db.collection('users').doc(widget.userId);

    try {
      final merchantQuery = await db
          .collection('users')
          .where('username',
          isEqualTo: merchantName)
          .limit(1)
          .get();

      if (merchantQuery.docs.isEmpty) {
        throw Exception("ไม่พบร้านค้า");
      }

      final merchantDoc =
          merchantQuery.docs.first;
      final merchantRef =
          merchantDoc.reference;

      await db.runTransaction((transaction) async {
        DocumentSnapshot staffSnap =
        await transaction.get(staffRef);
        int currentBudget =
            staffSnap.get('budget') ?? 0;
        int collected =
            staffSnap.get('collected_tokens') ?? 0;

        DocumentSnapshot merchantSnap =
        await transaction.get(merchantRef);
        int merchantTokens =
            merchantSnap.get('ocean_tokens') ?? 0;

        int cashToPay = points; // 1:1 rate

        if (merchantTokens < points) {
          throw Exception("แต้มร้านค้าไม่พอ");
        }
        if (currentBudget < cashToPay) {
          throw Exception(
              "งบ Staff ไม่พอ ($currentBudget)");
        }

        // 1. หักแต้มร้านค้า
        transaction.update(merchantRef, {
          'ocean_tokens':
          merchantTokens - points
        });

        // 2. หักงบ Staff + เก็บแต้มคืนระบบ
        transaction.update(staffRef, {
          'budget':
          currentBudget - cashToPay,
          'collected_tokens':
          collected + points,
        });

        // 3. บันทึกประวัติ
        transaction.set(
            db.collection('transactions').doc(), {
          'type': 'Merchant Cash Out',
          'staffId': widget.userId,
          'merchantId': merchantDoc.id,
          'amount': points,
          'cash_paid': cashToPay,
          'timestamp':
          FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(
                "จ่ายเงิน $points บาท สำเร็จ")));
        _merchantUsernameController.clear();
        _cashOutPointsController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text("$e")),
      );
    }
  }

  // ==============================
  // UI
  // ==============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff System"),
        backgroundColor: Colors.green,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "รับซื้อขยะ"),
            Tab(text: "ร้านค้า Cash Out"),
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

  // ---------------- BUY WASTE TAB ----------------

  Widget _buildBuyWasteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: "Username ลูกค้า",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: selectedType,
            items: rates.keys
                .map((e) => DropdownMenuItem(
              value: e,
              child: Text(
                  "$e (${rates[e]} Tokens/kg)"),
            ))
                .toList(),
            onChanged: (val) {
              setState(() =>
              selectedType = val!);
              _calculate();
            },
            decoration: const InputDecoration(
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _weightController,
            keyboardType:
            TextInputType.number,
            decoration:
            const InputDecoration(
              labelText: "น้ำหนัก (kg)",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 20),
          Text(
            "$calculatedTokens Tokens",
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
            isLoading ? null : _buyWaste,
            style: ElevatedButton.styleFrom(
                backgroundColor:
                Colors.green),
            child: const Text(
              "ยืนยันโอนแต้ม",
              style:
              TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- CASH OUT TAB ----------------

  Widget _buildCashOutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore
                  .instance
                  .collection('users')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                var data = snapshot.data
                    ?.data()
                as Map<String, dynamic>?;
                int budget =
                    data?['budget'] ?? 0;
                int collected =
                    data?['collected_tokens'] ??
                        0;

                return Container(
                  padding:
                  const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.orange
                          .shade100,
                      borderRadius:
                      BorderRadius.circular(
                          15)),
                  child: Column(
                    children: [
                      Text(
                          "งบคงเหลือ: $budget ฿"),
                      Text(
                          "แต้มเก็บคืน: $collected"),
                    ],
                  ),
                );
              }),
          const SizedBox(height: 20),
          TextField(
            controller:
            _merchantUsernameController,
            decoration: const InputDecoration(
              labelText:
              "Username ร้านค้า",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller:
            _cashOutPointsController,
            keyboardType:
            TextInputType.number,
            decoration: const InputDecoration(
              labelText:
              "จำนวนแต้มที่แลก",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _merchantCashOut,
            style: ElevatedButton.styleFrom(
                backgroundColor:
                Colors.orange),
            child: const Text(
              "ยืนยันจ่ายเงินสด",
              style:
              TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
