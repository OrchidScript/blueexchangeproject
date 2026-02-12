import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shop_detail_screen.dart';

class UserDashboard extends StatefulWidget {
  final String userId;
  const UserDashboard({super.key, required this.userId});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _HomeTab(userId: widget.userId),
      _HistoryTab(userId: widget.userId),
      _PartnerTab(userId: widget.userId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Blue Exchange"),
        backgroundColor: const Color(0xFF0077B6),
        foregroundColor: Colors.white,
      ),
      body: pages[_currentIndex],
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

// ================= HOME TAB =================

class _HomeTab extends StatelessWidget {
  final String userId;
  const _HomeTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        var data = snapshot.data?.data() as Map<String, dynamic>?;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("สวัสดี ${data?['name'] ?? ''}"),
              const SizedBox(height: 10),
              Text(
                "${data?['ocean_tokens'] ?? 0}",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const Text("Ocean Tokens"),
            ],
          ),
        );
      },
    );
  }
}

// ================= HISTORY TAB =================

class _HistoryTab extends StatelessWidget {
  final String userId;
  const _HistoryTab({required this.userId});

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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("ยังไม่มีรายการ"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            bool isIncome = data['is_income'] ?? false;

            return ListTile(
              leading: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
              ),
              title: Text(data['type'] ?? ''),
              trailing: Text(
                "${isIncome ? '+' : '-'}${data['amount']}",
                style: TextStyle(
                  color: isIncome ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ================= PARTNER TAB =================

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
            var shop = snapshot.data!.docs[index];
            var shopData = shop.data() as Map<String, dynamic>;

            String shopId = shop.id;
            String shopName = shopData['shop_name'] ?? shopData['name'] ?? "Shop";

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.store, color: Colors.white),
                ),
                title: Text(shopName),
                subtitle: const Text("คลิกเพื่อดูสินค้า"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDetailScreen(
                        userId: userId,
                        merchantId: shopId,
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
