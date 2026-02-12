import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantShop extends StatefulWidget {
  final String userId; // ID ของร้านค้า (Merchant)
  const MerchantShop({super.key, required this.userId});

  @override
  State<MerchantShop> createState() => _MerchantShopState();
}

class _MerchantShopState extends State<MerchantShop> {
  // สินค้า/โปรโมชั่น ของร้าน (Mockup) - ในการใช้งานจริงสามารถดึงจาก DB ได้
  final List<Map<String, dynamic>> products = [
    {'name': 'ส่วนลด 20 บาท', 'cost': 100, 'icon': Icons.local_offer},
    {'name': 'ฟรี Topping', 'cost': 50, 'icon': Icons.icecream},
    {'name': 'แลกเครื่องดื่มฟรี', 'cost': 250, 'icon': Icons.local_drink},
    {'name': 'ถุงผ้าลดโลกร้อน', 'cost': 500, 'icon': Icons.shopping_bag},
  ];

  // ฟังก์ชันตัดแต้ม (Transaction)
  Future<void> _processRedemption(String customerUsername, String itemName, int cost) async {
    if (customerUsername.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final merchantRef = db.collection('users').doc(widget.userId);

    try {
      showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

      // 1. ค้นหาลูกค้าจาก Username
      final customerQuery = await db.collection('users')
          .where('username', isEqualTo: customerUsername)
          .limit(1)
          .get();

      if (customerQuery.docs.isEmpty) {
        throw Exception("ไม่พบลูกค้าชื่อ '$customerUsername'");
      }

      final customerDoc = customerQuery.docs.first;
      final customerRef = customerDoc.reference;

      // 2. เริ่ม Transaction (เพื่อความปลอดภัยข้อมูล)
      await db.runTransaction((transaction) async {
        DocumentSnapshot customerSnapshot = await transaction.get(customerRef);
        int currentPoints = customerSnapshot.get('ocean_tokens') ?? 0;

        // เช็คว่าแต้มพอไหม?
        if (currentPoints < cost) {
          throw Exception("ลูกค้ามีแต้มไม่พอ! (มีอยู่ $currentPoints Tokens)");
        }

        // ตัดแต้มลูกค้า
        transaction.update(customerRef, {'ocean_tokens': currentPoints - cost});

        // เพิ่มแต้ม/สถิติให้ร้านค้า (Optional: ร้านค้าอาจจะได้ Credit หรือแค่บันทึกยอด)
        // transaction.update(merchantRef, {'total_redeemed': FieldValue.increment(cost)});

        // บันทึกประวัติ Transaction
        transaction.set(db.collection('transactions').doc(), {
          'userId': customerDoc.id,       // ลูกค้าคนไหน
          'merchantId': widget.userId,    // ร้านไหน
          'type': 'Redeem: $itemName',    // แลกอะไร
          'amount': cost,                 // กี่แต้ม
          'is_income': false,             // เป็นรายจ่ายของลูกค้า
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context); // ปิด Loading
        Navigator.pop(context); // ปิด Dialog กรอกชื่อ
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("ตัดแต้มคุณ $customerUsername สำเร็จ! (-$cost)"),
          backgroundColor: Colors.green,
        ));
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ปิด Loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception:', '')}"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // Dialog ให้ร้านค้ากรอกชื่อลูกค้า
  void _showRedeemDialog(String itemName, int cost) {
    final usernameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            const Icon(Icons.qr_code_scanner, size: 50, color: Colors.orange),
            const SizedBox(height: 10),
            Text("แลกสิทธิ์: $itemName"),
            Text("ใช้ $cost Tokens", style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        content: TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: "ระบุ Username ลูกค้า",
            hintText: "เช่น user1",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => _processRedemption(usernameController.text, itemName, cost),
            child: const Text("ยืนยันตัดแต้ม"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Merchant POS System"), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: Column(
        children: [
          // Header ร้านค้า
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.orange.shade50,
            child: Column(
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
                  builder: (context, snapshot) {
                    var data = snapshot.data?.data() as Map<String, dynamic>?;
                    return Text("ร้าน: ${data?['name'] ?? 'Shop'}",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange));
                  },
                ),
                const Text("เลือกรายการด้านล่างเพื่อตัดแต้มลูกค้า"),
              ],
            ),
          ),

          // Grid รายการสินค้า
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final item = products[index];
                return InkWell(
                  onTap: () => _showRedeemDialog(item['name'], item['cost']),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item['icon'], size: 40, color: Colors.orange),
                        const SizedBox(height: 10),
                        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("${item['cost']} Tokens", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ประวัติการแลกล่าสุดของร้านนี้ (Real-time)
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("ประวัติการแลกวันนี้ (Today's Redemption)", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 200,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('merchantId', isEqualTo: widget.userId) // ดึงเฉพาะของร้านนี้
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("ยังไม่มีลูกค้ามาแลก"));

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.history, color: Colors.grey),
                      title: Text(data['type']), // เช่น Redeem: ส่วนลด 20 บาท
                      subtitle: Text("ตัดแต้มลูกค้าสำเร็จ"),
                      trailing: Text("-${data['amount']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}