import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database/app_database.dart';
import 'data/repositories/person_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  runApp(FamilyTreeApp(persons: PersonRepository(db)));
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key, required this.persons});

  final PersonRepository persons;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شجرة عائلتي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('شجرة عائلتي')),
        body: Center(
          child: FutureBuilder<int>(
            future: persons.count(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('خطأ في قاعدة البيانات: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              return Text('عدد الأفراد المسجلين: ${snapshot.data}');
            },
          ),
        ),
      ),
    );
  }
}
