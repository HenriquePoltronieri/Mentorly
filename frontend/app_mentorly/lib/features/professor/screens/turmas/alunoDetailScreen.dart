import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../models/estatisticaAlunoModel.dart';
import '../../widgets/professorTopBar.dart';
import '../../widgets/alunoGraficoWidget.dart';
import '../../services/professorAlunoDetailService.dart';

// tela de detalhe/estatisticas de um aluno especifico
// recebe o aluno via Navigator.pushNamed(context, AppRoutes.alunoDetail, arguments: aluno)
// onde "aluno" é o Map que veio da turmaAlunosScreen (tem id, nome, matricula)
//
// endpoint -> GET {baseUrl}/api/professor/alunos/{alunoId}/estatisticas
// resposta: EstatisticaAlunoModel, calculada pelo Marco 2 (nota_calculada
// e situacao por etapa, ja ponderados pelos criterios da escola).
class AlunoDetailScreen extends StatefulWidget {
  const AlunoDetailScreen({super.key});

  @override
  State<AlunoDetailScreen> createState() => _AlunoDetailScreenState();
}

class _AlunoDetailScreenState extends State<AlunoDetailScreen> {
  final ProfessorAlunoDetailService _detailService = ProfessorAlunoDetailService();

  bool _carregando = true;
  String? _mensagemErro;
  EstatisticaAlunoModel? _estatistica;
  Map<String, dynamic>? _aluno;
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _aluno = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _jaBuscou = true;
      _buscarEstatisticas();
    }
  }

  Future<void> _buscarEstatisticas() async {
    if (_aluno == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Aluno não informado';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final dados = await _detailService.buscarEstatisticas(_aluno!['id'] as int);
      setState(() {
        _estatistica = EstatisticaAlunoModel.fromJson(dados);
      });
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar estatísticas: ${e.mensagem}');
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'turmas'),
      body: Column(
        children: [
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
                  _aluno?['nome'] ?? 'Aluno',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _buscarEstatisticas,
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

    final estatistica = _estatistica;
    if (estatistica == null) {
      return const Center(child: Text('Nenhuma estatística disponível'));
    }

    // So entram no grafico as etapas ja calculadas (completo=true) - uma
    // etapa em_andamento ou com configuracao invalida nao tem nota pra
    // desenhar, e inventar um valor ali contradiria a regra do Marco 2.
    final etapasCompletas =
        estatistica.etapas.where((e) => e.notaCalculada != null).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Matrícula: ${_aluno?['matricula'] ?? ''}'),
        if (estatistica.media != null) ...[
          const SizedBox(height: 4),
          Text(
            'Média geral (bruta, sem peso de critério): '
            '${estatistica.media!.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Desempenho por etapa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (estatistica.etapas.isEmpty)
          const Text('Nenhuma etapa configurada pela coordenação ainda.')
        else
          ...estatistica.etapas.map((etapa) => _CardEtapa(
                etapa: etapa,
                ehAtual: etapa.etapaId == estatistica.etapaAtualId,
              )),
        if (etapasCompletas.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Evolução da nota calculada por etapa',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          AlunoGraficoWidget(
            notas: etapasCompletas.map((e) => e.percentual ?? 0).toList(),
            notaMaxima: 100,
            rotulos: etapasCompletas.map((e) => e.etapa).toList(),
          ),
          const Text(
            '% da etapa (nota calculada já convertida para percentual)',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ],
    );
  }
}

class _CardEtapa extends StatelessWidget {
  final EtapaDesempenhoModel etapa;
  final bool ehAtual;

  const _CardEtapa({required this.etapa, required this.ehAtual});

  @override
  Widget build(BuildContext context) {
    final cor = etapa.emRisco
        ? Colors.red
        : etapa.situacao == 'adequado'
            ? Colors.green
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: ehAtual ? Border.all(color: cor.withOpacity(0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  etapa.etapa,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (ehAtual)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('atual', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _descricaoSituacao(),
            style: TextStyle(color: cor, fontWeight: FontWeight.w600),
          ),
          if (etapa.criterios.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...etapa.criterios.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.criterio, style: const TextStyle(fontSize: 13))),
                      Text(
                        !c.temAtividade
                            ? 'sem atividade'
                            : c.desempenhoPercentual == null
                                ? 'sem nota'
                                : '${c.desempenhoPercentual!.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _descricaoSituacao() {
    switch (etapa.situacao) {
      case 'adequado':
        return 'Nota: ${etapa.notaCalculada!.toStringAsFixed(1)} / '
            '${etapa.notaMaxima!.toStringAsFixed(0)} — adequado';
      case 'abaixo_do_minimo':
        return 'Nota: ${etapa.notaCalculada!.toStringAsFixed(1)} / '
            '${etapa.notaMaxima!.toStringAsFixed(0)} — abaixo do mínimo '
            '(${etapa.notaMinima!.toStringAsFixed(0)})';
      case 'configuracao_invalida':
        return etapa.mensagem ?? 'Configuração da etapa inválida';
      default:
        return 'Em andamento — ainda faltam notas para calcular';
    }
  }
}
