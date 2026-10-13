import 'package:flutter/material.dart';
import 'tela_login.dart';

class ProfessorLoginScreen extends StatelessWidget {
  const ProfessorLoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const TelaLogin(professor: true);
}
