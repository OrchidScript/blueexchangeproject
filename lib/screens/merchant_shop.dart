import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart'; // ตรวจสอบว่า import ถูกต้อง

class MerchantShop extends StatefulWidget {
  final String userId;
  const MerchantShop({super.key, required this.userId});

  @override
  State<MerchantShop> createState() => _MerchantShopState();
}

class _MerchantShopState extends State<MerchantShop> {
  // ตัวเลือกไอคอน
  final List<Map<String, dynamic>> _iconOptions = [
    {'icon': Icons.local_offer, 'name': 'ส่วนลด'},
    {'icon': Icons.coffee, 'name': 'เครื่องดื่ม'},
    {'icon': Icons.restaurant, 'name': 'อาหาร'},
    {'icon': Icons.shopping_bag, 'name': 'สินค้า'},
    {'icon': Icons.icecream, 'name': 'ขนม'},
  ];

  @override
  void initState() {
    super.initState();
    _listenForNewOrders();
  }

  //////////////////////////////////////////////////////
  /// 1. REALTIME LISTENER (FIXED)
  //////////////////////////////////////////////////////
  void _listenForNewOrders() {
    FirebaseFirestore.instance
        .collection('transactions')
        .where('merchantId', isEqualTo: widget.userId)
    // *** แก้ไข: ฟังเฉพาะรายการใหม่ที่เกิดขึ้นหลังจากเปิดหน้านี้ ***
        .where('timestamp', isGreaterThan: Timestamp.now())
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          // เช็คว่าเป็นรายการ Redeem (ลูกค้าแลกของ)
          if (data['type'] != null && data['type'].toString().contains('Redeem')) {
            _showNotification(data);
          }
        }
      }
    });
  }

  void _showNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    String item = (data['type'] ?? '').replaceAll('Redeem: ', '');
    int amount = data['amount'] ?? 0;
    String customer = data['customerName'] ?? 'ลูกค้า';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.orange.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.deepOrange),
            SizedBox(width: 10),
            Text("มีรายการแลกใหม่!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ลูกค้า: $customer", style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const Divider(),
            Text(item, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.add_circle, color: Colors.green, size: 20),
                const SizedBox(width: 5),
                Text("$amount Tokens", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            child: const Text("รับทราบ / ส่งมอบของ"),
          )
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////
  /// 2. CASH OUT (FIXED)
  //////////////////////////////////////////////////////
  void _transferToStaff() {
    final usernameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("แลกเงินสด (Cash Out)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("โอนแต้มคืนเจ้าหน้าที่เพื่อรับเงินสด"),
            const SizedBox(height: 10),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: "Username เจ้าหน้าที่", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "จำนวน Tokens ที่จะแลก", border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: () {
              String staffUsername = usernameController.text.trim();
              int amount = int.tryParse(amountController.text) ?? 0;
              Navigator.pop(context);
              if (staffUsername.isNotEmpty && amount > 0) {
                _processCashOut(staffUsername, amount);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("ยืนยัน"),
          )
        ],
      ),
    );
  }

  Future<void> _processCashOut(String staffUsername, int amount) async {
    final db = FirebaseFirestore.instance;
    final merchantRef = db.collection('users').doc(widget.userId);

    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      // 1. หา Staff
      final staffQuery = await db.collection('users').where('username', isEqualTo: staffUsername).where('role', isEqualTo: 'staff').limit(1).get();

      if (staffQuery.docs.isEmpty) throw Exception("ไม่พบเจ้าหน้าที่ชื่อนี้");

      final staffDoc = staffQuery.docs.first;
      final staffRef = staffDoc.reference;

      // 2. เริ่ม Transaction
      await db.runTransaction((transaction) async {
        final merchantSnap = await transaction.get(merchantRef);
        final staffSnap = await transaction.get(staffRef);

        int merchantTokens = merchantSnap.data()?['ocean_tokens'] ?? 0;
        int staffBudget = staffSnap.data()?['budget'] ?? 0;
        int staffCollected = staffSnap.data()?['collected_tokens'] ?? 0;

        if (merchantTokens < amount) throw Exception("แต้มของคุณไม่พอ");

        // หักแต้มร้าน -> เพิ่มแต้มเข้าระบบ Staff -> หักงบ Staff
        transaction.update(merchantRef, {'ocean_tokens': merchantTokens - amount});
        transaction.update(staffRef, {
          'budget': staffBudget - amount,
          'collected_tokens': staffCollected + amount
        });

        transaction.set(db.collection('transactions').doc(), {
          'merchantId': widget.userId,
          'staffId': staffDoc.id,
          'type': 'Cash Out', // หรือ Merchant Cash Out
          'amount': amount,
          'cash_paid': amount, // บันทึกจำนวนเงินบาทที่จ่ายจริงด้วย
          'timestamp': FieldValue.serverTimestamp(),
          'shopName': merchantSnap.data()?['shop_name'] ?? 'Shop',
          'staffName': staffSnap.data()?['name'] ?? 'Staff',
        });
      });

      if (mounted) {
        Navigator.pop(context); // ปิด Loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ แลกเงิน $amount บาท สำเร็จ!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ปิด Loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red));
      }
    }
  }

  //////////////////////////////////////////////////////
  /// 3. PRODUCT CRUD (FIXED WITH ICONS)
  //////////////////////////////////////////////////////
  void _showProductDialog({DocumentSnapshot? product}) {
    final nameController = TextEditingController();
    final costController = TextEditingController();

    // Default Icon
    int selectedIconCode = _iconOptions[0]['icon'].codePoint;
    String selectedIconFamily = _iconOptions[0]['icon'].fontFamily;
    String selectedIconName = _iconOptions[0]['name'];

    if (product != null) {
      var data = product.data() as Map<String, dynamic>;
      nameController.text = data['name'];
      costController.text = data['cost'].toString();
      // Load existing icon if available
      if (data['icon_code'] != null) {
        selectedIconCode = data['icon_code'];
        selectedIconFamily = data['icon_font'];
        selectedIconName = data['icon_name'] ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // ต้องใช้ StatefulBuilder เพื่อให้กดเลือกไอคอนแล้วเปลี่ยนสีทันทีใน Dialog
          builder: (context, setState) {
            return AlertDialog(
              title: Text(product == null ? "เพิ่มสินค้า" : "แก้ไขสินค้า"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: "ชื่อสินค้า", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "ราคา (Tokens)", border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    const Text("เลือกไอคอน:"),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: _iconOptions.map((option) {
                        bool isSelected = option['icon'].codePoint == selectedIconCode;
                        return ChoiceChip(
                          label: Icon(option['icon'], color: isSelected ? Colors.white : Colors.orange),
                          selected: isSelected,
                          selectedColor: Colors.orange,
                          onSelected: (selected) {
                            setState(() {
                              selectedIconCode = option['icon'].codePoint;
                              selectedIconFamily = option['icon'].fontFamily;
                              selectedIconName = option['name'];
                            });
                          },
                        );
                      }).toList(),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || costController.text.isEmpty) return;
                    int cost = int.tryParse(costController.text) ?? 0;

                    Map<String, dynamic> itemData = {
                      'shopId': widget.userId,
                      'name': nameController.text,
                      'cost': cost,
                      'icon_code': selectedIconCode,
                      'icon_font': selectedIconFamily,
                      'icon_name': selectedIconName,
                      'updated_at': FieldValue.serverTimestamp()
                    };

                    if (product == null) {
                      itemData['created_at'] = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance.collection('shop_items').add(itemData);
                    } else {
                      await FirebaseFirestore.instance.collection('shop_items').doc(product.id).update(itemData);
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  child: const Text("บันทึก"),
                )
              ],
            );
          }
      ),
    );
  }

  void _deleteProduct(String id) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("ยืนยันการลบ"),
      content: const Text("ต้องการลบสินค้านี้ใช่ไหม?"),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("ยกเลิก")),
        TextButton(onPressed: (){
          FirebaseFirestore.instance.collection('shop_items').doc(id).delete();
          Navigator.pop(context);
        }, child: const Text("ลบ", style: TextStyle(color: Colors.red)))
      ],
    ));
  }

  //////////////////////////////////////////////////////
  /// UI
  //////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("จัดการร้านค้า"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          // ปุ่ม Cash Out
          IconButton(onPressed: _transferToStaff, icon: const Icon(Icons.currency_exchange), tooltip: 'แลกเงินสด'),
          // ปุ่ม Logout
          IconButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Column(
        children: [
          // --- HEADER: แสดงข้อมูลร้านและยอดเงิน ---
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var userData = snapshot.data!.data() as Map<String, dynamic>;

                return Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: const Border(bottom: BorderSide(color: Colors.orange, width: 1))
                  ),
                  child: Column(
                    children: [
                      Text(userData['shop_name'] ?? 'ร้านค้า', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text("${NumberFormat('#,##0').format(userData['ocean_tokens'] ?? 0)} Tokens",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text("ยอดสะสมที่สามารถแลกเงินสดได้", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }
          ),

          // --- LIST: รายการสินค้า ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shop_items')
                  .where('shopId', isEqualTo: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("ยังไม่มีสินค้า กดปุ่ม + เพื่อเพิ่ม"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    // โหลดไอคอน
                    IconData iconData = Icons.local_offer; // default
                    if (data['icon_code'] != null) {
                      iconData = IconData(data['icon_code'], fontFamily: data['icon_font']);
                    }

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Icon(iconData, color: Colors.deepOrange),
                        ),
                        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${NumberFormat('#,##0').format(data['cost'])} Tokens"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showProductDialog(product: doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(doc.id),
                            ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        onPressed: () => _showProductDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("เพิ่มสินค้า", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}