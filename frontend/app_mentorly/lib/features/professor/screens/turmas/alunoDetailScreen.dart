import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../models/estatisticaAlunoModel.dart';
import '../../widgets/professorTopBar.dart';
import '../../widgets/alunoGraficoWidget.dart';
import '../../services/professorAlunoDetailService.dart';
import 'feedbackIaDialog.dart';

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

  // Marco 9D: so leitura. O dialogo gera uma SUGESTAO sobre o resultado que o
  // motor ja calculou para esta etapa; nada e salvo e nada muda aqui.
  void _abrirFeedbackIa(EtapaDesempenhoModel etapa) {
    final aluno = _aluno;
    if (aluno == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => FeedbackIaDialog(
        alunoId: aluno['id'] as int,
        etapa: etapa,
        alunoNome: aluno['nome']?.toString() ?? '',
      ),
    );
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
        _CardConsolidado(consolidado: estatistica.consolidado),
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
                aoGerarFeedback: () => _abrirFeedbackIa(etapa),
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
  final VoidCallback aoGerarFeedback;

  const _CardEtapa({
    required this.etapa,
    required this.ehAtual,
    required this.aoGerarFeedback,
  });

  // Sem atividade avaliada (ou com a etapa mal configurada) nao ha o que
  // interpretar: o botao fica desabilitado em vez de gerar um erro.
  bool get _podeGerarFeedback =>
      etapa.atividadesAvaliadas > 0 && etapa.situacao != 'configuracao_invalida';

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
              if (etapa.fechada)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 12),
                      SizedBox(width: 4),
                      Text('fechada', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              if (ehAtual)
                Container(
                  margin: const EdgeInsets.only(left: 6),
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
          if (etapa.totalAtividades > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${etapa.atividadesAvaliadas} avaliada(s) · '
              '${etapa.atividadesSemNota} sem nota',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
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
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: _podeGerarFeedback
                  ? ''
                  : 'Disponível quando houver ao menos uma atividade avaliada nesta etapa',
              child: TextButton.icon(
                onPressed: _podeGerarFeedback ? aoGerarFeedback : null,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Gerar feedback com IA'),
              ),
            ),
          ),
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

// Consolidado geral: media das etapas ja FECHADAS (ver ConsolidadoModel).
// Sem etapa fechada ainda, mostra "em andamento" em vez de inventar nota.
class _CardConsolidado extends StatelessWidget {
  final ConsolidadoModel consolidado;

  const _CardConsolidado({required this.consolidado});

  @override
  Widget build(BuildContext context) {
    final emAndamento = consolidado.situacao == 'em_andamento';
    final cor = emAndamento
        ? Colors.grey
        : consolidado.situacao == 'adequado'
            ? Colors.green
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consolidado geral',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  emAndamento
                      ? (consolidado.mensagem ??
                          'Em andamento — nenhuma etapa fechada ainda')
                      : '${consolidado.percentual!.toStringAsFixed(0)}% — '
                          '${consolidado.situacao == 'adequado' ? 'adequado' : 'abaixo do mínimo'} '
                          '(${consolidado.etapasConsideradas} etapa(s) fechada(s))',
                  style: TextStyle(color: cor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
