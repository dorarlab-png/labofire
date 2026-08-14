import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _analysisList = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAnalysisList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _refreshAnalysisList() async {
    final db = await _dbHelper.db;
    if (db == null) return;
    final List<Map<String, dynamic>> maps = await db.query('analysis');
    if (mounted) {
      setState(() {
        _analysisList = maps;
      });
    }
  }

  // --- دالة حذف كل التحاليل ---
  void _deleteAllAnalysis() async {
    if (_analysisList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('القائمة فارغة بالفعل!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف الكل'),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف جميع التحاليل المسجلة؟ لا يمكن التراجع عن هذه الخطوة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final db = await _dbHelper.db;
              if (db != null) {
                await db.delete('analysis'); // حذف كافة السجلات
              }
              if (mounted) {
                Navigator.pop(dialogContext);
                _refreshAnalysisList();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف جميع التحاليل بنجاح')),
                );
              }
            },
            child:
                const Text('حذف الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ميزة تصدير البيانات إلى ملف CSV ---
  void _exportToCSV() async {
    if (_analysisList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قائمة التحاليل فارغة حالياً للتصدير')),
      );
      return;
    }

    try {
      StringBuffer csvContent = StringBuffer();
      csvContent.write('\uFEFF'); // BOM للغة العربية
      csvContent.writeln('name_ana_list,price_ana_list');

      for (var row in _analysisList) {
        String cleanName = row['name'].toString().replaceAll(',', ' ');
        csvContent.writeln('$cleanName,${row['price']}');
      }

      final directory = await getTemporaryDirectory();
      final String path = '${directory.path}/analysis_prices_export.csv';
      final File file = File(path);
      await file.writeAsString(csvContent.toString(), encoding: utf8);

      if (!mounted) return;

      final xFile = XFile(path);
      await Share.shareXFiles(
        [xFile],
        text: 'قائمة أسعار التحاليل الطبية (CSV)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء التصدير: $e')));
    }
  }

  // --- ميزة استيراد البيانات من ملف CSV ---
  void _importFromCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        List<String> lines = await file.readAsLines(encoding: utf8);

        if (lines.isEmpty) return;

        final db = await _dbHelper.db;
        if (db == null) return;

        Batch batch = db.batch();
        int importedCount = 0;

        for (int i = 1; i < lines.length; i++) {
          String line = lines[i].trim();
          if (line.isEmpty) continue;

          List<String> rowData = line.split(',');
          if (rowData.length >= 2) {
            String name = rowData[0].trim();
            double? price = double.tryParse(rowData[1].trim());

            if (name.isNotEmpty && price != null) {
              batch.insert('analysis', {'name': name, 'price': price});
              importedCount++;
            }
          }
        }

        await batch.commit(noResult: true);
        _refreshAnalysisList();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد وإضافة $importedCount تحليلاً بنجاح للقائمة',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل الاستيراد، تأكد من مطابقة صياغة وترتيب الأعمدة: $e',
          ),
        ),
      );
    }
  }

  void _addAnalysis() async {
    final String name = _nameController.text.trim();
    final String priceText = _priceController.text.trim();

    if (name.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    final double? price = double.tryParse(priceText);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال سعر صحيح وصالح')),
      );
      return;
    }

    final db = await _dbHelper.db;
    if (db == null) return;
    await db.insert('analysis', {'name': name, 'price': price});

    _nameController.clear();
    _priceController.clear();
    _refreshAnalysisList();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة التحليل بنجاح')));
    }
  }

  void _deleteAnalysis(int id) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف هذا التحليل نهائياً؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final db = await _dbHelper.db;
              if (db != null) {
                await db.delete('analysis', where: 'id = ?', whereArgs: [id]);
              }
              if (mounted) {
                Navigator.pop(dialogContext);
                _refreshAnalysisList();
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> analysis) {
    final editNameController = TextEditingController(text: analysis['name']);
    final editPriceController = TextEditingController(
      text: analysis['price'].toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل بيانات التحليل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameController,
              decoration: const InputDecoration(labelText: 'اسم التحليل'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: editPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'السعر (ج.م)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              editNameController.dispose();
              editPriceController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final String newName = editNameController.text.trim();
              final double? newPrice = double.tryParse(
                editPriceController.text.trim(),
              );

              if (newName.isEmpty || newPrice == null || newPrice < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('الرجاء التأكد من صحة البيانات المسجلة'),
                  ),
                );
                return;
              }

              final db = await _dbHelper.db;
              if (db != null) {
                await db.update(
                  'analysis',
                  {'name': newName, 'price': newPrice},
                  where: 'id = ?',
                  whereArgs: [analysis['id']],
                );
              }

              editNameController.dispose();
              editPriceController.dispose();

              if (mounted) {
                Navigator.pop(dialogContext);
                _refreshAnalysisList();
              }
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التحاليل الطبية'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_rounded),
            tooltip: 'استيراد قائمة ملف أسعار',
            onPressed: _importFromCSV,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'تصدير القائمة الحالية',
            onPressed: _exportToCSV,
          ),
          // ⬇️ تم إضافة زر حذف الكل هنا
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            tooltip: 'حذف جميع التحاليل',
            onPressed: _deleteAllAnalysis,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'إضافة تحليل طبي جديد يدوياً',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم التحليل',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'السعر',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _addAnalysis,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة لقائمة المختبر'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _analysisList.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد تحاليل مسجلة حالياً.',
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _analysisList.length,
                      itemBuilder: (context, index) {
                        final item = _analysisList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade50,
                              foregroundColor: Colors.teal.shade800,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('السعر: ${item['price']} ج.م'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () => _showEditDialog(item),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteAnalysis(item['id']),
                                ),
                              ],
                            ),
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
