import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const PehchaanApp());
}

class PehchaanApp extends StatelessWidget {
  const PehchaanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pehchaan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F5F3),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}