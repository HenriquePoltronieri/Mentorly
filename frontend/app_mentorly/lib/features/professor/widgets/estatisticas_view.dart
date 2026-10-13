import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/apiService.dart';
import '../../../core/widgets/estrutura_pagina.dart';
import '../../../core/widgets/identidade_visual.dart';

Color corRisco(String risco) => switch (risco) {
      'Alto' => Colors.red.shade700,
      'Médio' => Colors.orange.shade800,
      'Em andamento' => AppCores.professorAzul,
      'Sem dados' => Colors.grey,
      _ => AppCores.professorVerde
    };
String formatarMetrica(dynamic v) =>
    v is num ? v.toStringAsFixed(1).replaceAll('.', ',') : '—';
String pontosAvaliados(Map aluno) => aluno['pontos_obtidos'] == null
    ? 'Sem notas lançadas'
    : '${formatarMetrica(aluno['pontos_obtidos'])}/${formatarMetrica(aluno['pontos_avaliados'])} pts avaliados';

class EstatisticasView extends StatefulWidget {
  final int turmaId;
  final int? alunoId;
  const EstatisticasView({super.key, required this.turmaId, this.alunoId});
  @override
  State<EstatisticasView> createState() => _EstatisticasViewState();
}

class _EstatisticasViewState extends State<EstatisticasView> {
  Map<String, dynamic>? _dados;
  int? _etapa;
  bool _carregando = true;
  String? _erro;
  int _versao = 0;
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final versao = ++_versao;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final aluno = widget.alunoId == null ? '' : '/alunos/${widget.alunoId}';
      final filtro = _etapa == null ? '' : '?etapa_id=$_etapa';
      final dados = await ApiService()
          .get('/professor/turmas/${widget.turmaId}$aluno/estatisticas$filtro');
      if (mounted && versao == _versao) {
        setState(() => _dados = Map<String, dynamic>.from(dados as Map));
      }
    } catch (e) {
      if (mounted && versao == _versao) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar as estatísticas.');
      }
    } finally {
      if (mounted && versao == _versao) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const CarregamentoPagina();
    if (_erro != null) {
      return EstadoPagina(
          titulo: 'Estatísticas indisponíveis',
          mensagem: _erro!,
          acao: 'Tentar novamente',
          onPressed: _carregar);
    }
    final d = _dados!;
    final aluno = widget.alunoId != null;
    final atividades = (d['atividades'] as List).cast<Map<String, dynamic>>();
    return RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (aluno) ...[
            Text(d['nome'].toString(),
                style: Theme.of(context).textTheme.headlineSmall),
            Text('${d['turma']} · ${d['risco']} · ${pontosAvaliados(d)}',
                style: TextStyle(color: corRisco(d['risco'].toString()))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.chatIa, arguments: {
                      'id': widget.turmaId,
                      'nome': d['turma'],
                      'aluno_id': widget.alunoId,
                      'aluno_nome': d['nome'],
                    }),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Como ajudar este aluno?')),
            const SizedBox(height: 16)
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
                label: const Text('Todas'),
                selected: _etapa == null,
                onSelected: (_) {
                  _etapa = null;
                  _carregar();
                }),
            ...(d['etapas'] as List).map((e) => ChoiceChip(
                label: Text(e['nome'].toString()),
                selected: _etapa == e['id'],
                onSelected: (_) {
                  _etapa = e['id'] as int;
                  _carregar();
                })),
          ]),
          const SizedBox(height: 16),
          const Text(
              'Os gráficos comparam atividades na escala de 0 a 10; essa escala não é a nota final. O desempenho geral considera os pontos de cada avaliação. Alertas de nota só aparecem no período final da etapa ou após o fechamento, considerando os pesos dos critérios. Sem nota, confirme o lançamento e a entrega.'),
          if (aluno)
            ...((d['acompanhamento_etapas'] as List?) ?? []).map((e) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: VidroCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e['etapa']} · ${e['risco']}',
                              style: TextStyle(
                                  color: corRisco(e['risco'].toString()))),
                          Text(pontosAvaliados(e as Map)),
                          if (e['fase'] == 'final' &&
                              e['pontos_ponderados'] != null) ...[
                            Text(
                                'Pontos com os pesos dos critérios: ${formatarMetrica(e['pontos_ponderados'])} · Mínimo: ${formatarMetrica(e['nota_minima'])}'),
                            Text(
                                'Ainda possíveis nas avaliações pendentes: ${formatarMetrica(e['pontos_restantes'])} pontos'),
                            const Text(
                                'Projeção das atividades cadastradas; novas avaliações podem mudar o resultado.'),
                          ],
                          ...((e['motivos'] as List?) ?? [])
                              .map((m) => Text(m.toString())),
                        ])))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _resumo('Desempenho (0–10)', formatarMetrica(d['media'])),
            if (aluno) ...[
              _resumo('Maior nota (0–10)', formatarMetrica(d['maior_nota'])),
              _resumo('Menor nota (0–10)', formatarMetrica(d['menor_nota'])),
              _resumo('Entregues / pendentes',
                  '${d['entregues']} / ${d['pendentes']}')
            ] else ...[
              _resumo('Entregas registradas',
                  '${formatarMetrica(d['percentual_entregas'])}%'),
              _resumo('Alunos em risco', '${d['alunos_em_risco']}'),
              _resumo('Pior desempenho',
                  d['pior_atividade']?['titulo']?.toString() ?? 'Sem notas')
            ],
          ]),
          const SizedBox(height: 24),
          VidroCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        aluno
                            ? 'Evolução por atividade'
                            : 'Média da turma por atividade',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 20),
                    _linha(atividades, aluno),
                    if (aluno)
                      const Text('Verde: aluno · Azul: média da turma'),
                  ])),
          if (!aluno) ...[
            const SizedBox(height: 20),
            VidroCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('Distribuição por risco',
                      style: Theme.of(context).textTheme.titleMedium),
                  if ((d['alunos'] as List).isEmpty)
                    const Text('Nenhum aluno cadastrado ainda.')
                  else
                    SizedBox(
                        height: 180,
                        child: PieChart(PieChartData(
                            centerSpaceRadius: 36,
                            sectionsSpace: 4,
                            sections: [
                              'Alto',
                              'Médio',
                              'Em andamento',
                              'Baixo',
                              'Sem dados'
                            ]
                                .where((r) =>
                                    ((d['distribuicao_risco'][r] as num?) ??
                                        0) >
                                    0)
                                .map((r) => PieChartSectionData(
                                    value: (d['distribuicao_risco'][r] as num)
                                        .toDouble(),
                                    color: corRisco(r),
                                    radius: 50,
                                    title: '$r\n${d['distribuicao_risco'][r]}',
                                    titleStyle: const TextStyle(
                                        color: Colors.white, fontSize: 12)))
                                .toList()))),
                  Wrap(
                      spacing: 12,
                      children: [
                        'Alto',
                        'Médio',
                        'Em andamento',
                        'Baixo',
                        'Sem dados'
                      ]
                          .map((r) => Text(
                              '$r: ${d['distribuicao_risco'][r] ?? 0}',
                              style: TextStyle(color: corRisco(r))))
                          .toList()),
                ])),
            const SizedBox(height: 24),
            Text('Alunos por risco',
                style: Theme.of(context).textTheme.titleLarge),
            ...(d['alunos'] as List).map((a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.circle,
                    size: 12, color: corRisco(a['risco'].toString())),
                title: Text(a['nome'].toString()),
                subtitle: Text('${a['risco']} · ${pontosAvaliados(a as Map)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.pushNamed(context, AppRoutes.alunoDetail,
                      arguments: {
                        ...Map<String, dynamic>.from(a),
                        'turma_id': widget.turmaId
                      });
                  if (mounted) _carregar();
                })),
          ] else ...[
            const SizedBox(height: 24),
            Text('Atividades', style: Theme.of(context).textTheme.titleLarge),
            if (atividades.isEmpty)
              const Text('Ainda não há atividades nesta etapa.'),
            ...atividades.map((a) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a['titulo'].toString()),
                subtitle: Text(
                    '${a['status']} · ${a['data'].toString().split(' ').first.split('T').first}'),
                trailing: Text(a['nota'] == null
                    ? '—'
                    : '${formatarMetrica(a['nota'])}/${formatarMetrica(a['nota_maxima'])}'))),
          ],
        ]));
  }

  Widget _resumo(String titulo, String valor) => SizedBox(
      width: 220,
      child: VidroCard(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo),
            Text(valor,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 20))
          ])));
  Widget _linha(List<Map<String, dynamic>> atividades, bool aluno) {
    List<FlSpot> pontos(String campo) => [
          for (var i = 0; i < atividades.length; i++)
            if (atividades[i][campo] is num)
              FlSpot(i.toDouble(), (atividades[i][campo] as num).toDouble())
        ];
    final principal = pontos(aluno ? 'nota_normalizada' : 'media');
    if (principal.isEmpty) {
      return const SizedBox(
          height: 160,
          child: Center(
              child: Text(
                  'Ainda não há notas. Os gráficos aparecerão após os lançamentos.')));
    }
    return SizedBox(
        height: 220,
        child: LineChart(LineChartData(
            minY: 0,
            maxY: 10,
            minX: 0,
            maxX:
                atividades.length > 1 ? (atividades.length - 1).toDouble() : 1,
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: .6), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true, reservedSize: 28, interval: 2)),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, meta) => Text(
                            v >= 0 && v < atividades.length
                                ? '${v.toInt() + 1}'
                                : '',
                            style: const TextStyle(fontSize: 11))))),
            lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                            '${atividades[s.x.toInt()]['titulo']}\n${s.barIndex == 1 ? "Turma" : aluno ? "Aluno" : "Turma"}: ${s.y.toStringAsFixed(1)}',
                            const TextStyle(color: Colors.white)))
                        .toList())),
            lineBarsData: [
              LineChartBarData(
                  spots: principal,
                  color: AppCores.professorVerde,
                  barWidth: 3,
                  isCurved: false),
              if (aluno)
                LineChartBarData(
                    spots: pontos('media_turma'),
                    color: AppCores.professorAzul,
                    barWidth: 2,
                    dashArray: [6, 4])
            ])));
  }
}
