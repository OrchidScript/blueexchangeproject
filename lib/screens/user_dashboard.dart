import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'shop_detail_screen.dart';

class UserDashboard extends StatefulWidget {
  final String userId;
  const UserDashboard({super.key, required this.userId});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return "แดชบอร์ด";
      case 1:
        return "ประวัติธุรกรรม";
      case 2:
        return "ร้านค้าพาร์ทเนอร์";
      default:
        return "Blue Exchange";
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(userId: widget.userId),
      _HistoryTab(userId: widget.userId),
      _PartnerTab(userId: widget.userId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: const Color(0xFF0077B6),
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF0077B6),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "หน้าหลัก"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "ประวัติ"),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: "ร้านค้า"),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////
/// HOME TAB
////////////////////////////////////////////////////////

class _HomeTab extends StatelessWidget {
  final String userId;
  const _HomeTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String name = data['name'] ?? 'ผู้ใช้';
        int tokens = data['ocean_tokens'] ?? 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text("สวัสดี,", style: TextStyle(color: Colors.grey)),
            Text(name,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0077B6))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0096C7), Color(0xFF0077B6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.waves,
                      color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Text(
                    NumberFormat('#,##0').format(tokens),
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text("Tokens",
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

////////////////////////////////////////////////////////
/// HISTORY TAB WITH E-RECEIPT
////////////////////////////////////////////////////////

class _HistoryTab extends StatelessWidget {
  final String userId;
  const _HistoryTab({super.key, required this.userId});

  void _showReceipt(BuildContext context, Map<String, dynamic> data) {
    Timestamp? ts = data['timestamp'];
    String formattedDate = ts != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate())
        : "-";

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 60),
              const SizedBox(height: 10),
              const Text(
                "ทำรายการสำเร็จ",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green),
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(data['type'] ?? "รายการ",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                "${NumberFormat('#,##0').format(data['amount'] ?? 0)} Tokens",
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange),
              ),
              const SizedBox(height: 15),
              Text("รหัสลูกค้า: $userId",
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
              Text("วันที่: $formattedDate",
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 15),
              const Text(
                "กรุณาแสดงหน้าจอนี้แก่พนักงาน",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("ปิด"),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("ยังไม่มีประวัติธุรกรรม"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data =
            doc.data() as Map<String, dynamic>;

            bool isIncome = data['is_income'] ?? false;

            Timestamp? ts = data['timestamp'];
            String date = ts != null
                ? DateFormat('dd/MM/yyyy HH:mm')
                .format(ts.toDate())
                : "-";

            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: ListTile(
                leading: Icon(
                  isIncome
                      ? Icons.arrow_downward
                      : Icons.shopping_bag,
                  color:
                  isIncome ? Colors.green : Colors.deepOrange,
                ),
                title: Text(data['type'] ?? "รายการ"),
                subtitle: Text(date),
                trailing: Text(
                  "${isIncome ? '+' : '-'}${NumberFormat('#,##0').format(data['amount'] ?? 0)}",
                  style: TextStyle(
                    color:
                    isIncome ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  if (!isIncome) {
                    _showReceipt(context, data);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

////////////////////////////////////////////////////////
/// PARTNER TAB
////////////////////////////////////////////////////////

class _PartnerTab extends StatelessWidget {
  final String userId;
  const _PartnerTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'merchant')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("ยังไม่มีร้านค้า"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var shopDoc = snapshot.data!.docs[index];
            var shopData =
            shopDoc.data() as Map<String, dynamic>;

            String merchantId = shopDoc.id;
            String shopName =
                shopData['shop_name'] ??
                    shopData['name'] ??
                    "ร้านค้า";

            return Card(
              child: ListTile(
                leading: const Icon(Icons.store),
                title: Text(shopName),
                trailing:
                const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDetailScreen(
                        userId: userId,
                        merchantId: merchantId,
                        merchantName: shopName,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
