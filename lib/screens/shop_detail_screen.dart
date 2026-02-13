import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ShopDetailScreen extends StatefulWidget {
  final String userId;       // ID ลูกค้า (คนจ่ายตังค์)
  final String merchantId;   // ID ร้านค้า (คนรับตังค์/เจ้าของสินค้า)
  final String merchantName; // ชื่อร้าน

  const ShopDetailScreen({
    super.key,
    required this.userId,
    required this.merchantId,
    required this.merchantName
  });

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {

  // ฟังก์ชันแลกสินค้า
  Future<void> _redeemItem(Map<String, dynamic> item) async {
    String itemName = item['name'];
    int cost = item['cost'];

    // 1. ถามยืนยันก่อน
    bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("ยืนยันแลก: $itemName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("คุณต้องการใช้แต้มแลกสินค้านี้ใช่ไหม?"),
              const SizedBox(height: 10),
              Text("ราคา: ${NumberFormat('#,##0').format(cost)} Tokens",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ยกเลิก")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("ยืนยัน"),
            ),
          ],
        )
    ) ?? false;

    if (!confirm) return;

    // 2. เริ่มกระบวนการโอนเหรียญ (Transaction)
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(widget.userId);
    final merchantRef = db.collection('users').doc(widget.merchantId);

    try {
      showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

      await db.runTransaction((transaction) async {
        DocumentSnapshot userSnap = await transaction.get(userRef);
        DocumentSnapshot merchantSnap = await transaction.get(merchantRef);

        if (!userSnap.exists) throw Exception("ไม่พบข้อมูลผู้ใช้");

        int userBalance = userSnap.get('ocean_tokens') ?? 0;
        int merchantBalance = merchantSnap.get('ocean_tokens') ?? 0;
        String customerName = userSnap.get('name') ?? 'ลูกค้า';

        if (userBalance < cost) {
          throw Exception("แต้มของคุณไม่พอ (มี $userBalance ใช้ $cost)");
        }

        transaction.update(userRef, {'ocean_tokens': userBalance - cost});
        transaction.update(merchantRef, {'ocean_tokens': merchantBalance + cost});

        transaction.set(db.collection('transactions').doc(), {
          'userId': widget.userId,
          'merchantId': widget.merchantId,
          'customerName': customerName,
          'type': 'Redeem: $itemName',
          'amount': cost,
          'is_income': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context); // ปิด Loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ แลกสำเร็จ! แสดงหน้าจอนี้ให้พนักงานดูได้เลย"),
            backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ปิด Loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("❌ เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception:', '')}"),
            backgroundColor: Colors.red
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchantName),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header แสดงแต้มคงเหลือของลูกค้า
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.deepOrange),
                const SizedBox(width: 10),
                const Text("แต้มของคุณ: "),
                // *** จุดที่แก้ไข ***
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data?.data() == null) {
                      return const Text("กำลังโหลด...", style: TextStyle(color: Colors.grey));
                    }

                    // แปลงข้อมูลเป็น Map ก่อนดึงค่า
                    var userData = snapshot.data!.data() as Map<String, dynamic>;
                    int tokens = userData['ocean_tokens'] ?? 0;

                    return Text("${NumberFormat('#,##0').format(tokens)} Tokens",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 18));
                  },
                )
              ],
            ),
          ),

          // Grid แสดงรายการสินค้าของร้านนี้
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shop_items')
                  .where('shopId', isEqualTo: widget.merchantId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("ร้านนี้ยังไม่มีโปรโมชั่น", style: TextStyle(color: Colors.grey)));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var item = doc.data() as Map<String, dynamic>;

                    // แปลงไอคอนจาก Database
                    IconData iconData = Icons.local_offer;
                    if (item['icon_code'] != null) {
                      iconData = IconData(item['icon_code'], fontFamily: item['icon_font'] ?? 'MaterialIcons');
                    }

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: InkWell(
                        onTap: () => _redeemItem(item),
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.orange.shade100,
                              child: Icon(iconData, size: 30, color: Colors.deepOrange),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                item['name'] ?? 'สินค้า',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "${NumberFormat('#,##0').format(item['cost'])} Tokens",
                              style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                              child: const Text("กดแลก", style: TextStyle(color: Colors.white, fontSize: 12)),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}