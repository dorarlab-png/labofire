import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'patients.dart';

class SearchPaPage extends StatefulWidget {
  const SearchPaPage({super.key});

  @override
  State<SearchPaPage> createState() => _SearchPaPageState();
}

class _SearchPaPageState extends State<SearchPaPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _allPatientsList = [];
  List<Map<String, dynamic>> _filteredPatientsList = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void _loadPatients() async {
    final db = await _dbHelper.db;
    final List<Map<String, dynamic>> patients =
        await db!.query('patients', orderBy: 'id DESC');
    setState(() {
      _allPatientsList = patients;
      _filteredPatientsList = patients;
    });
  }

  void _filterPatients(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredPatientsList = _allPatientsList;
      } else {
        _filteredPatientsList = _allPatientsList.where((patient) {
          final name = patient['name'].toString().toLowerCase();
          final phone = patient['phone'].toString();
          return name.contains(keyword.toLowerCase()) ||
              phone.contains(keyword);
        }).toList();
      }
    });
  }

  void _deletePatient(int id, String name) async {
    final db = await _dbHelper.db;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف سجل المريض ($name) نهائياً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await db!.delete('patients', where: 'id = ?', whereArgs: [id]);
              Navigator.pop(context);
              _loadPatients();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('الاستعلام عن مريض'),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _filterPatients,
              decoration: InputDecoration(
                  labelText: 'ابحث باسم المريض أو رقم الهاتف...',
                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _filteredPatientsList.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مطابقة.'))
                  : ListView.builder(
                      itemCount: _filteredPatientsList.length,
                      itemBuilder: (context, index) {
                        final patient = _filteredPatientsList[index];
                        final double remaining = patient['remaining_amount'];
                        return Card(
                          child: ListTile(
                            title: Text(patient['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'السن: ${patient['age']} | الهاتف: ${patient['phone']}\nالتاريخ: ${patient['date_time']}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    'الإجمالي: ${patient['total_amount']} ج.م'),
                                Text(
                                    remaining > 0
                                        ? 'المتبقي: $remaining ج.م'
                                        : 'خالص الدفع',
                                    style: TextStyle(
                                        color: remaining > 0
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PatientsPage(
                                              patientData: patient)))
                                  .then((_) => _loadPatients());
                            },
                            onLongPress: () =>
                                _deletePatient(patient['id'], patient['name']),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
