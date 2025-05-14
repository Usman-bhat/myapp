import 'package:flutter/material.dart';
import 'ui.dart';

void main() {
  runApp(const DirBusterApp());
}

class DirBusterApp extends StatelessWidget {
  const DirBusterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter DirBuster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BruteforceScreen(),
    );
  }
}