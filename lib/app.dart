import 'package:flutter/material.dart';
import 'features/home/presentation/home_shell.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BicycleGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomeShell(),
    );
  }
}
