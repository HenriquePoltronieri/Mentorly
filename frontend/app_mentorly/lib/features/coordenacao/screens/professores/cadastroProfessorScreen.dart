import 'package:flutter/material.dart';
import '../../services/professoresService.dart';

// tela onde a coordenacao cadastra um novo professor
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> POST {baseUrl}/api/coordenacao/professores
// body enviado -> { "nome": "...", "email": "...", "senha": "...", "disciplina": "..." }
// resposta esperada em caso de sucesso (201) ->
// { "id": 1, "nome": "...", "email": "...", "disciplina": "..." }
// resposta esperada em caso de erro (400) ->
// { "erro": "mensagem explicando o erro" } (ex: "email ja cadastrado")
class CadastroProfessorScreen extends StatefulWidget {
  const CadastroProfessorScreen({super.key});

  @override
  State<CadastroProfessorScreen> createState() => _CadastroProfessorScreenState();
}

class _CadastroProfessorScreenState extends State<CadastroProfessorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _disciplinaController = TextEditingController();
  final ProfessoresService _professoresService = ProfessoresService();

  bool _carregando = false;
  String? _mensagemErro;

  Future<void> _cadastrarProfessor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _professoresService.cadastrarProfessor(
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        disciplina: _disciplinaController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Professor cadastrado com sucesso')),
      );
      Navigator.pop(context, true); // volta pra lista avisando que deu certo
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
    _disciplinaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Professor')),
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
                  labelText: 'Senha provisória',
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
                controller: _disciplinaController,
                decoration: const InputDecoration(
                  labelText: 'Disciplina',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Digite a disciplina';
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
                onPressed: _carregando ? null : _cadastrarProfessor,
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