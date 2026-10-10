import 'package:flutter/material.dart';
import '../../../../core/utils/mensagensConvite.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/apiService.dart';
import '../../services/professoresService.dart';

// Cadastro de professor pela Coordenacao.
//
// O professor nao cria a propria conta: a Coordenacao o cadastra e ele
// recebe por email um convite para definir a senha.
//
// POST /api/coordenacao/professores
//   body -> { "nome", "email", "disciplina" }
//   201  -> { "id", "nome", "email", "disciplina", "conviteEnviado", ... }
//
// Quando o backend esta sem SMTP configurado (modo dev), a resposta traz
// tambem "conviteToken" - a tela mostra o link para que o primeiro acesso
// do professor possa ser feito localmente.
class CadastroProfessorScreen extends StatefulWidget {
  const CadastroProfessorScreen({super.key});

  @override
  State<CadastroProfessorScreen> createState() => _CadastroProfessorScreenState();
}

class _CadastroProfessorScreenState extends State<CadastroProfessorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _disciplinaController = TextEditingController();
  final ProfessoresService _professoresService = ProfessoresService();

  bool _carregando = false;
  String? _mensagemErro;
  String? _conviteToken;
  bool _conviteEnviado = false;

  Future<void> _cadastrarProfessor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final professor = await _professoresService.cadastrarProfessor(
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        disciplina: _disciplinaController.text.trim(),
      );

      if (!mounted) return;

      final token = professor['conviteToken'] as String?;
      if (token != null) {
        // Modo de desenvolvimento (DEV_EXPOSE_AUTH_CODES): o backend devolveu o
        // token; mostra o link em vez de fechar a tela.
        setState(() {
          _conviteToken = token;
          _conviteEnviado = professor['conviteEnviado'] == true;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MensagensConvite.cadastro(professor))),
      );
      Navigator.pop(context, true); // volta pra lista avisando que deu certo
    } on ApiException catch (e) {
      setState(() => _mensagemErro = e.mensagem);
    } catch (e) {
      setState(() {
        _mensagemErro = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  // Mostrado so quando o backend esta em modo dev (DEV_EXPOSE_AUTH_CODES).
  Widget _blocoConvite() {
    // Uri.base.origin so existe em http/https (Flutter Web); em outras
    // plataformas cai no endereco padrao do app em desenvolvimento.
    final base = Uri.base;
    final origem = (base.scheme == 'http' || base.scheme == 'https')
        ? base.origin
        : 'http://localhost:3000';
    final link = '$origem/#/definir-senha?token=${_conviteToken ?? ''}';

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.10),
          border: Border.all(color: Colors.amber.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Professor cadastrado',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _conviteEnviado
                  ? 'O convite foi enviado por e-mail. Em desenvolvimento, '
                      'este link tambem serve para o primeiro acesso:'
                  : 'O e-mail com o convite não pôde ser enviado. Passe este '
                      'link para o professor fazer o primeiro acesso:',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            SelectableText(link, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar link'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Concluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
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
                onPressed: _carregando || _conviteToken != null
                    ? null
                    : _cadastrarProfessor,
                child: _carregando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cadastrar'),
              ),
              if (_conviteToken != null) _blocoConvite(),
            ],
          ),
        ),
      ),
    );
  }
}