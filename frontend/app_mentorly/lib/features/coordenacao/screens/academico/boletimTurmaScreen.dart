import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../models/turmaModel.dart';
import '../../services/boletimService.dart';
import '../../services/etapasService.dart';

// Boletim da turma para a Coordenacao: mesma tabela que o Professor ve,
// mais o controle de fechar/reabrir etapa - acao exclusiva da Coordenacao
// (o backend recusa com 403 se um token de Professor tentar).
//
// recebe a turma via Navigator.pushNamed(..., arguments: TurmaModel)
// endpoint -> GET {baseUrl}/api/coordenacao/turmas/{turmaId}/boletim
class BoletimTurmaScreen extends StatefulWidget {
  const BoletimTurmaScreen({super.key});

  @override
  State<BoletimTurmaScreen> createState() => _BoletimTurmaScreenState();
}

class _BoletimTurmaScreenState extends State<BoletimTurmaScreen> {
  final BoletimService _service = BoletimService();
  final EtapasService _etapasService = EtapasService();

  bool _carregando = true;
  String? _mensagemErro;
  TurmaModel? _turma;
  List<dynamic> _alunos = [];
  List<dynamic> _etapasColunas = [];
  int? _alterandoEtapaId;
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _turma = ModalRoute.of(context)!.settings.arguments as TurmaModel?;
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
      final dados = await _service.buscarBoletim(int.parse(_turma!.id));
      final alunos = (dados['alunos'] as List?) ?? [];
      setState(() {
        _alunos = alunos;
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

  Future<void> _alternarFechamento(Map<String, dynamic> etapa) async {
    final etapaId = etapa['etapa_id'] as int;
    final estaFechada = etapa['fechada'] == true;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(estaFechada ? 'Reabrir etapa' : 'Fechar etapa'),
        content: Text(
          estaFechada
              ? 'Reabrir "${etapa['etapa']}"? O professor volta a poder '
                  'lançar notas e editar atividades dela.'
              : 'Fechar "${etapa['etapa']}"? O resultado fica congelado e o '
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
    if (confirmou != true) return;

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
        final incompletos = (resultado['alunosIncompletos'] as num?)?.toInt() ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              incompletos > 0
                  ? 'Etapa fechada. $incompletos aluno(s) da escola ainda '
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
      return etapa['situacao'] == 'configuracao_invalida' ? 'config.' : '—';
    }
    final nota = (etapa['nota_calculada'] as num).toDouble();
    return nota.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Boletim — ${_turma?.nome ?? ''}'),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarBoletim,
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
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Nenhum aluno cadastrado nessa turma ainda')),
        ],
      );
    }

    if (_etapasColunas.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Nenhuma etapa configurada para esta escola ainda')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Etapas',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fechar uma etapa congela o resultado e bloqueia novas notas nela.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        ..._etapasColunas.map((e) {
          final etapa = e as Map<String, dynamic>;
          final fechada = etapa['fechada'] == true;
          final alterando = _alterandoEtapaId == etapa['etapa_id'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                fechada ? Icons.lock_outline : Icons.lock_open_outlined,
                color: fechada ? Colors.grey[700] : Colors.green,
              ),
              title: Text('${etapa['etapa']}'),
              subtitle: Text(fechada ? 'Fechada' : 'Aberta'),
              trailing: alterando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton(
                      onPressed: () => _alternarFechamento(etapa),
                      child: Text(fechada ? 'Reabrir' : 'Fechar'),
                    ),
            ),
          );
        }),
        const SizedBox(height: 20),
        const Text(
          'Boletim',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Aluno')),
              ...(_etapasColunas.map((e) {
                final etapa = e as Map<String, dynamic>;
                return DataColumn(label: Text('${etapa['etapa']}'));
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
          ),
        ),
      ],
    );
  }
}
