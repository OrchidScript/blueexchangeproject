import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShopDetailScreen extends StatefulWidget {
  final String userId;
  final String merchantId;
  final String merchantName;

  const ShopDetailScreen({
    super.key,
    required this.userId,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {

  Future<void> _redeemCoupon(String itemName, int cost) async {
    final db = FirebaseFirestore.instance;

    DocumentReference userRef =
    db.collection('users').doc(widget.userId);

    await db.runTransaction((transaction) async {

      DocumentSnapshot userSnap = await transaction.get(userRef);
      int userPoints = userSnap.get('ocean_tokens') ?? 0;

      if (userPoints < cost) {
        throw Exception("แต้มของคุณไม่พอ");
      }

      DocumentReference merchantRef =
      db.collection('users').doc(widget.merchantId);

      DocumentSnapshot merchantSnap =
      await transaction.get(merchantRef);

      int merchantPoints =
          merchantSnap.get('ocean_tokens') ?? 0;

      transaction.update(userRef, {
        'ocean_tokens': userPoints - cost
      });

      transaction.update(merchantRef, {
        'ocean_tokens': merchantPoints + cost
      });

      transaction.set(db.collection('transactions').doc(), {
        'userId': widget.userId,
        'merchantId': widget.merchantId,
        'type': 'Purchase @ ${widget.merchantName}',
        'item': itemName,
        'amount': cost,
        'is_income': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("แลกสำเร็จ")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {"name": "ลด 20 บาท", "cost": 100},
      {"name": "ส่วนลด 10%", "cost": 150},
      {"name": "ของแถมฟรี", "cost": 80},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchantName),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          var item = items[index];

          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text(item["name"].toString()),
              subtitle: Text("ใช้ ${item["cost"]} Tokens"),
              trailing: ElevatedButton(
                onPressed: () {
                  _redeemCoupon(
                    item["name"].toString(),
                    item["cost"] as int,
                  );
                },
                child: const Text("แลก"),
              ),
            ),
          );
        },
      ),
    );
  }
}
