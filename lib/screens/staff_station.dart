import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  final _merchantUsernameController = TextEditingController();
  final _cashOutPointsController = TextEditingController();

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
    _merchantUsernameController.dispose();
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

  Future<void> _buyWaste() async {
    if (_calculatedTokens <= 0 || _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอก Username ลูกค้า และน้ำหนักขยะ")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      final userQuery = await db
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        throw Exception("ไม่พบผู้ใช้ '${_usernameController.text}'");
      }

      final userDoc = userQuery.docs.first;
      final userRef = userDoc.reference;
      final staffRef = db.collection('users').doc(widget.userId);

      await db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final staffSnapshot = await transaction.get(staffRef);

        int newBalance =
            (userSnapshot.get('ocean_tokens') ?? 0) + _calculatedTokens;
        transaction.update(userRef, {'ocean_tokens': newBalance});

        transaction.set(db.collection('transactions').doc(), {
          'userId': userDoc.id,
          'staffId': widget.userId,
          'type': 'Sell Waste: $_selectedType',
          'weight': double.tryParse(_weightController.text) ?? 0.0,
          'amount': _calculatedTokens,
          'is_income': true,
          'timestamp': FieldValue.serverTimestamp(),
          'customerName':
              userSnapshot.get('name') ?? _usernameController.text.trim(),
          'staffName': staffSnapshot.get('name') ?? 'Staff',
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "✅ โอน $_calculatedTokens แต้มให้ ${_usernameController.text} สำเร็จ"),
          backgroundColor: Colors.green,
        ));
        _usernameController.clear();
        _weightController.clear();
        setState(() => _calculatedTokens = 0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("❌ ${e.toString().replaceAll('Exception: ', '')}"),
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _merchantCashOut() async {
    final points = int.tryParse(_cashOutPointsController.text) ?? 0;
    final merchantName = _merchantUsernameController.text.trim();

    if (points <= 0 || merchantName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("กรุณากรอก Username ร้านค้าและจำนวนแต้ม")));
      return;
    }

    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;
    final staffRef = db.collection('users').doc(widget.userId);

    try {
      final merchantQuery = await db
          .collection('users')
          .where('username', isEqualTo: merchantName)
          .where('role', isEqualTo: 'merchant')
          .limit(1)
          .get();
      if (merchantQuery.docs.isEmpty) {
        throw Exception("ไม่พบร้านค้า '$merchantName'");
      }

      final merchantDoc = merchantQuery.docs.first;
      final merchantRef = merchantDoc.reference;

      await db.runTransaction((transaction) async {
        final staffSnap = await transaction.get(staffRef);
        final merchantSnap = await transaction.get(merchantRef);

        int currentBudget = staffSnap.get('budget') ?? 0;
        int collected = staffSnap.get('collected_tokens') ?? 0;
        int merchantTokens = merchantSnap.get('ocean_tokens') ?? 0;
        int cashToPay = points; // 1:1 rate

        if (merchantTokens < points) {
          throw Exception("แต้มร้านค้าไม่พอ (มี $merchantTokens)");
        }
        if (currentBudget < cashToPay) {
          throw Exception("งบ Staff ไม่พอ (มี $currentBudget ฿)");
        }

        transaction.update(merchantRef, {'ocean_tokens': merchantTokens - points});
        transaction.update(staffRef, {
          'budget': currentBudget - cashToPay,
          'collected_tokens': collected + points,
        });

        transaction.set(db.collection('transactions').doc(), {
          'type': 'Merchant Cash Out',
          'staffId': widget.userId,
          'merchantId': merchantDoc.id,
          'amount': points,
          'cash_paid': cashToPay,
          'timestamp': FieldValue.serverTimestamp(),
          'staffName': staffSnap.get('name') ?? 'Staff',
          'shopName': merchantSnap.get('shop_name') ?? merchantName,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ จ่ายเงิน $points บาท ให้ $merchantName สำเร็จ"),
          backgroundColor: Colors.green,
        ));
        _merchantUsernameController.clear();
        _cashOutPointsController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text("❌ ${e.toString().replaceAll('Exception: ', '')}"),
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff System"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: Colors.white60,
          indicatorColor: theme.colorScheme.onPrimary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.eco_rounded), text: "รับซื้อขยะ"),
            Tab(icon: Icon(Icons.storefront_rounded), text: "ร้านค้า Cash Out"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuyWasteTab(theme),
          _buildCashOutTab(theme),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontSize: 14, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("ไม่สามารถโหลดข้อมูลได้"));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("ไม่พบข้อมูล Staff"));
        }

        var data = snapshot.data?.data() as Map<String, dynamic>?;
        int budget = data?['budget'] ?? 0;
        int collected = data?['collected_tokens'] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _statCard(
                  "งบประมาณเงินสด",
                  "${NumberFormat("#,##0").format(budget)} ฿",
                  Icons.account_balance_wallet_outlined,
                  Colors.orange.shade800),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                  "แต้มที่ดึงคืน",
                  NumberFormat("#,##0").format(collected),
                  Icons.restart_alt_rounded,
                  Colors.blue.shade800),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBuyWasteTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("คำนวณแต้มสำหรับลูกค้า",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
                labelText: "Username ลูกค้า",
                prefixIcon: Icon(Icons.person_search)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            items: _rates.keys
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text("$e (${_rates[e]} Tokens/kg)"),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedType = val);
                _calculateTokens();
              }
            },
            decoration: const InputDecoration(
                labelText: "ประเภทขยะ", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: "น้ำหนัก (kg)", prefixIcon: Icon(Icons.scale)),
            onChanged: (_) => _calculateTokens(),
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text("แต้มที่จะได้รับ", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    "${NumberFormat("#,##0").format(_calculatedTokens)} Tokens",
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _buyWaste,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : const Icon(Icons.send_rounded),
            label: const Text("ยืนยันโอนแต้ม"),
          ),
        ],
      ),
    );
  }

  Widget _buildCashOutTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // This is the new widget from the user's suggestion
          _buildBudgetStatus(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text("จ่ายเงินสดให้ร้านค้า",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _merchantUsernameController,
            decoration: const InputDecoration(
                labelText: "Username ร้านค้า", prefixIcon: Icon(Icons.storefront)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cashOutPointsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: "จำนวนแต้มที่ร้านค้าแลก",
                prefixIcon: Icon(Icons.monetization_on_outlined)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _merchantCashOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : const Icon(Icons.price_check_rounded),
            label: const Text("ยืนยันจ่ายเงินสด"),
          ),
        ],
      ),
    );
  }
}