import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'adicionarAlunosModal.dart';

// tela que lista os alunos de uma turma especifica
// recebe a turma via Navigator.pushNamed(context, AppRoutes.listaAlunosTurma, arguments: turma)
// onde "turma" é o Map que veio da gerenciarTurmasScreen (tem id e nome)
//
// IMPORTANTE PRO BACKEND:
// endpoint -> GET {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos
// resposta esperada (200) -> [ { "id": 1, "nome": "...", "matricula": "..." }, ... ]
class ListaAlunosTurmaScreen extends StatefulWidget {
  const ListaAlunosTurmaScreen({super.key});

  @override
  State<ListaAlunosTurmaScreen> createState() => _ListaAlunosTurmaScreenState();
}

class _ListaAlunosTurmaScreenState extends State<ListaAlunosTurmaScreen> {
  // ATENCAO: 10.0.2.2 so funciona no emulador Android.
  // Testando no Chrome/Web, troca por 'http://localhost:5000'
  static const String baseUrl = 'http://localhost:5000';

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _alunos = [];
  Map<String, dynamic>? _turma;
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _turma = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _jaBuscou = true;
      _buscarAlunos();
    }
  }

  Future<void> _buscarAlunos() async {
    if (_turma == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Turma não informada';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/coordenacao/turmas/${_turma!['id']}/alunos'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() => _alunos = jsonDecode(response.body));
      } else {
        setState(() => _mensagemErro = 'Erro ao buscar alunos');
      }
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirAdicionarAlunos() async {
    if (_turma == null) return;

    final adicionou = await showDialog<bool>(
      context: context,
      builder: (_) => AdicionarAlunosModal(turmaId: _turma!['id']),
    );

    if (adicionou == true) _buscarAlunos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_turma != null ? 'Alunos - ${_turma!['nome']}' : 'Alunos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirAdicionarAlunos,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarAlunos,
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

    if (_alunos.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhum aluno cadastrado nessa turma ainda')),
        ],
      );
    }

    return ListView.builder(
      itemCount: _alunos.length,
      itemBuilder: (context, index) {
        final aluno = _alunos[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(aluno['nome'] ?? ''),
          subtitle: Text('Matrícula: ${aluno['matricula'] ?? ''}'),
        );
      },
    );
  }
}