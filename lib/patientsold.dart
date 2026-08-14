import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'db_helper.dart';

class PatientsPage extends StatefulWidget {
  final Map<String, dynamic>? patientData;

  const PatientsPage({super.key, this.patientData});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final DbHelper _dbHelper = DbHelper();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  double _totalAmount = 0.0;
  double _remainingAmount = 0.0;

  List<Map<String, dynamic>> _allAvailableAnalysis = [];
  List<int> _selectedAnalysisIds = [];
  bool _isEditMode = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  BluetoothConnection? _bluetoothConnection;

  @override
  void initState() {
    super.initState();
    _loadAvailableAnalysis();
    _paidController.addListener(_calculateFinances);
  }

  @override
  void dispose() {
    _paidController.removeListener(_calculateFinances);
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    _bluetoothConnection?.dispose();
    super.dispose();
  }

  void _loadAvailableAnalysis() async {
    final db = await _dbHelper.db;
    if (db == null) return;

    final List<Map<String, dynamic>> analysis = await db.query('analysis');

    if (!mounted) return;
    setState(() {
      _allAvailableAnalysis = analysis;
    });

    if (widget.patientData != null) {
      _isEditMode = true;
      _nameController.text = widget.patientData!['name'] ?? '';
      _ageController.text = widget.patientData!['age']?.toString() ?? '';
      _phoneController.text = widget.patientData!['phone'] ?? '';
      _paidController.text =
          widget.patientData!['paid_amount']?.toString() ?? '';
      _notesController.text = widget.patientData!['notes'] ?? '';
      _totalAmount =
          (widget.patientData!['total_amount'] as num?)?.toDouble() ?? 0.0;
      _remainingAmount =
          (widget.patientData!['remaining_amount'] as num?)?.toDouble() ?? 0.0;

      if (widget.patientData!['image_path'] != null &&
          widget.patientData!['image_path'].toString().isNotEmpty) {
        _selectedImage = File(widget.patientData!['image_path']);
      }

      _loadPatientSelectedAnalysis(widget.patientData!['id']);
    }
  }

  void _loadPatientSelectedAnalysis(int patientId) async {
    final db = await _dbHelper.db;
    if (db == null) return;

    final List<Map<String, dynamic>> maps = await db.query(
      'patient_analysis',
      where: 'patient_id = ?',
      whereArgs: [patientId],
    );

    if (!mounted) return;
    setState(() {
      _selectedAnalysisIds = maps.map((e) => e['analysis_id'] as int).toList();
      _calculateFinances();
    });
  }

  void _calculateFinances() {
    double total = 0.0;
    for (var id in _selectedAnalysisIds) {
      var analysisItem = _allAvailableAnalysis.firstWhere(
        (element) => element['id'] == id,
        orElse: () => {'price': 0.0},
      );
      total += (analysisItem['price'] as num?)?.toDouble() ?? 0.0;
    }
    double paid = double.tryParse(_paidController.text) ?? 0.0;

    if (mounted) {
      setState(() {
        _totalAmount = total;
        _remainingAmount = _totalAmount - paid;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء اختيار الصورة: $e')),
        );
      }
    }
  }

