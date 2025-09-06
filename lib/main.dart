import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_config.dart';
import 'screens/pos_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 恢復正常的系統UI模式，但保持橫向鎖定
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // 設置正常的系統UI樣式
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.blue[800], // 配合 AppBar 顏色
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await AppConfig.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cheemow POS',
      theme: ThemeData(
        primarySwatch: Colors.blue, 
        useMaterial3: false, // 保持 Material 2 設計
      ),
      home: PosMainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
