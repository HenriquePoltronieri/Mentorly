import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../app/routes.dart';

// tela de cadastro de uma nova conta de coordenacao
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> POST {baseUrl}/api/coordenacao/cadastro
// body enviado -> { "nome": "...", "email": "...", "senha": "..." }
// resposta esperada em caso de sucesso (201) ->
// { "id": 1, "nome": "...", "email": "..." }
// (o backend deve, nesse momento, disparar o codigo de verificacao
// por email/sms pro usuario, que sera digitado na twoFactorScreen)
// resposta esperada em caso de erro (400) ->
// { "erro": "mensagem explicando o erro" } (ex: "email ja cadastrado")
class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _carregando = false;
  String? _mensagemErro;

  // ATENCAO: 10.0.2.2 so funciona no emulador Android.
  // Testando no Chrome/Web, troca por 'http://localhost:5000'
  static const String baseUrl = 'http://localhost:5000';

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/coordenacao/cadastro'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nome': _nomeController.text.trim(),
              'email': _emailController.text.trim(),
              'senha': _senhaController.text,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.twoFactor,
          arguments: {'email': _emailController.text.trim()},
        );
      } else {
        final dados = jsonDecode(response.body);
        setState(() {
          _mensagemErro = dados['erro'] ?? 'Erro ao cadastrar';
        });
      }
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
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta - Coordenação')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Digite o nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
                    return 'Digite uma senha';
                  }
                  if (valor.length < 6) {
                    return 'A senha precisa ter no mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmarSenhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar senha',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor != _senhaController.text) {
                    return 'As senhas não coincidem';
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
                onPressed: _carregando ? null : _cadastrar,
                child: _carregando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}