import 'package:flutter/material.dart';
import '../../../core/widgets/customTextfield.dart';
import '../../../core/widgets/customButton.dart';
import '../../../core/utils/validators.dart';
import '../../../app/routes.dart';
import '../controllers/authController.dart';

// Professor recebe o email por convite da coordenacao e cria a senha aqui
// pela primeira vez (Confirmar senha garante que ele digitou certo)
// O token vem na URL: /definir-senha?token=xxx
class DefinirSenhaProfessorScreen extends StatefulWidget {
  const DefinirSenhaProfessorScreen({super.key});

  @override
  State<DefinirSenhaProfessorScreen> createState() => _DefinirSenhaProfessorScreenState();
}

class _DefinirSenhaProfessorScreenState extends State<DefinirSenhaProfessorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _authController = AuthController();
  bool _carregando = false;
  String? _token;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['token'] != null) {
      _token = args['token'] as String;
    } else {
      // Try to get from query parameters
      final uri = Uri.base;
      _token = uri.queryParameters['token'];
    }
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token inválido ou ausente. Acesse pelo link do e-mail.')),
      );
      return;
    }

    setState(() => _carregando = true);
    final sucesso = await _authController.criarSenhaProfessor(
      email: _emailController.text,
      senha: _senhaController.text,
      confirmarSenha: _confirmarSenhaController.text,
      token: _token!,
    );
    setState(() => _carregando = false);

    if (sucesso && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.listaTurmas);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authController.erro ?? 'Erro ao definir senha')),
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
                Text('Definir Senha', style: TextStyle(fontSize: 24)),
                SizedBox(height: 8),
                Text('Digite sua nova senha para ativar sua conta', style: TextStyle(color: Colors.grey[600])),
                SizedBox(height: 24),
                CustomTextfield(
                  label: 'Email',
                  controller: _emailController,
                  validator: Validators.validarEmail,
                ),
                SizedBox(height: 12),
                CustomTextfield(
                  label: 'Nova senha',
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
                  texto: 'Definir senha e entrar',
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