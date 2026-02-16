import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'shop_detail_screen.dart'; // ตรวจสอบว่ามีไฟล์นี้
import 'login_screen.dart';      // ตรวจสอบว่ามีไฟล์นี้

class UserDashboard extends StatefulWidget {
  final String userId;
  const UserDashboard({super.key, required this.userId});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  // ฟังก์ชันออกจากระบบ
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ออกจากระบบ"),
        content: const Text("ต้องการกลับไปหน้า Login ใช่ไหม?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text("ออก", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0: return "แดชบอร์ด";
      case 1: return "กระเป๋าตั๋ว & ประวัติ";
      case 2: return "ร้านค้าพาร์ทเนอร์";
      default: return "Blue Exchange";
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(userId: widget.userId),
      _HistoryTab(userId: widget.userId), // แท็บประวัติที่แก้บั๊กแล้ว
      _PartnerTab(userId: widget.userId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: const Color(0xFF0077B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
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
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: "ตั๋ว/ประวัติ"),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: "ร้านค้า"),
        ],
      ),
    );
  }
}

// ==========================================
// 1. HOME TAB (หน้าหลัก)
// ==========================================
class _HomeTab extends StatelessWidget {
  final String userId;
  const _HomeTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String name = data['name'] ?? 'ผู้ใช้';
        int tokens = data['ocean_tokens'] ?? 0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("ยินดีต้อนรับ,", style: TextStyle(color: Colors.grey)),
            Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0077B6))),
            const SizedBox(height: 20),

            // การ์ดแสดงเงิน
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0096C7), Color(0xFF0077B6)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const Text("ยอดคงเหลือ", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.waves, color: Colors.white, size: 40),
                      const SizedBox(width: 10),
                      Text(NumberFormat('#,##0').format(tokens), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const Text("Ocean Tokens", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text("QR Code ของฉัน", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),

            // QR Code (Icon)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 160, color: Colors.black87),
                    Text("ID: $userId", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 2. HISTORY TAB (FIXED: แก้ปัญหาหมุนค้าง + E-Ticket)
// ==========================================
class _HistoryTab extends StatefulWidget {
  final String userId;
  const _HistoryTab({required this.userId});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {

  // ฟังก์ชันแสดงตั๋วแบบละเอียด (Dialog)
  void _showTicketDetail(BuildContext context, Map<String, dynamic> data) {
    Timestamp? ts = data['timestamp'];
    DateTime date = ts != null ? ts.toDate() : DateTime.now();
    DateTime expireDate = date.add(const Duration(hours: 24)); // หมดอายุใน 24 ชม.
    bool isExpired = DateTime.now().isAfter(expireDate);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isExpired ? Colors.grey : Colors.green, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isExpired ? Icons.cancel : Icons.confirmation_number, color: isExpired ? Colors.grey : Colors.green, size: 60),
              const SizedBox(height: 10),
              Text(isExpired ? "ตั๋วหมดอายุแล้ว" : "ตั๋วพร้อมใช้งาน", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isExpired ? Colors.grey : Colors.green)),
              const Divider(thickness: 1.5),
              const SizedBox(height: 10),
              Text(data['type'] ?? "สินค้า", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 5),
              Text("${NumberFormat('#,##0').format(data['amount'] ?? 0)} Tokens", style: const TextStyle(fontSize: 18, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                height: 60, width: 200,
                color: isExpired ? Colors.grey.shade300 : Colors.black,
                alignment: Alignment.center,
                child: const Text("|| ||| | |||| || ||", style: TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 5)),
              ),
              const SizedBox(height: 5),
              Text("REF: ${data['timestamp'].hashCode}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("แลกเมื่อ:", style: TextStyle(color: Colors.grey)),
                  Text(DateFormat('dd/MM HH:mm').format(date)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("หมดอายุ:", style: TextStyle(color: Colors.red)),
                  Text(DateFormat('dd/MM HH:mm').format(expireDate), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: isExpired ? Colors.grey : Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                child: const Text("ปิดหน้านี้"),
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
          .where('userId', isEqualTo: widget.userId)
      // .orderBy('timestamp', descending: true) <--- ลบออกเพื่อแก้ปัญหา Index หมุนค้าง
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("ยังไม่มีประวัติธุรกรรม"));

        // --- เรียงลำดับข้อมูลเอง (Client-side Sorting) ---
        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          Timestamp tA = a['timestamp'] ?? Timestamp.now();
          Timestamp tB = b['timestamp'] ?? Timestamp.now();
          return tB.compareTo(tA); // ใหม่ -> เก่า
        });

        // แยกข้อมูล
        final now = DateTime.now();
        final oneDayAgo = now.subtract(const Duration(hours: 24));

        List<DocumentSnapshot> activeTickets = [];
        List<DocumentSnapshot> historyItems = [];

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          Timestamp? ts = data['timestamp'];
          DateTime txDate = ts != null ? ts.toDate() : DateTime(2000);
          bool isIncome = data['is_income'] ?? false;

          if (!isIncome && txDate.isAfter(oneDayAgo)) {
            activeTickets.add(doc);
          } else {
            historyItems.add(doc);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ส่วนที่ 1: ตั๋วที่ใช้ได้
            if (activeTickets.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number, color: Colors.green),
                    SizedBox(width: 8),
                    Text("ตั๋วที่ใช้ได้ (หมดอายุใน 24 ชม.)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              ...activeTickets.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                Timestamp ts = data['timestamp'];
                DateTime expireDate = ts.toDate().add(const Duration(hours: 24));
                Duration diff = expireDate.difference(now);
                String timeLeft = "${diff.inHours} ชม. ${diff.inMinutes % 60} นาที";

                return Card(
                  elevation: 4,
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _showTicketDetail(context, data),
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.qr_code, color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['type'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text("หมดอายุใน: $timeLeft", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Divider(height: 30, thickness: 1),
            ],

            // ส่วนที่ 2: ประวัติย้อนหลัง
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text("ประวัติย้อนหลัง", style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
            if (historyItems.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("ไม่มีประวัติย้อนหลัง"))),

            ...historyItems.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              bool isIncome = data['is_income'] ?? false;
              Timestamp? ts = data['timestamp'];
              String dateStr = ts != null ? DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate()) : "-";

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Icon(isIncome ? Icons.arrow_downward : Icons.history, color: isIncome ? Colors.green : Colors.grey, size: 20),
                  ),
                  title: Text(data['type'] ?? "รายการ", style: TextStyle(color: isIncome ? Colors.black : Colors.grey.shade700)),
                  subtitle: Text(dateStr),
                  trailing: Text(
                    "${isIncome ? '+' : '-'}${NumberFormat('#,##0').format(data['amount'] ?? 0)}",
                    style: TextStyle(color: isIncome ? Colors.green : Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    if (!isIncome) _showTicketDetail(context, data);
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ==========================================
// 3. PARTNER TAB (ร้านค้า)
// ==========================================
class _PartnerTab extends StatelessWidget {
  final String userId;
  const _PartnerTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Align(alignment: Alignment.centerLeft, child: Text("เลือกร้านค้าเพื่อแลกสิทธิ์", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'merchant')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("ยังไม่มีร้านค้าเข้าร่วม"));

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var shopDoc = snapshot.data!.docs[index];
                  var shopData = shopDoc.data() as Map<String, dynamic>;
                  String merchantId = shopDoc.id;
                  String shopName = shopData['shop_name'] ?? shopData['name'] ?? "ร้านค้า";

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: const Icon(Icons.store, color: Colors.deepOrange),
                      ),
                      title: Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("คลิกเพื่อดูสินค้าและโปรโมชั่น"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
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
          ),
        ),
      ],
    );
  }
}