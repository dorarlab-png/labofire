import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static Database? _db;

  Future<Database?> get db async {
    if (_db != null) return _db;
    _db = await initDb();
    return _db;
  }

  Future<Database> initDb() async {
    String databasePath = await getDatabasesPath();
    String path = join(databasePath, 'medical_lab.db');

    Database myDb = await openDatabase(
      path,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      version: 2,
    );
    return myDb;
  }

  void _onCreate(Database db, int version) async {
    // 1. جدول التحاليل
    await db.execute('''
      CREATE TABLE "analysis" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "price" REAL NOT NULL
      )
    ''');

    // 2. جدول المرضى
    await db.execute('''
      CREATE TABLE "patients" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "age" INTEGER NOT NULL,
        "phone" TEXT NOT NULL,
        "date_time" TEXT NOT NULL,
        "total_amount" REAL NOT NULL,
        "paid_amount" REAL NOT NULL,
        "remaining_amount" REAL NOT NULL,
        "notes" TEXT,
        "image_path" TEXT
      )
    ''');

    // 3. جدول الربط
    await db.execute('''
      CREATE TABLE "patient_analysis" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "patient_id" INTEGER NOT NULL,
        "analysis_id" INTEGER NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE,
        FOREIGN KEY (analysis_id) REFERENCES analysis (id) ON DELETE CASCADE
      )
    ''');

    print("تم إنشاء قاعدة البيانات بنجاح بالإصدار الجديد");

    // إدراج قائمة التحاليل الافتراضية الجديدة فور إنشاء الجدول
    await _insertDefaultAnalysis(db);
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE patients ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE patients ADD COLUMN image_path TEXT');
      print("تم ترقية قاعدة البيانات بنجاح وإضافة الأعمدة الجديدة");
    }
  }

  // دالة حقن البيانات الافتراضية بالتحديث الجديد
  Future<void> _insertDefaultAnalysis(Database db) async {
    final List<Map<String, dynamic>> defaultList = [
      {'name': 'Urine', 'price': 40.0},
      {'name': 'Stool', 'price': 40.0},
      {'name': 'preg urine', 'price': 60.0},
      {'name': 'preg blood', 'price': 70.0},
      {'name': 'BHCG', 'price': 150.0},
      {'name': 'F', 'price': 40.0},
      {'name': 'P.P', 'price': 40.0},
      {'name': 'R.B.S', 'price': 40.0},
      {'name': 'HBA1C', 'price': 100.0},
      {'name': 'CBC', 'price': 130.0},
      {'name': 'Hb', 'price': 60.0},
      {'name': 'TLC', 'price': 80.0},
      {'name': 'PLT', 'price': 80.0},
      {'name': 'Differential Count', 'price': 80.0},
      {'name': 'ABO', 'price': 40.0},
      {'name': 'Rh', 'price': 40.0},
      {'name': 'B.T', 'price': 40.0},
      {'name': 'C.T', 'price': 40.0},
      {'name': 'GPT  ALT', 'price': 60.0},
      {'name': 'GOT  AST', 'price': 60.0},
      {'name': 'T-Bili', 'price': 60.0},
      {'name': 'D-Bili', 'price': 60.0},
      {'name': 'Alb', 'price': 80.0},
      {'name': 'Alb 24 urine', 'price': 120.0},
      {'name': 'ALP', 'price': 80.0},
      {'name': 'T-Protein', 'price': 100.0},
      {'name': 'GGT', 'price': 100.0},
      {'name': 'Creatinine', 'price': 60.0},
      {'name': 'Urea', 'price': 60.0},
      {'name': 'U.A', 'price': 80.0},
      {'name': 'Na', 'price': 80.0},
      {'name': 'K', 'price': 80.0},
      {'name': 'Lipid', 'price': 280.0},
      {'name': 'Cholesterol', 'price': 80.0},
      {'name': 'T.G', 'price': 80.0},
      {'name': 'HDL', 'price': 80.0},
      {'name': 'LDL', 'price': 80.0},
      {'name': 'ESR', 'price': 60.0},
      {'name': 'ASOT', 'price': 70.0},
      {'name': 'CRP', 'price': 70.0},
      {'name': 'RF', 'price': 100.0},
      {'name': 'PT-PC-INR', 'price': 80.0},
      {'name': 'PTT', 'price': 80.0},
      {'name': 'Lupus', 'price': 200.0},
      {'name': 'HCV Ab', 'price': 120.0},
      {'name': 'HBS Ag', 'price': 120.0},
      {'name': 'HAV IgM', 'price': 200.0},
      {'name': 'HIV', 'price': 200.0},
      {'name': 'T3', 'price': 120.0},
      {'name': 'Free T3', 'price': 120.0},
      {'name': 'T4', 'price': 120.0},
      {'name': 'Free T4', 'price': 120.0},
      {'name': 'TSH', 'price': 120.0},
      {'name': 'T3 , T4 , TSH', 'price': 350.0},
      {'name': 'Free T3 , Free  T4 , TSH', 'price': 350.0},
      {'name': 'FSH', 'price': 130.0},
      {'name': 'LH', 'price': 130.0},
      {'name': 'PRL  Prolactin', 'price': 130.0},
      {'name': 'PROGESTRONE (P4)', 'price': 150.0},
      {'name': 'E2', 'price': 150.0},
      {'name': 'Testosterone', 'price': 150.0},
      {'name': 'Free Testosterone', 'price': 200.0},
      {'name': 'Toxo IgG', 'price': 150.0},
      {'name': 'Toxo IgM', 'price': 150.0},
      {'name': 'CMV IgG', 'price': 150.0},
      {'name': 'CMV IgM', 'price': 150.0},
      {'name': 'RUBELLA  IgG', 'price': 150.0},
      {'name': 'RUBELLA  IgM', 'price': 150.0},
      {'name': 'HERPES IgG', 'price': 150.0},
      {'name': 'HERPES IgM', 'price': 150.0},
      {'name': 'ANTI  CARDIOLIPIN  IgG', 'price': 300.0},
      {'name': 'ANTI  CARDIOLIPIN  IgM', 'price': 300.0},
      {'name': 'ANTI  PHOSPHLIPID  IgG', 'price': 300.0},
      {'name': 'ANTI  PHOSPHLIPID  IgM', 'price': 300.0},
      {'name': 'TORCH (IgG & IgM )EACH', 'price': 1300.0},
      {'name': 'Semen    السائل المنوي ', 'price': 140.0},
      {'name': 'Brucella M A', 'price': 150.0},
      {'name': 'Widal test', 'price': 150.0},
      {'name': 'Ca', 'price': 80.0},
      {'name': 'ionized  Ca++', 'price': 100.0},
      {'name': 'B U N', 'price': 60.0},
      {'name': 'IgE  TOTAL', 'price': 200.0},
      {'name': 'PHOSPHRUS P', 'price': 80.0},
      {'name': 'Urine C/S', 'price': 180.0},
      {'name': 'AFP', 'price': 180.0},
      {'name': 'Iron Fe', 'price': 100.0},
      {'name': 'Coagulation Profile', 'price': 160.0},
      {'name': 'ANA', 'price': 250.0},
      {'name': 'ASMA', 'price': 350.0},
      {'name': 'PSA  Total ', 'price': 150.0},
      {'name': 'PSA  Free  ', 'price': 180.0},
      {'name': 'AMA', 'price': 550.0},
      {'name': 'Anti CCP', 'price': 350.0},
      {'name': 'Bilharzial Ab', 'price': 220.0},
      {'name': 'CA-125', 'price': 250.0},
      {'name': 'CA-15.3', 'price': 250.0},
      {'name': 'CA-19.9', 'price': 250.0},
      {'name': 'CEA', 'price': 200.0},
      {'name': 'Depakine', 'price': 200.0},
      {'name': 'Tegretol', 'price': 200.0},
      {'name': 'DHEA-S', 'price': 250.0},
      {'name': 'Ferritin', 'price': 150.0},
      {'name': 'G6PD', 'price': 250.0},
      {'name': 'Growth Hormone', 'price': 300.0},
      {'name': 'H pylori Ab', 'price': 180.0},
      {'name': 'PTH', 'price': 250.0},
      {'name': 'Rh antibody titer ', 'price': 150.0},
      {'name': 'Stone', 'price': 150.0},
      {'name': 'TIBC', 'price': 100.0},
      {'name': 'Microalbuminuria', 'price': 100.0},
      {'name': 'Occult blood in stool ', 'price': 150.0},
      {'name': 'الفحص الدوري الشامل ', 'price': 1300.0},
      {'name': 'تحاليل ما قبل الزواج  الزوج', 'price': 260.0},
      {'name': 'تحاليل ما قبل الزواج  الزوجة', 'price': 420.0},
      {'name': 'CPK  -( CK) - ', 'price': 100.0},
      {'name': 'LDH', 'price': 100.0},
      {'name': 'Malaria Ag  ', 'price': 150.0},
      {'name': 'Mg ', 'price': 100.0},
      {'name': 'CK-MB', 'price': 100.0},
      {'name': 'Troponin I ', 'price': 200.0},
      {'name': 'CK-MB , LDH , Troponin I ', 'price': 400.0},
      {'name': 'AMH', 'price': 550.0},
      {'name': 'Drugs', 'price': 350.0},
      {'name': 'EBV IgG', 'price': 300.0},
      {'name': 'EBV IgM', 'price': 300.0},
      {'name': 'HBs Ab', 'price': 200.0},
      {'name': 'HBe Ab', 'price': 200.0},
      {'name': 'HBe Ag', 'price': 200.0},
      {'name': 'Cortisol am 10.00', 'price': 250.0},
      {'name': 'Cortisol pm 10.00', 'price': 250.0},
      {'name': 'Alb/Creat Ratio   ', 'price': 150.0},
      {'name': 'Vit  D3', 'price': 350.0},
      {'name': 'HCV PCR ', 'price': 500.0},
      {'name': 'HBV PCR ', 'price': 600.0},
      {'name': 'H pylori Ag stool نوعي', 'price': 180.0},
      {'name': 'H pylori Ag stool عددي', 'price': 180.0},
      {'name': 'عينة خارجية', 'price': 40.0},
      {'name': 'Amylase', 'price': 150.0},
      {'name': 'ESR,ASOT,CRP', 'price': 200.0},
      {'name': 'Homa-IR', 'price': 250.0},
      {'name': 'lipase', 'price': 150.0},
      {'name': 'Vit B12', 'price': 600.0},
    ];

    Batch batch = db.batch();
    for (var analysis in defaultList) {
      batch.insert('analysis', analysis);
    }
    await batch.commit(noResult: true);
    print("تم إدخال التحاليل الافتراضية بنجاح.");
  }
}
