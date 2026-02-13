import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MerchantShop extends StatefulWidget {
  final String userId;
  const MerchantShop({super.key, required this.userId});

  @override
  State<MerchantShop> createState() => _MerchantShopState();
}

class _MerchantShopState extends State<MerchantShop> {

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
  /// REALTIME LISTENER
  //////////////////////////////////////////////////////

  void _listenForNewOrders() {
    FirebaseFirestore.instance
        .collection('transactions')
        .where('merchantId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          if (data['type'] != null &&
              data['type'].toString().contains('Redeem')) {
            _showNotification(data);
          }
        }
      }
    });
  }

  void _showNotification(Map<String, dynamic> data) {
    if (!mounted) return;

    String item =
    (data['type'] ?? '').replaceAll('Redeem: ', '');
    int amount = data['amount'] ?? 0;
    String customer =
        data['customerName'] ?? 'ลูกค้า';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.orange.shade50,
        title: const Text("มีรายการแลกใหม่!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(customer,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            const SizedBox(height: 10),
            Text(item,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange)),
            Text("+$amount Tokens",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange),
            child: const Text("รับทราบ"),
          )
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////
  /// CASH OUT
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
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                  labelText: "Username เจ้าหน้าที่"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "จำนวน Tokens"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: () {
              String staffUsername =
              usernameController.text.trim();
              int amount =
                  int.tryParse(amountController.text) ?? 0;

              Navigator.pop(context);

              if (staffUsername.isNotEmpty &&
                  amount > 0) {
                _processCashOut(staffUsername, amount);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green),
            child: const Text("ยืนยัน"),
          )
        ],
      ),
    );
  }

  Future<void> _processCashOut(
      String staffUsername, int amount) async {
    final db = FirebaseFirestore.instance;
    final merchantRef =
    db.collection('users').doc(widget.userId);

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
          const Center(child: CircularProgressIndicator()));

      final staffQuery = await db
          .collection('users')
          .where('username', isEqualTo: staffUsername)
          .limit(1)
          .get();

      if (staffQuery.docs.isEmpty) {
        throw Exception("ไม่พบเจ้าหน้าที่");
      }

      final staffDoc = staffQuery.docs.first;
      final staffRef = staffDoc.reference;

      await db.runTransaction((transaction) async {
        final merchantSnap =
        await transaction.get(merchantRef);
        final staffSnap =
        await transaction.get(staffRef);

        int merchantTokens =
            merchantSnap.data()?['ocean_tokens'] ?? 0;
        int staffBudget =
            staffSnap.data()?['budget'] ?? 0;
        int staffCollected =
            staffSnap.data()?['collected_tokens'] ?? 0;

        if (merchantTokens < amount) {
          throw Exception("แต้มไม่พอ");
        }

        transaction.update(merchantRef, {
          'ocean_tokens': merchantTokens - amount
        });

        transaction.update(staffRef, {
          'budget': staffBudget - amount,
          'collected_tokens':
          staffCollected + amount
        });

        transaction.set(
            db.collection('transactions').doc(), {
          'merchantId': widget.userId,
          'staffId': staffDoc.id,
          'type': 'Cash Out',
          'amount': amount,
          'timestamp':
          FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
          content:
          Text("โอน $amount Tokens สำเร็จ"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  //////////////////////////////////////////////////////
  /// PRODUCT CRUD
  //////////////////////////////////////////////////////

  void _showProductDialog({DocumentSnapshot? product}) {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    int selectedIconIndex = 0;

    if (product != null) {
      var data =
      product.data() as Map<String, dynamic>;
      nameController.text = data['name'];
      costController.text =
          data['cost'].toString();
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            product == null
                ? "เพิ่มสินค้า"
                : "แก้ไขสินค้า"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                  labelText: "ชื่อสินค้า"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costController,
              keyboardType:
              TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "ราคา"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  costController.text.isEmpty)
                return;

              int cost =
              int.parse(costController.text);

              if (product == null) {
                await FirebaseFirestore.instance
                    .collection('shop_items')
                    .add({
                  'shopId': widget.userId,
                  'name': nameController.text,
                  'cost': cost,
                  'created_at':
                  FieldValue.serverTimestamp()
                });
              } else {
                await FirebaseFirestore.instance
                    .collection('shop_items')
                    .doc(product.id)
                    .update({
                  'name': nameController.text,
                  'cost': cost
                });
              }

              if (mounted)
                Navigator.pop(context);
            },
            child: const Text("บันทึก"),
          )
        ],
      ),
    );
  }

  void _deleteProduct(String id) {
    FirebaseFirestore.instance
        .collection('shop_items')
        .doc(id)
        .delete();
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
        actions: [
          IconButton(
            onPressed: _transferToStaff,
            icon:
            const Icon(Icons.currency_exchange),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shop_items')
            .where('shopId',
            isEqualTo: widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child:
                CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount:
            snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc =
              snapshot.data!.docs[index];
              var data = doc.data()
              as Map<String, dynamic>;

              return ListTile(
                title: Text(data['name']),
                subtitle: Text(
                    "${NumberFormat('#,##0').format(data['cost'])} Tokens"),
                trailing: IconButton(
                  icon: const Icon(
                      Icons.delete,
                      color: Colors.red),
                  onPressed: () =>
                      _deleteProduct(doc.id),
                ),
                onTap: () =>
                    _showProductDialog(
                        product: doc),
              );
            },
          );
        },
      ),
      floatingActionButton:
      FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () =>
            _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
