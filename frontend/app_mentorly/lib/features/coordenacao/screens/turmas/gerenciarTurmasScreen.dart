import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../app/routes.dart';
import 'adicionarTurmaModal.dart';

// tela onde a coordenacao cria turmas e ve a lista de turmas existentes
// (diferente da listaTurmasProfessorScreen, que serve pra VINCULAR
// professores as turmas ja criadas aqui)
//
// IMPORTANTE PRO BACKEND:
// endpoint -> GET {baseUrl}/api/coordenacao/turmas
// resposta esperada (200) -> [ { "id": 1, "nome": "...", "disciplina": "...", "turno": "..." }, ... ]
class GerenciarTurmasScreen extends StatefulWidget {
  const GerenciarTurmasScreen({super.key});

  @override
  State<GerenciarTurmasScreen> createState() => _GerenciarTurmasScreenState();
}

class _GerenciarTurmasScreenState extends State<GerenciarTurmasScreen> {
  // ATENCAO: 10.0.2.2 so funciona no emulador Android.
  // Testando no Chrome/Web, troca por 'http://localhost:5000'
  static const String baseUrl = 'http://localhost:5000';

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _turmas = [];

  @override
  void initState() {
    super.initState();
    _buscarTurmas();
  }

  Future<void> _buscarTurmas() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/coordenacao/turmas'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() => _turmas = jsonDecode(response.body));
      } else {
        setState(() => _mensagemErro = 'Erro ao buscar turmas');
      }
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirCriarTurma() async {
    final criou = await showDialog<bool>(
      context: context,
      builder: (_) => const AdicionarTurmaModal(),
    );
    if (criou == true) _buscarTurmas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turmas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCriarTurma,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar turma'),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarTurmas,
        child: _construirCorpo(),
      ),
    );
  }

  Widget _construirCorpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mensagemErro != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Center(
            child: Text(_mensagemErro!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    if (_turmas.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhuma turma cadastrada ainda')),
        ],
      );
    }

    return ListView.builder(
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final turma = _turmas[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.class_)),
          title: Text(turma['nome'] ?? ''),
          subtitle: Text('${turma['disciplina'] ?? ''} • ${turma['turno'] ?? ''}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.listaAlunosTurma, arguments: turma);
          },
        );
      },
    );
  }
}