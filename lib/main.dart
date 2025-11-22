import 'package:flutter/material.dart';
import 'theme/terminal_theme.dart';
import 'pages/home_page.dart';
import 'misc/logger.dart';

void main() {
  AppLogger.init();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boot Helper',
      theme: buildTerminalTheme(),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
