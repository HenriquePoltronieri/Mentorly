import 'package:flutter/material.dart';
import '../../../core/widgets/customTextfield.dart';
import '../../../core/widgets/customButton.dart';
import '../../../core/utils/validators.dart';
import '../../../app/routes.dart';
import '../controllers/authController.dart';

// Professor recebe o email por convite da coordenacao e cria a senha aqui
// pela primeira vez (Confirmar senha garante que ele digitou certo)
class ProfessorLoginScreen extends StatefulWidget {
  const ProfessorLoginScreen({super.key});

  @override
  State<ProfessorLoginScreen> createState() => _ProfessorLoginScreenState();
}

class _ProfessorLoginScreenState extends State<ProfessorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _authController = AuthController();
  bool _carregando = false;

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);
    final sucesso = await _authController.criarSenhaProfessor(
      email: _emailController.text,
      senha: _senhaController.text,
      confirmarSenha: _confirmarSenhaController.text,
    );
    setState(() => _carregando = false);

    if (sucesso && mounted) {
      Navigator.pushNamed(context, AppRoutes.twoFactor);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authController.erro ?? 'Erro ao entrar')),
      );
    }
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
                Text('Entrar', style: TextStyle(fontSize: 24)),
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
                SizedBox(height: 12),
                CustomTextfield(
                  label: 'Confirmar senha',
                  controller: _confirmarSenhaController,
                  senha: true,
                  validator: Validators.validarSenha,
                ),
                SizedBox(height: 24),
                CustomButton(
                  texto: 'Entrar',
                  onPressed: _entrar,
                  carregando: _carregando,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
