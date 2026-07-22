import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../app/routes.dart';
import '../../widgets/professorTopBar.dart';

// tela que lista os alunos de uma turma especifica do professor
// recebe a turma via Navigator.pushNamed(context, AppRoutes.turmaAlunos, arguments: turma)
//
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> GET {baseUrl}/api/professor/turmas/{turmaId}/alunos
// resposta esperada (200) ->
// [ { "id": 1, "nome": "...", "matricula": "...", "media": 7.2 }, ... ]
// "media" e a media geral do aluno na etapa atual (usa o GradeCalculator
// do lado do backend, ou o professor calcula e o backend so retorna pronto)
class TurmaAlunosScreen extends StatefulWidget {
  const TurmaAlunosScreen({super.key});

  @override
  State<TurmaAlunosScreen> createState() => _TurmaAlunosScreenState();
}

class _TurmaAlunosScreenState extends State<TurmaAlunosScreen> {
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
          .get(Uri.parse('$baseUrl/api/professor/turmas/${_turma!['id']}/alunos'))
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

  Color _corDaMedia(double? media) {
    if (media == null) return Colors.grey;
    if (media < 5) return Colors.red;
    if (media < 7) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'turmas'),
      body: Column(
        children: [
          if (_turma != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    _turma!['nome'] ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _buscarAlunos,
              child: _construirCorpo(),
            ),
          ),
        ],
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
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Fale com a coordenação para adicionar alunos',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alunos.length,
      itemBuilder: (context, index) {
        final aluno = _alunos[index];
        final media = (aluno['media'] as num?)?.toDouble();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(aluno['nome'] ?? ''),
            subtitle: Text('Matrícula: ${aluno['matricula'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _corDaMedia(media).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    media != null ? media.toStringAsFixed(1) : '-',
                    style: TextStyle(
                      color: _corDaMedia(media),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 14),
              ],
            ),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.alunoDetail, arguments: aluno);
            },
          ),
        );
      },
    );
  }
}