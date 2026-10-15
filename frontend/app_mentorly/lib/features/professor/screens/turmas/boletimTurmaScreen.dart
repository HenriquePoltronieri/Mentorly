import '../../../coordenacao/services/etapasService.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
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
  final _etapasService = EtapasService();
  int? _alterandoEtapaId;

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
      _turma =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
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
      final respostas = await Future.wait([
        _service.buscarBoletim(_turma!['id'] as int),
        _etapasService.listarEtapas(
            anoLetivo: ((_turma!['anoLetivo'] ?? _turma!['ano_letivo']) as num?)
                ?.toInt(),
            atualizar: true),
      ]);
      if (!mounted) return;
      final dados = respostas[0] as Map<String, dynamic>;
      final alunos = (dados['alunos'] as List?) ?? [];
      setState(() {
        _alunos = alunos;
        // Etapas independem da lista de alunos, inclusive em turma vazia.
        _etapasColunas = (respostas[1] as List)
            .map((e) => {
                  'etapa_id': e['id'],
                  'etapa': e['nome'],
                  'fechada': e['fechada'],
                })
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Erro ao buscar boletim: ${e.mensagem}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _alternarFechamento(Map<String, dynamic> etapa) async {
    if (_alterandoEtapaId != null) return;
    // A trava comeca antes do dialogo, impedindo varias confirmacoes abertas.
    _alterandoEtapaId = etapa['etapa_id'] as int;
    final etapaId = etapa['etapa_id'] as int;
    final estaFechada = etapa['fechada'] == true;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(estaFechada ? 'Reabrir etapa' : 'Fechar etapa'),
        content: Text(
          estaFechada
              ? 'Esta etapa pertence ao ano inteiro da escola. Reabrir "${etapa['etapa']}"? O professor volta a poder '
                  'lançar notas e editar atividades dela.'
              : 'Esta etapa pertence ao ano inteiro da escola. Fechar "${etapa['etapa']}"? O resultado fica congelado e o '
                  'professor deixa de poder lançar notas ou editar '
                  'atividades dela até você reabrir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: Text(estaFechada ? 'Reabrir' : 'Fechar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmou != true) {
      setState(() => _alterandoEtapaId = null);
      return;
    }

    setState(() => _alterandoEtapaId = etapaId);
    try {
      if (estaFechada) {
        await _etapasService.reabrirEtapa(etapaId);
      } else {
        // A resposta do fechamento informa quantos alunos da escola ainda
        // tem atividade sem nota nesta etapa - o fechamento acontece do
        // mesmo jeito (nao e bloqueado), isso e so um aviso pra
        // Coordenacao decidir com informacao (Marco 4).
        final resultado = await _etapasService.fecharEtapa(etapaId);
        final incompletos =
            (resultado['alunosIncompletos'] as num?)?.toInt() ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              incompletos > 0
                  ? 'Etapa fechada. $incompletos aluno(s) das suas turmas ainda '
                      'têm atividade sem nota nesta etapa.'
                  : 'Etapa fechada. Nenhum aluno ficou com atividade sem '
                      'nota nesta etapa.',
            ),
            duration: const Duration(seconds: 5),
          ));
        }
      }
      await _buscarBoletim();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensagem)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor')),
      );
    } finally {
      if (mounted) setState(() => _alterandoEtapaId = null);
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
      if (etapa['nota_parcial'] is num) {
        return '${(etapa['nota_parcial'] as num).toStringAsFixed(1)} parcial';
      }
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
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.3),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                      child: Text(
                    'Boletim — ${_turma!['nome'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  )),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _buscarBoletim,
              child: ConteudoPagina(child: _construirCorpo()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCorpo() {
    if (_carregando) {
      return const CarregamentoPagina();
    }

    if (_mensagemErro != null) {
      return EstadoPagina(
          titulo: 'Falha ao carregar o boletim',
          mensagem: _mensagemErro!,
          acao: 'Tentar novamente',
          onPressed: _buscarBoletim);
    }

    if (_alunos.isEmpty && _etapasColunas.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(
              child: Text('Nenhum aluno cadastrado nessa turma ainda')),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Fechamento de etapas',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const Text(
            'O fechamento vale para todas as turmas deste ano da escola.'),
        ..._etapasColunas.map((item) {
          final etapa = item as Map<String, dynamic>;
          final fechada = etapa['fechada'] == true;
          return ListTile(
            title: Text('${etapa["etapa"]}'),
            subtitle: Text(fechada ? 'Fechada' : 'Aberta'),
            trailing: OutlinedButton(
              onPressed: _alterandoEtapaId != null
                  ? null
                  : () => _alternarFechamento(etapa),
              child: Text(fechada ? 'Reabrir' : 'Fechar'),
            ),
          );
        }),
        SingleChildScrollView(
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
                      consolidado['situacao'] == 'em_andamento' ||
                              consolidado['percentual'] == null
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
            )),
      ],
    );
  }
}
