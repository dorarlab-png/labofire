import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'patients.dart';
import 'searchpa.dart';
import 'analysis.dart';
import 'accounts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدارة معمل التحاليل',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'),
      ],
      locale: const Locale('ar', 'AE'),
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'إدخال مريض جديد',
        'icon': Icons.person_add_alt_1_rounded,
        'color': Colors.blue.shade700,
        'page': const PatientsPage()
      },
      {
        'title': 'استعلام وتعديل مريض',
        'icon': Icons.image_search_rounded,
        'color': Colors.orange.shade700,
        'page': const SearchPaPage()
      },
      {
        'title': 'إدارة التحاليل الطبية',
        'icon': Icons.science_rounded,
        'color': Colors.teal.shade700,
        'page': const AnalysisPage()
      },
      {
        'title': 'الحسابات والتقارير',
        'icon': Icons.calculate_rounded,
        'color': Colors.red.shade700,
        'page': const AccountsPage()
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم - معمل التحاليل الطبية',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: menuItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => menuItems[index]['page']),
                  );
                },
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor:
                          menuItems[index]['color'].withOpacity(0.1),
                      child: Icon(menuItems[index]['icon'],
                          size: 40, color: menuItems[index]['color']),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      menuItems[index]['title'],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
