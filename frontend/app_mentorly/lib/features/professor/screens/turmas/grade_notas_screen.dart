import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../models/atividadeModel.dart';
import '../../models/insightsTurmaModel.dart';
import '../../services/insightsIaService.dart';
import '../../services/rascunho_notas_service.dart';

class GradeNotasScreen extends StatefulWidget {
  const GradeNotasScreen({super.key});
  @override
  State<GradeNotasScreen> createState() => _GradeNotasScreenState();
}

class _GradeNotasScreenState extends State<GradeNotasScreen> {
  Map<String, dynamic>? _turma, _dados;
  bool _iniciou = false, _carregando = true, _salvando = false;
  bool _gerandoIa = false;
  String? _erro;
  String? _erroIa;
  InsightsTurmaModel? _insights;
  int? _etapa;
  String _busca = '', _estado = '';
  bool _soPendentes = false;
  final _campos = <String, TextEditingController>{};
  final _originais = <String, String>{};
  final _form = GlobalKey<FormState>();
  final _horizontal = ScrollController();
  Timer? _timer;
  RascunhoNotasService? _rascunho;
  String _chave(dynamic aluno, dynamic atividade) => '$aluno:$atividade';
  bool _editavel(dynamic atividade) =>
      _dados?['somente_leitura'] != true &&
      !(_dados!['etapas'] as List)
          .any((e) => e['id'] == atividade['etapa_id'] && e['fechada'] == true);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciou) {
      _iniciou = true;
      _turma =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _rascunho = RascunhoNotasService('grade.${_turma?['id']}');
      _carregar();
    }
  }

  Future<void> _carregar() async {
    if (_turma?['id'] == null) {
      setState(() {
        _erro = 'Turma não informada.';
        _carregando = false;
      });
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    ApiService().invalidarCache();
    try {
      final d =
          await ApiService().get('/professor/turmas/${_turma!['id']}/grade');
      if (!mounted) return;
      for (final c in _campos.values) {
        c.dispose();
      }
      _campos.clear();
      _originais.clear();
      _dados = Map<String, dynamic>.from(d as Map);
      final etapas = _dados!['etapas'] as List;
      if (_etapa == null && etapas.isNotEmpty) {
        _etapa = etapas.first['id'] as int;
      }
      (_dados!['alunos'] as List)
          .sort((a, b) => a['nome'].toString().compareTo(b['nome'].toString()));
      for (final al in _dados!['alunos'] as List) {
        for (final a in al['atividades'] as List) {
          final chave = _chave(al['id'], a['id']);
          final texto = a['nota']?.toString() ?? '';
          _originais[chave] = texto;
          _campos[chave] = TextEditingController(text: texto);
        }
      }
      await _recuperar();
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar a grade.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Map<String, dynamic> _rascunhoDados() => {
        'campos': {
          for (final e in _campos.entries)
            if (e.value.text != _originais[e.key])
              e.key: {'texto': e.value.text, 'original': _originais[e.key]}
        }
      };
  Future<void> _guardar() async {
    try {
      await _rascunho?.gravar(_rascunhoDados());
      if (mounted) setState(() => _estado = 'Rascunho salvo neste dispositivo');
    } catch (_) {
      if (mounted) {
        setState(() =>
            _estado = 'Não foi possível guardar o rascunho neste dispositivo');
      }
    }
  }

  void _alterou() {
    _timer?.cancel();
    setState(() => _estado = 'Alterações ainda não publicadas');
    _timer = Timer(const Duration(milliseconds: 450), _guardar);
  }

  Future<void> _recuperar() async {
    Map<String, dynamic>? salvo;
    try {
      salvo = await _rascunho?.ler();
    } catch (_) {
      return;
    }
    if (!mounted ||
        salvo?['campos'] is! Map ||
        (salvo!['campos'] as Map).isEmpty) {
      return;
    }
    final sim = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Recuperar rascunho da grade?'),
                content: const Text(
                    'Campos alterados no servidor desde o rascunho serão preservados. Revise as notas recuperadas antes de salvar.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Descartar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Recuperar'))
                ]));
    if (!mounted) return;
    if (sim != true) {
      await _rascunho?.apagar();
      return;
    }
    var conflitos = 0;
    for (final e in (salvo['campos'] as Map).entries) {
      if (!_campos.containsKey(e.key) || e.value is! Map) continue;
      if (e.value['original'] != _originais[e.key]) {
        conflitos++;
        continue;
      }
      _campos[e.key]!.text = e.value['texto'].toString();
    }
    _estado = conflitos > 0
        ? '$conflitos campos mudaram no servidor e não foram recuperados.'
        : 'Rascunho recuperado. Revise e salve.';
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    _timer?.cancel();
    // Todos os campos, inclusive os ocultos por filtros, precisam ser válidos.
    for (final atividade in _dados!['atividades_cadastro'] as List) {
      for (final al in _dados!['alunos'] as List) {
        final chave = _chave(al['id'], atividade['id']);
        final texto = _campos[chave]?.text.trim() ?? '';
        if (texto == _originais[chave]) continue;
        final n = double.tryParse(texto.replaceAll(',', '.'));
        final maximo = (atividade['nota_maxima'] as num?)?.toDouble();
        if (n == null ||
            !n.isFinite ||
            n < 0 ||
            maximo == null ||
            n > maximo ||
            RegExp(r'[.,]\d{3,}').hasMatch(texto)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Revise a nota de ${al['nome']} em ${atividade['title']}. Remova os filtros para localizar o campo.')));
          return;
        }
      }
    }
    setState(() => _salvando = true);
    var salvas = 0;
    try {
      // Cada atividade usa a transacao e as guardas de notas ja existentes.
      for (final atividade in _dados!['atividades_cadastro'] as List) {
        final id = atividade['id'];
        final notas = <Map<String, dynamic>>[];
        for (final al in _dados!['alunos'] as List) {
          final chave = _chave(al['id'], id);
          final texto = _campos[chave]?.text;
          if (texto == null || texto == _originais[chave]) continue;
          final a = (al['atividades'] as List)
              .firstWhere((a) => a['id'].toString() == id.toString());
          notas.add({
            'aluno_id': al['id'],
            'valor': double.parse(texto.replaceAll(',', '.')),
            'observacao': a['observacao'],
            'situacao': ['Ausente', 'Não entregou', 'Não corrigido']
                    .contains(a['situacao'])
                ? a['situacao']
                : 'Nota',
          });
        }
        if (notas.isEmpty) continue;
        await ApiService().post('/atividades/$id/notas', {'notas': notas});
        for (final n in notas) {
          final chave = _chave(n['aluno_id'], id);
          _originais[chave] = _campos[chave]!.text;
        }
        salvas++;
        await _rascunho?.gravar(_rascunhoDados());
      }
      await _rascunho?.apagar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(salvas == 0
              ? 'Nenhuma nota alterada.'
              : 'Notas salvas em $salvas atividades.')));
      _estado = 'Notas salvas no servidor';
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$salvas atividades salvas. As alterações restantes foram mantidas. ${e is ApiException ? e.mensagem : 'Tente novamente.'}')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _relatorio() async {
    final api = ApiService();
    try {
      final filtro = _etapa == null ? '' : '?etapa_id=$_etapa';
      final uri = await api.autorizarDownload(
          '/professor/turmas/${_turma!['id']}/resumo-reuniao$filtro');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('download');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível abrir o resumo para impressão.')));
      }
    }
  }

  Future<void> _gerarInsights() async {
    if (_turma?['id'] == null || _gerandoIa) return;
    setState(() {
      _gerandoIa = true;
      _erroIa = null;
    });
    try {
      final turmaId = int.tryParse(_turma!['id'].toString());
      if (turmaId == null) throw StateError('Turma inválida');
      final resultado =
          await InsightsIaService().gerar(turmaId, etapaId: _etapa);
      if (mounted) setState(() => _insights = resultado);
    } catch (e) {
      if (mounted) {
        setState(() => _erroIa = e is ApiException
            ? e.mensagem
            : 'Não foi possível gerar as sugestões agora.');
      }
    } finally {
      if (mounted) setState(() => _gerandoIa = false);
    }
  }

  String _numero(num? valor) {
    if (valor == null) return '—';
    final n = valor.toDouble();
    return n == n.roundToDouble()
        ? n.toInt().toString()
        : n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  double? _notaDigitada(dynamic alunoId, dynamic atividadeId) {
    final texto = _campos[_chave(alunoId, atividadeId)]?.text.trim() ?? '';
    return texto.isEmpty ? null : double.tryParse(texto.replaceAll(',', '.'));
  }

  String _resumoCriterio(
      dynamic aluno, dynamic criterio, List<dynamic> atividades) {
    final doCriterio = atividades
        .where((a) => a['criterio_id'].toString() == criterio['id'].toString())
        .toList();
    final notas = doCriterio
        .map((a) => _notaDigitada(aluno['id'], a['id']))
        .whereType<double>()
        .toList();
    if (notas.isEmpty) return '—';
    return _numero(notas.fold<double>(0, (a, b) => a + b));
  }

  String _totalEtapa(dynamic aluno) {
    final atividades = (_dados!['atividades_cadastro'] as List)
        .where((a) => a['etapa_id'] == _etapa);
    final notas = atividades
        .map((a) => _notaDigitada(aluno['id'], a['id']))
        .whereType<double>()
        .toList();
    return notas.isEmpty
        ? '—'
        : _numero(notas.fold<double>(0, (soma, nota) => soma + nota));
  }

  Map<String, dynamic>? _acompanhamentoSelecionado(dynamic aluno) {
    final lista = aluno['acompanhamento_etapas'] as List? ?? const [];
    final encontrados =
        lista.where((e) => e['etapa_id'].toString() == _etapa.toString());
    return encontrados.isEmpty
        ? null
        : Map<String, dynamic>.from(encontrados.first as Map);
  }

  Widget _painelAtencao(List<dynamic> alunos) {
    final atencao = alunos.where((a) {
      final acompanhamento = _acompanhamentoSelecionado(a);
      return const ['Alto', 'Médio'].contains(acompanhamento?['risco']);
    }).toList();
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Atenção pedagógica',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(atencao.isEmpty
                              ? 'Nenhum alerta de nota nesta etapa.'
                              : '${atencao.length} aluno(s) precisam de conferência nesta etapa.')
                        ]),
                    FilledButton.icon(
                        onPressed: _gerandoIa ? null : _gerarInsights,
                        icon: _gerandoIa
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(_gerandoIa
                            ? 'Analisando…'
                            : 'Gerar sugestões com IA'))
                  ]),
              if (atencao.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...atencao.take(5).map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(() {
                      final acompanhamento = _acompanhamentoSelecionado(a);
                      final motivos = acompanhamento?['motivos'] as List?;
                      final motivo = motivos == null || motivos.isEmpty
                          ? 'desempenho que precisa de atenção'
                          : motivos.first.toString();
                      return '• ${a['nome']} · $motivo';
                    }())))
              ],
              if (_erroIa != null) ...[
                const SizedBox(height: 10),
                Text(_erroIa!, style: const TextStyle(color: Colors.red))
              ],
              if (_insights != null) ...[
                const Divider(height: 24),
                Text('Sugestões da IA · ${_insights!.etapa}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(_insights!.resumo),
                ..._insights!.pontosAtencao.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.titulo,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Evidência: ${p.evidencia}'),
                          Text('Sugestão: ${p.sugestao}')
                        ]))),
                ..._insights!.sugestoesGerais.map((s) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• $s'))),
                const SizedBox(height: 8),
                const Text(
                    'A IA apenas sugere ações. As notas e alertas oficiais são calculados pelo Mentorly e a decisão continua com o professor.',
                    style: TextStyle(fontSize: 12, color: Colors.black54))
              ]
            ])));
  }

  @override
  void dispose() {
    if (_timer?.isActive == true) {
      _timer!.cancel();
      _rascunho?.gravar(_rascunhoDados()).catchError((Object _) {});
    }
    for (final c in _campos.values) {
      c.dispose();
    }
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Grade de notas · ${_turma?['nome'] ?? ''}')),
      bottomNavigationBar: _dados == null
          ? null
          : SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            _estado.isEmpty
                                ? 'Revise os lançamentos antes de salvar.'
                                : _estado,
                            style: Theme.of(context).textTheme.bodySmall)),
                    const SizedBox(width: 12),
                    FilledButton(
                        onPressed: _salvando ||
                                _carregando ||
                                _dados?['somente_leitura'] == true
                            ? null
                            : _salvar,
                        child:
                            Text(_salvando ? 'Salvando…' : 'Salvar alterações'))
                  ]))),
      body: ConteudoPagina(
          vidro: false,
          largura: 1600,
          child: _carregando
              ? const CarregamentoPagina()
              : _erro != null
                  ? EstadoPagina(
                      titulo: 'Não foi possível abrir a grade',
                      mensagem: _erro!,
                      acao: 'Tentar novamente',
                      onPressed: _carregar)
                  : _grade()));
  Widget _grade() {
    final atividades = (_dados!['atividades_cadastro'] as List)
        .where((a) => _etapa == null || a['etapa_id'] == _etapa)
        .toList();
    final criterios = (_dados!['criterios'] as List? ?? const [])
        .where((c) => c['etapa_id'] == _etapa && ((c['peso'] as num?) ?? 0) > 0)
        .toList();
    final alunos = (_dados!['alunos'] as List)
        .where((a) =>
            a['nome'].toString().toLowerCase().contains(_busca.toLowerCase()) &&
            (!_soPendentes ||
                atividades.any((at) =>
                    _campos[_chave(a['id'], at['id'])]?.text.trim().isEmpty ==
                    true)))
        .toList();
    return Form(
        key: _form,
        child: ListView(children: [
          Text('Notas da turma',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (_dados?['somente_leitura'] == true)
            const Text(
                'Ano letivo encerrado. Esta grade está disponível somente para consulta.'),
          const Text(
              'Use Tab para avançar entre campos. Valores em branco continuam pendentes. Abra uma atividade para registrar ausência, falta de entrega ou excluir uma nota.'),
          const SizedBox(height: 20),
          Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                    width: 250,
                    child: TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Buscar aluno',
                            prefixIcon: Icon(Icons.search)),
                        onChanged: (v) => setState(() => _busca = v))),
                SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int>(
                        initialValue: _etapa,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Etapa'),
                        items: [
                          const DropdownMenuItem<int>(
                              value: null, child: Text('Todas as etapas')),
                          ...(_dados!['etapas'] as List).map((e) =>
                              DropdownMenuItem<int>(
                                  value: e['id'] as int,
                                  child: Text(e['nome'].toString())))
                        ],
                        onChanged: (v) => setState(() {
                              _etapa = v;
                              _insights = null;
                              _erroIa = null;
                            }))),
                FilterChip(
                    label: const Text('Somente com pendências'),
                    selected: _soPendentes,
                    onSelected: (v) => setState(() => _soPendentes = v)),
                OutlinedButton.icon(
                    onPressed: _relatorio,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Resumo para reunião')),
              ]),
          const SizedBox(height: 20),
          if (_etapa != null && criterios.isNotEmpty) ...[
            Text('Planejamento da etapa',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'Os limites são definidos pela Coordenação. Os pontos distribuídos vêm das atividades criadas pelo professor.'),
            const SizedBox(height: 10),
            Wrap(
                spacing: 12,
                runSpacing: 12,
                children: criterios.map((c) {
                  final distribuido = atividades
                      .where((a) => a['criterio_id'] == c['id'])
                      .fold<double>(
                          0,
                          (soma, a) =>
                              soma +
                              ((a['nota_maxima'] as num?)?.toDouble() ?? 0));
                  final limite = (c['nota_maxima'] as num?)?.toDouble() ?? 0;
                  final restante = limite - distribuido;
                  return SizedBox(
                      width: 230,
                      child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['nome'].toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text(
                                        '${_numero(distribuido)} de ${_numero(limite)} pts distribuídos'),
                                    Text(
                                        restante >= 0
                                            ? '${_numero(restante)} pts restantes'
                                            : '${_numero(-restante)} pts acima do limite',
                                        style: TextStyle(
                                            color: restante < 0
                                                ? Colors.red[700]
                                                : Colors.black54,
                                            fontSize: 12))
                                  ]))));
                }).toList()),
            const SizedBox(height: 20),
          ],
          _painelAtencao(alunos),
          const SizedBox(height: 20),
          const Text(
              'O boletim começa pelos totais de cada tipo e da etapa. Depois vêm as atividades individuais para lançamento. Deslize para os lados para consultar tudo.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          if (atividades.isEmpty && criterios.isEmpty)
            const Text(
                'A Coordenação ainda não configurou os tipos de pontuação desta etapa.')
          else if (alunos.isEmpty)
            const Text('Nenhum aluno corresponde aos filtros.')
          else
            Scrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                        headingRowColor:
                            const WidgetStatePropertyAll(Color(0xFFEAF0F8)),
                        headingRowHeight: 78,
                        dataRowMinHeight: 76,
                        dataRowMaxHeight: 96,
                        columnSpacing: 20,
                        columns: [
                          const DataColumn(label: Text('Aluno')),
                          ...criterios.map((c) => DataColumn(
                              label: SizedBox(
                                  width: 135,
                                  child: Text(c['nome'].toString(),
                                      maxLines: 2)))),
                          const DataColumn(
                              label: SizedBox(
                                  width: 120, child: Text('Total atual'))),
                          ...atividades.map((a) => DataColumn(
                              label: SizedBox(
                                  width: 150,
                                  child: TextButton(
                                      onPressed: () async {
                                        _timer?.cancel();
                                        await _guardar();
                                        if (!mounted) return;
                                        await Navigator.pushNamed(
                                            context, AppRoutes.atividadeNotas,
                                            arguments: {
                                              'atividade':
                                                  AtividadeModel.fromJson(
                                                      Map<String, dynamic>.from(
                                                          a as Map))
                                            });
                                        if (mounted) _carregar();
                                      },
                                      child: Text(
                                          '${a['title']}\nAté ${a['nota_maxima'] ?? '—'} pts',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis)))))
                        ],
                        rows: alunos
                            .map((al) => DataRow(cells: [
                                  DataCell(SizedBox(
                                      width: 180,
                                      child: Text(al['nome'].toString()))),
                                  ...criterios.map((c) => DataCell(SizedBox(
                                      width: 135,
                                      child: Text(
                                          _resumoCriterio(al, c, atividades),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600))))),
                                  DataCell(SizedBox(
                                      width: 120,
                                      child: Text(_totalEtapa(al),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)))),
                                  ...atividades.map((a) {
                                    final chave = _chave(al['id'], a['id']);
                                    final detalhes = (al['atividades'] as List)
                                        .firstWhere((x) =>
                                            x['id'].toString() ==
                                            a['id'].toString());
                                    return DataCell(SizedBox(
                                        width: 150,
                                        child: TextFormField(
                                            key: ValueKey(
                                                'grade-${al['id']}-${a['id']}'),
                                            controller: _campos[chave],
                                            enabled: !_salvando &&
                                                _editavel(a) &&
                                                a['nota_maxima'] != null,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: InputDecoration(
                                                isDense: true,
                                                hintText: '—',
                                                suffixText:
                                                    'de ${_numero(a['nota_maxima'] as num?)}',
                                                helperText: [
                                                  'Ausente',
                                                  'Não entregou',
                                                  'Não corrigido'
                                                ].contains(detalhes['situacao'])
                                                    ? detalhes['situacao']
                                                        .toString()
                                                    : null),
                                            onChanged: (_) => _alterou(),
                                            validator: (v) {
                                              if ((v ?? '').trim().isEmpty) {
                                                return _originais[chave]!
                                                        .isEmpty
                                                    ? null
                                                    : 'Exclua na atividade';
                                              }
                                              final n = double.tryParse(
                                                  v!.replaceAll(',', '.'));
                                              final maximo =
                                                  (a['nota_maxima'] as num?)
                                                      ?.toDouble();
                                              if (n == null ||
                                                  !n.isFinite ||
                                                  n < 0 ||
                                                  maximo == null ||
                                                  n > maximo) {
                                                return 'De 0 a ${maximo ?? '?'}';
                                              }
                                              return null;
                                            })));
                                  })
                                ]))
                            .toList()))),
          const SizedBox(height: 24),
        ]));
  }
}
