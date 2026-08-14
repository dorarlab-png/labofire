import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final DbHelper _dbHelper = DbHelper();
  double _totalExpected = 0.0;
  double _totalCollected = 0.0;
  double _totalRemaining = 0.0;
  List<Map<String, dynamic>> _debtorPatients = [];
  String _selectedFilter = 'all';

  // متغيرات نظام الحماية وكلمة السر
  bool _isAuthenticated = false;
  final TextEditingController _passwordController = TextEditingController();
  final String _correctPassword = 'dorar';

  @override
  void initState() {
    super.initState();
    _calculateFinancials();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _calculateFinancials() async {
    final db = await _dbHelper.db;
    final List<Map<String, dynamic>> patients = await db!.query('patients');

    double expected = 0.0;
    double collected = 0.0;
    double remaining = 0.0;
    List<Map<String, dynamic>> debtors = [];

    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

    for (var patient in patients) {
      String pDateTime = patient['date_time'].toString();
      bool include = false;

      if (_selectedFilter == 'all') {
        include = true;
      } else if (_selectedFilter == 'today' && pDateTime.startsWith(todayStr)) {
        include = true;
      } else if (_selectedFilter == 'month' &&
          pDateTime.startsWith(currentMonthStr)) {
        include = true;
      }

      if (include) {
        expected += patient['total_amount'];
        collected += patient['paid_amount'];
        remaining += patient['remaining_amount'];
        if (patient['remaining_amount'] > 0) debtors.add(patient);
      }
    }

    setState(() {
      _totalExpected = expected;
      _totalCollected = collected;
      _totalRemaining = remaining;
      _debtorPatients = debtors;
    });
  }

  void _checkPassword() {
    if (_passwordController.text == _correctPassword) {
      setState(() {
        _isAuthenticated = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة السر غير صحيحة! برجاء المحاولة مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(
                alpha: 0.1,
              ), // ⬅️ تم التحديث هنا لتجنب التحذير
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    '$value ج.م',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحسابات والتقارير المالية'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isAuthenticated ? _buildAccountsContent() : _buildLoginContent(),
    );
  }

  // واجهة طلب كلمة المرور
  Widget _buildLoginContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 64,
                  color: Colors.red.shade700,
                ),
                const SizedBox(height: 16),
                const Text(
                  'منطقة محمية',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى إدخال كلمة السر لعرض التقارير المالية',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'كلمة السر',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.password),
                  ),
                  onSubmitted: (_) => _checkPassword(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _checkPassword,
                    child: const Text('دخول', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // واجهة عرض الحسابات الأساسية
  Widget _buildAccountsContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ChoiceChip(
                label: const Text('اليوم'),
                selected: _selectedFilter == 'today',
                onSelected: (val) {
                  if (val) {
                    _selectedFilter = 'today';
                    _calculateFinancials();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('الشهر الحالي'),
                selected: _selectedFilter == 'month',
                onSelected: (val) {
                  if (val) {
                    _selectedFilter = 'month';
                    _calculateFinancials();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('كل الأوقات'),
                selected: _selectedFilter == 'all',
                onSelected: (val) {
                  if (val) {
                    _selectedFilter = 'all';
                    _calculateFinancials();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildStatCard(
            title: 'إجمالي قيمة الفحوصات المطلوبة',
            value: _totalExpected.toStringAsFixed(2),
            color: Colors.blue.shade800,
            icon: Icons.request_quote_rounded,
          ),
          _buildStatCard(
            title: 'الخزنة (المبالغ المحصلة فعلياً)',
            value: _totalCollected.toStringAsFixed(2),
            color: Colors.green.shade700,
            icon: Icons.account_balance_wallet_rounded,
          ),
          _buildStatCard(
            title: 'الديون المتبقية طرف المرضى',
            value: _totalRemaining.toStringAsFixed(2),
            color: Colors.red.shade700,
            icon: Icons.money_off_rounded,
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.assignment_late_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'قائمة المطالبات والديون المتبقية',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _debtorPatients.isEmpty
                ? const Center(child: Text('لا توجد مبالغ متأخرة.'))
                : ListView.builder(
                    itemCount: _debtorPatients.length,
                    itemBuilder: (context, index) {
                      final debtor = _debtorPatients[index];
                      return Card(
                        color: Colors.red.shade50.withValues(
                          alpha: 0.5,
                        ), // ⬅️ تم التحديث هنا أيضاً
                        child: ListTile(
                          title: Text(
                            debtor['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'الهاتف: ${debtor['phone']}\nالتاريخ: ${debtor['date_time']}',
                          ),
                          trailing: Text(
                            'متبقي: ${debtor['remaining_amount']} ج.م',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
