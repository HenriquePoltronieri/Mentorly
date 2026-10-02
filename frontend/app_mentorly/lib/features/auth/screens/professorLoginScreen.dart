import 'package:flutter/material.dart';
import '../../../core/widgets/customTextfield.dart';
import '../../../core/widgets/customButton.dart';
import '../../../core/utils/validators.dart';
import '../../../app/routes.dart';
import '../../../core/services/authService.dart';

// Tela de login do professor (para logins subsequentes, após já ter definido a senha)
class ProfessorLoginScreen extends StatefulWidget {
  const ProfessorLoginScreen({super.key});

  @override
  State<ProfessorLoginScreen> createState() => _ProfessorLoginScreenState();
}

class _ProfessorLoginScreenState extends State<ProfessorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _authService = AuthService();
  bool _carregando = false;

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);
    try {
      await _authService.loginProfessor(
        email: _emailController.text,
        senha: _senhaController.text,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.listaTurmas);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entrar como Professor', style: TextStyle(fontSize: 24)),
                SizedBox(height: 24),
                CustomTextfield(
                  label: 'Email',
                  controller: _emailController,
                  validator: Validators.validarEmail,
                ),
                SizedBox(height: 12),
                CustomTextfield(
                  label: 'Senha',
                  controller: _senhaController,
                  senha: true,
                  validator: Validators.validarSenha,
                ),
                SizedBox(height: 24),
                CustomButton(
                  texto: 'Entrar',
                  onPressed: _entrar,
                  carregando: _carregando,
                ),
                SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.definirSenha);
                  },
                  child: const Text('Primeiro acesso? Definir senha'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
