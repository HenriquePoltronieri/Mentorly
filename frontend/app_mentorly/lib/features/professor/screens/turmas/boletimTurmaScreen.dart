import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../widgets/professorTopBar.dart';
import '../../services/boletimTurmaService.dart';

// Boletim da turma: todos os alunos, com a nota calculada de cada etapa e o
// consolidado geral (so etapas fechadas). Reaproveita o mesmo dado que a
// tela de detalhe do aluno usa, so que para a turma inteira de uma vez.
//
// recebe a turma via Navigator.pushNamed(context, AppRoutes.boletimTurma, arguments: turma)
// endpoint -> GET {baseUrl}/api/professor/turmas/{turmaId}/boletim
class BoletimTurmaScreen extends StatefulWidget {
  const BoletimTurmaScreen({super.key});

  @override
  State<BoletimTurmaScreen> createState() => _BoletimTurmaScreenState();
}

class _BoletimTurmaScreenState extends State<BoletimTurmaScreen> {
  final BoletimTurmaService _service = BoletimTurmaService();

  bool _carregando = true;
  String? _mensagemErro;
  Map<String, dynamic>? _turma;
  List<dynamic> _alunos = [];
  List<dynamic> _etapasColunas = [];
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _turma = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _jaBuscou = true;
      _buscarBoletim();
    }
  }

  Future<void> _buscarBoletim() async {
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
      final dados = await _service.buscarBoletim(_turma!['id'] as int);
      final alunos = (dados['alunos'] as List?) ?? [];
      setState(() {
        _alunos = alunos;
        // As etapas sao configuracao da escola: todo aluno da mesma turma
        // tem a mesma lista, na mesma ordem. Usa a do primeiro so pra
        // montar as colunas da tabela.
        _etapasColunas = alunos.isNotEmpty
            ? ((alunos.first['etapas'] as List?) ?? [])
            : [];
      });
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar boletim: ${e.mensagem}');
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Color _corSituacao(String? situacao) {
    switch (situacao) {
      case 'adequado':
        return Colors.green;
      case 'abaixo_do_minimo':
        return Colors.red;
      case 'configuracao_invalida':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _rotuloCelula(Map<String, dynamic> etapa) {
    if (etapa['nota_calculada'] == null) {
      return etapa['situacao'] == 'configuracao_invalida' ? 'config.' : '—';
    }
    final nota = (etapa['nota_calculada'] as num).toDouble();
    return nota.toStringAsFixed(1);
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
                    'Boletim — ${_turma!['nome'] ?? ''}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _buscarBoletim,
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
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhum aluno cadastrado nessa turma ainda')),
        ],
      );
    }

    if (_etapasColunas.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('A coordenação ainda não configurou etapas')),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Aluno')),
          ...(_etapasColunas.map((e) {
            final etapa = e as Map<String, dynamic>;
            return DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${etapa['etapa']}'),
                  if (etapa['fechada'] == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline, size: 12),
                  ],
                ],
              ),
            );
          })),
          const DataColumn(label: Text('Consolidado')),
        ],
        rows: _alunos.map((a) {
          final aluno = a as Map<String, dynamic>;
          final etapas = (aluno['etapas'] as List?) ?? [];
          final consolidado = (aluno['consolidado'] as Map?) ?? {};

          return DataRow(cells: [
            DataCell(Text(aluno['aluno'] ?? '')),
            ...etapas.map((e) {
              final etapa = e as Map<String, dynamic>;
              return DataCell(
                Text(
                  _rotuloCelula(etapa),
                  style: TextStyle(
                    color: _corSituacao(etapa['situacao'] as String?),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
            DataCell(
              Text(
                consolidado['situacao'] == 'em_andamento' || consolidado['percentual'] == null
                    ? 'em andamento'
                    : '${(consolidado['percentual'] as num).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _corSituacao(consolidado['situacao'] as String?),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}
