import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/services/apiService.dart';
import '../../../core/services/authService.dart';

// tela de login da coordenacao
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> POST {baseUrl}/api/coordenacao/login
// body enviado -> { "email": "...", "senha": "..." }
// resposta esperada em caso de sucesso (200) ->
// { "token": "...", "nome": "...", "id": 1 }
// resposta esperada em caso de erro (401/400) ->
// { "erro": "mensagem explicando o erro" }
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _carregando = false;
  String? _mensagemErro;

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _authService.loginCoordenacao(
        _emailController.text.trim(),
        _senhaController.text,
      );

      // login deu certo
      // por enquanto so navega, depois a gente salva o token (SharedPreferences)
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.coordenacaoHome);
    } on ApiException catch (e) {
      // a API respondeu, mas recusou: mostra o motivo real em vez de
      // dizer que o servidor esta fora do ar
      setState(() {
        _mensagemErro = e.statusCode == 401 || e.statusCode == 400
            ? 'Email ou senha incorretos'
            : e.mensagem;
      });
    } catch (e) {
      setState(() {
        _mensagemErro = 'Não foi possível conectar ao servidor';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
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
      appBar: AppBar(title: const Text('Login Coordenação')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Digite o email';
                  }
                  if (!valor.contains('@')) {
                    return 'Email inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Digite a senha';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _mensagemErro!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _carregando ? null : _fazerLogin,
                child: _carregando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
                           const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.cadastro);
                },
                child: const Text('Não tem conta? Cadastre-se'),
              ),
              const SizedBox(height: 12),
              // botao temporario so pra testar as telas sem precisar do backend
              // TODO: remover isso quando o backend estiver pronto
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.coordenacaoHome);
                },
                child: const Text('Pular login (modo teste)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}