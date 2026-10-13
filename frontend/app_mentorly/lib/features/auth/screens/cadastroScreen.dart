import 'package:flutter/material.dart';
import 'tela_login.dart';

class CadastroScreen extends StatelessWidget {
  const CadastroScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const TelaLogin(professor: false, cadastroInicial: true);
}
