import 'package:flutter/material.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../../core/services/apiService.dart';
import '../../../../app/routes.dart';
import '../../widgets/professorTopBar.dart';
import '../../services/professorAlunosService.dart';
import '../../widgets/estatisticas_view.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../atividades/adicionarAtividadeModal.dart';

// tela que lista os alunos de uma turma especifica do professor
// recebe a turma via Navigator.pushNamed(context, AppRoutes.turmaAlunos, arguments: turma)
//
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> GET {baseUrl}/api/professor/turmas/{turmaId}/alunos
// resposta esperada (200) ->
// [ { "id": 1, "nome": "...", "matricula": "...", "media": 7.2 }, ... ]
// "media" vem do motor academico central do backend, na etapa atual.
class TurmaAlunosScreen extends StatefulWidget {
  const TurmaAlunosScreen({super.key});

  @override
  State<TurmaAlunosScreen> createState() => _TurmaAlunosScreenState();
}

class _TurmaAlunosScreenState extends State<TurmaAlunosScreen> {
  final ProfessorAlunosService _alunosService = ProfessorAlunosService();

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _alunos = [];
  Map<String, dynamic>? _turma;
  bool _jaBuscou = false;
  int _versaoEstatisticas = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _turma =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
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

    if (!mounted) return;
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final respostas = await Future.wait([
        _alunosService.listarAlunos(_turma!['id'] as int),
        ApiService().get('/professor/turmas/${_turma!['id']}/estatisticas')
      ]);
      final metricas = (respostas[1]['alunos'] as List);
      final alunos = (respostas[0] as List).map((a) {
        final m = metricas.where((m) => m['id'] == a['id']);
        return {
          ...Map<String, dynamic>.from(a as Map),
          if (m.isNotEmpty) ...Map<String, dynamic>.from(m.first as Map)
        };
      }).toList();
      if (!mounted) return;
      setState(() => _alunos = alunos);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Erro ao buscar alunos: ${e.mensagem}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _novaAtividade() async {
    try {
      final dados = await ApiService().get('/classes/${_turma!['id']}');
      if (!mounted) return;
      await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => AdicionarAtividadeModal(turmas: [
                    TurmaModel.fromJson(Map<String, dynamic>.from(dados as Map))
                  ])));
      if (mounted) {
        setState(() => _versaoEstatisticas++);
        _buscarAlunos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível abrir a atividade.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: const ProfessorTopBar(abaAtiva: 'turmas'),
          body: Column(
            children: [
              if (_turma != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          _turma!['nome'] ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.boletimTurma,
                          arguments: _turma,
                        ),
                        icon: const Icon(Icons.grading_outlined),
                        tooltip: 'Boletim e fechamento de etapas',
                      ),
                      IconButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.insightsTurma,
                          arguments: _turma,
                        ),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        tooltip: 'Insights da turma',
                      ),
                    ],
                  ),
                ),
              if (_turma != null)
                Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Wrap(spacing: 12, runSpacing: 8, children: [
                      OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                              context, AppRoutes.gradeNotas,
                              arguments: _turma),
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('Grade de notas')),
                      FilledButton.icon(
                          onPressed: _novaAtividade,
                          icon: const Icon(Icons.add),
                          label: const Text('+ Nova atividade')),
                      OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                              context, AppRoutes.chatIa,
                              arguments: _turma),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Conversar com IA')),
                    ])),
              const TabBar(
                  tabs: [Tab(text: 'Alunos'), Tab(text: 'Estatísticas')]),
              Expanded(
                child: TabBarView(children: [
                  RefreshIndicator(
                    onRefresh: () {
                      ApiService().invalidarCache();
                      return _buscarAlunos();
                    },
                    child: ConteudoPagina(child: _construirCorpo()),
                  ),
                  if (_turma != null)
                    EstatisticasView(
                        key: ValueKey(_versaoEstatisticas),
                        turmaId: _turma!['id'] as int)
                  else
                    const SizedBox.shrink(),
                ]),
              ),
            ],
          ),
        ));
  }

  Widget _construirCorpo() {
    if (_carregando) {
      return const CarregamentoPagina();
    }

    if (_mensagemErro != null) {
      return EstadoPagina(
          titulo: 'Falha ao carregar',
          mensagem: _mensagemErro!,
          acao: 'Tentar novamente',
          onPressed: _buscarAlunos);
    }

    if (_alunos.isEmpty) {
      return EstadoPagina(
          titulo: 'Nenhum aluno nesta turma',
          mensagem: 'A Coordenação cadastra os alunos desta turma.');
    }

    return ListView.separated(
      separatorBuilder: (_, indice) => const Divider(height: 1),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _alunos.length,
      itemBuilder: (context, index) {
        final aluno = _alunos[index];

        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(aluno['nome'] ?? ''),
          subtitle: Text(
              '${aluno['risco'] ?? 'Sem dados'} · ${aluno['acompanhamento']?['etapa'] ?? 'Selecione uma etapa'}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: corRisco(aluno['risco']?.toString() ?? 'Sem dados')
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  aluno['pontos_obtidos'] == null
                      ? '—'
                      : '${formatarMetrica(aluno['pontos_obtidos'])}/${formatarMetrica(aluno['pontos_avaliados'])} pts',
                  style: TextStyle(
                    color: corRisco(aluno['risco']?.toString() ?? 'Sem dados'),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.alunoDetail, arguments: {
              ...Map<String, dynamic>.from(aluno as Map),
              'turma_id': _turma!['id'],
              'turma': _turma!['nome']
            });
          },
        );
      },
    );
  }
}