  void _showImagePreviewDialog(File imageFile) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAnalysisSelectionDialog() {
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredAnalysis =
        List.from(_allAvailableAnalysis);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('اختر التحاليل المطلوبة'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'بحث باسم التحليل...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setDialogState(() {
                                    searchController.clear();
                                    filteredAnalysis =
                                        List.from(_allAvailableAnalysis);
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (query) {
                        setDialogState(() {
                          filteredAnalysis = _allAvailableAnalysis
                              .where((item) => item['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredAnalysis.isEmpty
                          ? const Center(
                              child: Text('لا توجد تحاليل مطابقة للبحث.'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredAnalysis.length,
                              itemBuilder: (context, index) {
                                final analysis = filteredAnalysis[index];
                                final isSelected = _selectedAnalysisIds
                                    .contains(analysis['id']);
                                return CheckboxListTile(
                                  title: Text(analysis['name'] ?? ''),
                                  subtitle: Text('${analysis['price']} ج.م'),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        _selectedAnalysisIds
                                            .add(analysis['id']);
                                      } else {
                                        _selectedAnalysisIds
                                            .remove(analysis['id']);
                                      }
                                    });
                                    _calculateFinances();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('موافق'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      searchController.dispose();
      if (mounted) setState(() {});
    });
  }

  // ---------------------------------------------------------------------
  // 1- تحويل أي نص عربي لصورة ثم اقتصاص الهوامش بكسل بكسل وتحويله لأوامر ESC * m=33
  // ---------------------------------------------------------------------
  Future<List<Uint8List>> _renderArabicTextToEscStarCommands(
    String text, {
    double fontSize = 21,
    int imgWidth = 384,
  }) async {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: ui.TextDirection.rtl,
      fontSize: fontSize,
      maxLines: 100,
    ))
      ..pushStyle(ui.TextStyle(
        fontFamily: 'Cairo',
        color: const Color(0xFF000000),
      ))
      ..addText(text);

    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: imgWidth.toDouble()));

    final int height = paragraph.height.ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, imgWidth.toDouble(), height.toDouble()), paint);

    canvas.drawParagraph(paragraph, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(imgWidth, height);

    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final Uint8List rgba = byteData.buffer.asUint8List();

    List<List<int>> rawPixels =
        List.generate(height, (y) => List.filled(imgWidth, 0));

    int minY = height;
    int maxY = -1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < imgWidth; x++) {
        int idx = (y * imgWidth + x) * 4;
        int r = rgba[idx];
        int g = rgba[idx + 1];
        int b = rgba[idx + 2];
        int a = rgba[idx + 3];

        if (a >= 128) {
          int gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
          if (gray < 128) {
            rawPixels[y][x] = 1;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
    }

    if (maxY == -1 || minY >= height) return [];

    int textHeight = maxY - minY + 1;
    List<List<int>> croppedPixels = [];
    for (int y = minY; y <= maxY; y++) {
      croppedPixels.add(List.from(rawPixels[y]));
    }

    const int stripHeight = 24;
    int fullHeight =
        ((textHeight + stripHeight - 1) ~/ stripHeight) * stripHeight;

    while (croppedPixels.length < fullHeight) {
      croppedPixels.add(List.filled(imgWidth, 0));
    }

    List<Uint8List> commands = [];

    for (int yStart = 0; yStart < fullHeight; yStart += stripHeight) {
      final strip = croppedPixels.sublist(yStart, yStart + stripHeight);
      List<int> columnData = [];

      for (int x = 0; x < imgWidth; x++) {
        int byte0 = 0, byte1 = 0, byte2 = 0;
        for (int row = 0; row < 8; row++) {
          if (strip[row][x] == 1) byte0 |= (1 << (7 - row));
        }
        for (int row = 8; row < 16; row++) {
          if (strip[row][x] == 1) byte1 |= (1 << (15 - row));
        }
        for (int row = 16; row < 24; row++) {
          if (strip[row][x] == 1) byte2 |= (1 << (23 - row));
        }
        columnData.addAll([byte0, byte1, byte2]);
      }

      int nL = imgWidth & 0xFF;
      int nH = (imgWidth >> 8) & 0xFF;

      Uint8List cmd = Uint8List(5 + columnData.length);
      cmd[0] = 0x1B;
      cmd[1] = 0x2A;
      cmd[2] = 33; // m = 33 (24-dot double density)
      cmd[3] = nL;
      cmd[4] = nH;
      cmd.setRange(5, 5 + columnData.length, columnData);
      commands.add(cmd);
    }

    return commands;
  }

  // ---------------------------------------------------------------------
  // 2- إرسال البيانات على دفعات لتفادي خنق البلوتوث
  // ---------------------------------------------------------------------
  Future<void> _sendBytesInChunks(
    List<int> bytes, {
    int chunkSize = 128,
    Duration delay = const Duration(milliseconds: 15),
  }) async {
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      List<int> chunk = bytes.sublist(i, end);
      _bluetoothConnection!.output.add(Uint8List.fromList(chunk));
      await _bluetoothConnection!.output.allSent;
      await Future.delayed(delay);
    }
  }

  // ---------------------------------------------------------------------
  // 3- دالة طباعة الإيصال الكاملة والمعالجة
  // ---------------------------------------------------------------------
  Future<void> _printReceipt() async {
    if (_nameController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('الرجاء كتابة اسم المريض أولاً للطباعة')),
        );
      }
      return;
    }

    try {
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? targetDevice;

      for (var device in devices) {
        String name = (device.name ?? '').toLowerCase();
        if (name.contains('esp32') || name.contains('printer')) {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice == null && devices.isNotEmpty) {
        targetDevice = devices.first;
      }

      if (targetDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على طابعة مقترنة')),
          );
        }
        return;
      }

      if (_bluetoothConnection == null || !_bluetoothConnection!.isConnected) {
        _bluetoothConnection =
            await BluetoothConnection.toAddress(targetDevice.address);
      }

      List<String> analysisNames = _selectedAnalysisIds.map((id) {
        var item = _allAvailableAnalysis.firstWhere(
          (e) => e['id'] == id,
          orElse: () => {'name': ''},
        );
        return item['name'].toString();
      }).toList();

      double paid = double.tryParse(_paidController.text) ?? 0.0;
      String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      String patientIdStr = widget.patientData?['id']?.toString() ?? 'NEW';

      List<int> finalBytes = [];

      // تهيئة الطابعة
      finalBytes.addAll([0x1B, 0x40]);

      // --- Header ---
      finalBytes.addAll([0x1B, 0x61, 0x01]); // Center
      finalBytes.addAll([0x1B, 0x21, 0x30]); // Large Font
      finalBytes.addAll("S-LAB\n".codeUnits);
      finalBytes.addAll([0x1B, 0x21, 0x00]); // Normal Font
      finalBytes.addAll("01009726362\n".codeUnits);
      finalBytes.addAll("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n".codeUnits);

      // --- Patient Info ---
      finalBytes.addAll([0x1B, 0x61, 0x00]); // Left Align
      finalBytes.addAll([0x1B, 0x45, 0x01]); // Bold
      finalBytes.addAll("ID    : $patientIdStr\n".codeUnits);
      finalBytes.addAll([0x1B, 0x45, 0x00]);

      // إرسال الجزء النصي الحالي قبل طباعة صوة الاسم
      await _sendBytesInChunks(finalBytes);
      finalBytes.clear();

      // طباعة اسم المريض كصورة معالجة
      final nameCmds = await _renderArabicTextToEscStarCommands(
        "الاسم: ${_nameController.text}",
        fontSize: 21,
      );
      if (nameCmds.isNotEmpty) {
        _bluetoothConnection!.output.add(Uint8List.fromList([0x1B, 0x33, 24]));
        await _bluetoothConnection!.output.allSent;
        for (var cmd in nameCmds) {
          _bluetoothConnection!.output.add(cmd);
          await _bluetoothConnection!.output.allSent;
          _bluetoothConnection!.output.add(Uint8List.fromList([0x0A]));
          await _bluetoothConnection!.output.allSent;
          await Future.delayed(const Duration(milliseconds: 15));
        }
        _bluetoothConnection!.output.add(Uint8List.fromList([0x1B, 0x32]));
        await _bluetoothConnection!.output.allSent;
      }

      // تكملة بيانات التاريخ والتحاليل
      finalBytes.addAll([0x1B, 0x45, 0x01]);
      finalBytes.addAll("Date  : $dateStr\n".codeUnits);
      finalBytes.addAll([0x1B, 0x45, 0x00]);
      finalBytes.addAll("--------------------------------\n".codeUnits);

      await _sendBytesInChunks(finalBytes);
      finalBytes.clear();

      // طباعة قائمة التحاليل باللغة العربية كصورة
      if (analysisNames.isNotEmpty) {
        final testsCmds = await _renderArabicTextToEscStarCommands(
          "التحاليل: ${analysisNames.join(' ، ')}",
          fontSize: 20,
        );
        if (testsCmds.isNotEmpty) {
          _bluetoothConnection!.output
              .add(Uint8List.fromList([0x1B, 0x33, 24]));
          await _bluetoothConnection!.output.allSent;
          for (var cmd in testsCmds) {
            _bluetoothConnection!.output.add(cmd);
            await _bluetoothConnection!.output.allSent;
            _bluetoothConnection!.output.add(Uint8List.fromList([0x0A]));
            await _bluetoothConnection!.output.allSent;
            await Future.delayed(const Duration(milliseconds: 15));
          }
          _bluetoothConnection!.output.add(Uint8List.fromList([0x1B, 0x32]));
          await _bluetoothConnection!.output.allSent;
        }
      }

      finalBytes.addAll("--------------------------------\n".codeUnits);

      // --- Financial Summary ---
      String totalStr = _totalAmount.toStringAsFixed(0);
      String paidStr = paid.toStringAsFixed(0);
      String remStr = _remainingAmount.toStringAsFixed(0);

      finalBytes.addAll([0x1B, 0x61, 0x01]); // Center
      finalBytes.addAll([0x1B, 0x45, 0x01]); // Bold
      finalBytes.addAll("[$totalStr] + [$paidStr] - [$remStr]\n".codeUnits);
      finalBytes.addAll("================================\n".codeUnits);

      await _sendBytesInChunks(finalBytes);
      finalBytes.clear();

      // --- Tube Labels ---
      final tubeCmds = await _renderArabicTextToEscStarCommands(
        "$patientIdStr - ${_nameController.text}",
        fontSize: 20,
      );

      for (int i = 0; i < 3; i++) {
        if (tubeCmds.isNotEmpty) {
          _bluetoothConnection!.output
              .add(Uint8List.fromList([0x1B, 0x33, 24]));
          await _bluetoothConnection!.output.allSent;
          for (var cmd in tubeCmds) {
            _bluetoothConnection!.output.add(cmd);
            await _bluetoothConnection!.output.allSent;
            _bluetoothConnection!.output.add(Uint8List.fromList([0x0A]));
            await _bluetoothConnection!.output.allSent;
            await Future.delayed(const Duration(milliseconds: 15));
          }
          _bluetoothConnection!.output.add(Uint8List.fromList([0x1B, 0x32]));
          await _bluetoothConnection!.output.allSent;
        }
        _bluetoothConnection!.output.add(
            Uint8List.fromList("--------------------------------\n".codeUnits));
        await _bluetoothConnection!.output.allSent;
      }

      // تغذية أسطر إضافية للقطع
      _bluetoothConnection!.output.add(Uint8List.fromList([0x1B, 0x64, 0x03]));
      await _bluetoothConnection!.output.allSent;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت طباعة الإيصال بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الطباعة: $e')),
        );
      }
    }
  }

  Future<bool> _savePatientData() async {
    if (!_formKey.currentState!.validate()) return false;
    if (_selectedAnalysisIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار تحليل واحد على الأقل')),
        );
      }
      return false;
    }

    final db = await _dbHelper.db;
    if (db == null) return false;

    String currentDateTime = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.now());

    Map<String, dynamic> patientMap = {
      'name': _nameController.text,
      'age': int.tryParse(_ageController.text) ?? 0,
      'phone': _phoneController.text,
      'date_time':
          _isEditMode ? widget.patientData!['date_time'] : currentDateTime,
      'total_amount': _totalAmount,
      'paid_amount': double.tryParse(_paidController.text) ?? 0.0,
      'remaining_amount': _remainingAmount,
      'notes': _notesController.text,
      'image_path': _selectedImage?.path ?? '',
    };

    int patientId;
    if (_isEditMode) {
      patientId = widget.patientData!['id'];
      await db.update(
        'patients',
        patientMap,
        where: 'id = ?',
        whereArgs: [patientId],
      );
      await db.delete(
        'patient_analysis',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );
    } else {
      patientId = await db.insert('patients', patientMap);
    }

    for (var analysisId in _selectedAnalysisIds) {
      await db.insert('patient_analysis', {
        'patient_id': patientId,
        'analysis_id': analysisId,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'تم تعديل البيانات بنجاح'
                : 'تم حفظ بيانات المريض بنجاح',
          ),
        ),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'تعديل بيانات المريض' : 'إدخال مريض جديد'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة الإيصال',
            onPressed: _printReceipt,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'البيانات الشخصية للمريض',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المريض بالكامل',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السن',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val!.isEmpty ? 'أدخل السن' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val!.isEmpty ? 'أدخل رقم الهاتف' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText:
                      'ملاحظات طبية / إضافية (تُحفظ داخل التطبيق فقط ولا تُطبع)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const Divider(height: 30),
              const Text(
                'التحاليل الطبية المطلوبة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _showAnalysisSelectionDialog,
                icon: const Icon(Icons.list_alt),
                label: Text(
                  _selectedAnalysisIds.isEmpty
                      ? 'اضغط اختيار التحاليل'
                      : 'تم اختيار ${_selectedAnalysisIds.length} تحليل (اضغط للتعديل)',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 15),
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي:'),
                          Text(
                            '${_totalAmount.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _paidController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ المدفوع',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المتبقي:'),
                          Text(
                            '${_remainingAmount.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _remainingAmount > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        bool success = await _savePatientData();
                        if (success && mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: Text(_isEditMode ? 'تعديل' : 'حفظ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _printReceipt,
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
