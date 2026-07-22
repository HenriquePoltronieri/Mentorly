import 'package:flutter/material.dart';
import 'app/routes.dart';
import 'app/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mentorly',
      theme: appTheme,
      initialRoute: AppRoutes.perfilSelection,
      routes: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}