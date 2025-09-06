import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'screens/pos_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cheemow POS',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: PosMainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
