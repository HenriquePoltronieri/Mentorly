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
String formatarPontos(dynamic v) => v is num
    ? v
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll('.', ',')
    : '—';
String notaAtividade(Map atividade) => atividade['nota'] == null
    ? 'Sem nota lançada'
    : '${formatarPontos(atividade['nota'])} de ${formatarPontos(atividade['nota_maxima'])}';
String pontosAvaliados(Map aluno) => aluno['pontos_obtidos'] == null
    ? 'Sem notas lançadas'
    : '${formatarPontos(aluno['pontos_obtidos'])} pontos obtidos em ${formatarPontos(aluno['pontos_avaliados'])} avaliados';
String tipoAtividade(Map atividade) =>
    atividade['criterio_nome']?.toString() ?? 'Sem tipo definido';

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
    final avaliadas = atividades.where((a) => a['nota'] is num).toList()
      ..sort((a, b) => (a['nota'] as num).compareTo(b['nota'] as num));
    final pontos =
        avaliadas.fold<num>(0, (soma, a) => soma + (a['nota'] as num));
    final maximo = avaliadas.fold<num>(
        0, (soma, a) => soma + ((a['nota_maxima'] as num?) ?? 0));
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
              'Leia primeiro o resumo da etapa. Depois compare cada atividade pelo nome, pelo tipo de pontuação e pela porcentagem alcançada. Atividades com valores diferentes nunca são comparadas apenas pelos pontos brutos.'),
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
                                  fontWeight: FontWeight.w600,
                                  color: corRisco(e['risco'].toString()))),
                          const SizedBox(height: 10),
                          Wrap(spacing: 24, runSpacing: 10, children: [
                            _dadoEtapa(
                                'Total atual do aluno',
                                e['pontos_ponderados'] == null
                                    ? 'Ainda sem nota'
                                    : '${formatarPontos(e['pontos_ponderados'])} pts'),
                            _dadoEtapa(
                                'Pontos já avaliados', pontosAvaliados(e as Map)),
                            _dadoEtapa(
                                'Mínimo para aprovação',
                                e['nota_minima'] == null
                                    ? 'Não configurado'
                                    : '${formatarPontos(e['nota_minima'])} de ${formatarPontos(e['nota_maxima'])} pts'),
                            if (e['fechada'] != true)
                              _dadoEtapa(
                                  'Ainda disponíveis',
                                  '${formatarPontos(e['pontos_restantes'])} pts'),
                            if ((e['pontos_nao_planejados'] as num? ?? 0) > 0)
                              _dadoEtapa(
                                  'Professor ainda precisa distribuir',
                                  '${formatarPontos(e['pontos_nao_planejados'])} pts')
                          ]),
                          if (e['pontos_obtidos'] != null &&
                              e['pontos_ponderados'] != null) ...[
                            const SizedBox(height: 10),
                            Text((e['pontos_faltantes'] as num?) == 0
                                ? 'O aluno já alcançou o mínimo com os lançamentos atuais.'
                                : 'Pelos lançamentos atuais, faltam ${formatarPontos(e['pontos_faltantes'])} pontos para o mínimo.'),
                          ],
                          const SizedBox(height: 8),
                          ...((e['motivos'] as List?) ?? [])
                              .map((m) => Text(m.toString())),
                        ])))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (aluno) ...[
              _resumo(
                  'Desempenho no que já foi avaliado',
                  maximo <= 0
                      ? 'Sem notas'
                      : '${(pontos / maximo * 100).toStringAsFixed(0)}%'),
              _resumo('Atividades avaliadas', '${avaliadas.length}'),
              _resumo('Entregues', '${d['entregues']}'),
              _resumo('Pendentes', '${d['pendentes']}')
            ] else ...[
              _resumo(
                  'Desempenho nas atividades',
                  d['media'] is num
                      ? '${formatarMetrica((d['media'] as num) * 10)}%'
                      : '—'),
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
                            ? 'Aluno x turma, atividade por atividade'
                            : 'Média da turma por atividade',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    const Text(
                        'A comparação usa porcentagem, então uma atividade de 2 pontos e outra de 10 ficam na mesma escala de 0% a 100%.'),
                    const SizedBox(height: 16),
                    _linha(atividades, aluno),
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
                    '${tipoAtividade(a)} · ${a['status']} · ${a['data'].toString().split(' ').first.split('T').first}'),
                trailing: Text(a['nota'] == null ? '—' : notaAtividade(a)))),
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
  static Widget _dadoEtapa(String rotulo, String valor) => SizedBox(
      width: 210,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))
      ]));
  Widget _linha(List<Map<String, dynamic>> atividades, bool aluno) {
    num? mediaPontos(Map<String, dynamic> a) {
      final campo = aluno ? 'media_turma_pontos' : 'media_pontos';
      if (a[campo] is num) return a[campo] as num;
      final media = a[aluno ? 'media_turma' : 'media'];
      return media is num && a['nota_maxima'] is num
          ? media * (a['nota_maxima'] as num) / 10
          : null;
    }

    List<FlSpot> pontos(String campo) => [
          for (var i = 0; i < atividades.length; i++)
            if (atividades[i][campo] is num)
              FlSpot(i.toDouble(), (atividades[i][campo] as num).toDouble())
        ];
    final turma = [
      for (var i = 0; i < atividades.length; i++)
        if (mediaPontos(atividades[i]) != null)
          FlSpot(i.toDouble(), mediaPontos(atividades[i])!.toDouble())
    ];
    final principal = aluno ? pontos('nota') : turma;
    if (principal.isEmpty) {
      return const SizedBox(
          height: 160,
          child: Center(
              child: Text(
                  'Ainda não há notas. Os gráficos aparecerão após os lançamentos.')));
    }
    final maximo = atividades.fold<double>(1, (maior, a) {
      final valor = (a['nota_maxima'] as num?)?.toDouble() ?? 0;
      return valor > maior ? valor : maior;
    });
    final intervalo = maximo / 5;
    return SizedBox(
        height: 220,
        child: LineChart(LineChartData(
            minY: 0,
            maxY: maximo,
            minX: 0,
            maxX:
                atividades.length > 1 ? (atividades.length - 1).toDouble() : 1,
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: intervalo,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: .6), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: intervalo)),
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
                            '${atividades[s.x.toInt()]['titulo']}\n${s.barIndex == 1 ? "Turma" : aluno ? "Aluno" : "Turma"}: ${formatarPontos(s.y)} de ${formatarPontos(atividades[s.x.toInt()]['nota_maxima'])}',
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
                    spots: turma,
                    color: AppCores.professorAzul,
                    barWidth: 2,
                    dashArray: [6, 4])
            ])));
  }
}
