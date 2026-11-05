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
        setState(() => _erroIa = e is ApiException && e.statusCode < 500
            ? e.mensagem
            : 'Não foi possível gerar as sugestões agora. Tente novamente em instantes.');
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

  String _chaveCriterio(String nome) => nome.trim().toLowerCase();

  List<Map<String, dynamic>> _agruparCriterios(
      List<dynamic> criterios, List<dynamic> atividades) {
    final grupos = <String, Map<String, dynamic>>{};
    for (final criterio in criterios) {
      final nome = criterio['nome']?.toString() ?? 'Sem tipo';
      final chave = _chaveCriterio(nome);
      final grupo = grupos.putIfAbsent(
          chave,
          () => <String, dynamic>{
                'nome': nome,
                'ids': <String>{},
                'maximo': 0.0,
                'distribuido': 0.0,
              });
      (grupo['ids'] as Set<String>).add(criterio['id'].toString());
      grupo['maximo'] = (grupo['maximo'] as double) +
          ((criterio['nota_maxima'] as num?)?.toDouble() ?? 0);
    }
    for (final atividade in atividades) {
      final id = atividade['criterio_id']?.toString();
      final grupo = grupos.values
          .where((g) => id != null && (g['ids'] as Set<String>).contains(id));
      if (grupo.isNotEmpty) {
        grupo.first['distribuido'] = (grupo.first['distribuido'] as double) +
            ((atividade['nota_maxima'] as num?)?.toDouble() ?? 0);
      }
    }
    return grupos.values.toList();
  }

  String _resumoCriterio(
      dynamic aluno, Map<String, dynamic> criterio, List<dynamic> atividades) {
    final ids = criterio['ids'] as Set<String>;
    final doCriterio = atividades
        .where((a) => ids.contains(a['criterio_id'].toString()))
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
        .where((a) => _etapa == null || a['etapa_id'] == _etapa);
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
    if (_etapa == null) {
      if (lista.isEmpty) return null;
      const prioridade = {
        'Alto': 0,
        'Médio': 1,
        'Em andamento': 2,
        'Baixo': 3,
        'Sem dados': 4,
      };
      final ordenados = List<dynamic>.from(lista)
        ..sort((a, b) => (prioridade[a['risco']] ?? 5)
            .compareTo(prioridade[b['risco']] ?? 5));
      return Map<String, dynamic>.from(ordenados.first as Map);
    }
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
                Text(
                    '${_insights!.geradoPorIA ? 'Sugestões da IA' : 'Análise local'} · ${_insights!.etapa}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (_insights!.aviso != null) Text(_insights!.aviso!),
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

  String _nomeCriterio(dynamic atividade, List<dynamic> criterios) {
    final encontrados = criterios.where(
        (c) => c['id'].toString() == atividade['criterio_id'].toString());
    return encontrados.isEmpty
        ? (atividade['criterio_nome']?.toString() ?? 'Sem tipo')
        : encontrados.first['nome'].toString();
  }

  double _totalDistribuido(List<dynamic> atividades) => atividades.fold(
      0, (soma, a) => soma + ((a['nota_maxima'] as num?)?.toDouble() ?? 0));

  Future<void> _abrirAtividade(dynamic atividade) async {
    _timer?.cancel();
    await _guardar();
    if (!mounted) return;
    await Navigator.pushNamed(context, AppRoutes.atividadeNotas, arguments: {
      'atividade':
          AtividadeModel.fromJson(Map<String, dynamic>.from(atividade as Map))
    });
    if (mounted) _carregar();
  }

  Widget _campoNota(dynamic aluno, dynamic atividade) {
    final chave = _chave(aluno['id'], atividade['id']);
    final detalhes = (aluno['atividades'] as List)
        .firstWhere((x) => x['id'].toString() == atividade['id'].toString());
    return SizedBox(
        width: 145,
        child: TextFormField(
            key: ValueKey('grade-${aluno['id']}-${atividade['id']}'),
            controller: _campos[chave],
            enabled: !_salvando &&
                _editavel(atividade) &&
                atividade['nota_maxima'] != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
                isDense: true,
                labelText: 'Nota',
                hintText: '—',
                suffixText: 'de ${_numero(atividade['nota_maxima'] as num?)}',
                helperText: ['Ausente', 'Não entregou', 'Não corrigido']
                        .contains(detalhes['situacao'])
                    ? detalhes['situacao'].toString()
                    : null),
            onChanged: (_) => _alterou(),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) {
                return _originais[chave]!.isEmpty
                    ? null
                    : 'Exclua na atividade';
              }
              final n = double.tryParse(v!.replaceAll(',', '.'));
              final maximo = (atividade['nota_maxima'] as num?)?.toDouble();
              if (n == null ||
                  !n.isFinite ||
                  n < 0 ||
                  maximo == null ||
                  n > maximo) {
                return 'De 0 a ${maximo ?? '?'}';
              }
              return null;
            }));
  }

  Widget _boletimRapido(
      List<dynamic> alunos,
      List<Map<String, dynamic>> criterios,
      List<dynamic> atividades,
      double totalOficial,
      double minimoOficial) {
    final distribuido = _totalDistribuido(atividades);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_etapa == null ? 'Boletim geral' : 'Boletim rápido da etapa',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
          'Escala oficial: ${_numero(totalOficial)} pontos · mínimo para aprovação: ${_numero(minimoOficial)} pontos · ${_numero(distribuido)} pontos já distribuídos em atividades. O traço (—) significa que ainda não há nota lançada.'),
      const SizedBox(height: 10),
      DecoratedBox(
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCFD9E8)),
              borderRadius: BorderRadius.circular(14)),
          child: Scrollbar(
              controller: _horizontal,
              thumbVisibility: true,
              child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                      headingRowColor:
                          const WidgetStatePropertyAll(Color(0xFFEAF0F8)),
                      headingRowHeight: 72,
                      dataRowMinHeight: 68,
                      dataRowMaxHeight: 80,
                      columnSpacing: 26,
                      columns: [
                        const DataColumn(label: Text('Aluno')),
                        ...criterios.map((c) => DataColumn(
                            label: SizedBox(
                                width: 145,
                                child: Text(
                                    '${c['nome']}\nMáximo: ${_numero(c['maximo'] as num?)} pts')))),
                        DataColumn(
                            label: SizedBox(
                                width: 165,
                                child: Text(
                                    'Total do aluno\nEscala: ${_numero(totalOficial)} pts'))),
                        const DataColumn(label: Text('Acompanhamento')),
                      ],
                      rows: alunos.map((al) {
                        final acompanhamento = _acompanhamentoSelecionado(al);
                        final risco =
                            acompanhamento?['risco']?.toString() ?? 'Sem dados';
                        final cor = risco == 'Alto'
                            ? Colors.red
                            : risco == 'Médio'
                                ? Colors.orange
                                : risco == 'Baixo'
                                    ? Colors.green
                                    : Colors.blueGrey;
                        return DataRow(cells: [
                          DataCell(SizedBox(
                              width: 180, child: Text(al['nome'].toString()))),
                          ...criterios.map((c) {
                            final pontos = _resumoCriterio(al, c, atividades);
                            return DataCell(SizedBox(
                                width: 145,
                                child: Text(
                                    '$pontos de ${_numero(c['maximo'] as num?)} pts',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))));
                          }),
                          DataCell(SizedBox(
                              width: 165,
                              child: Text(
                                  '${_totalEtapa(al)} de ${_numero(totalOficial)} pts',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)))),
                          DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: cor.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(risco,
                                  style: TextStyle(
                                      color: cor,
                                      fontWeight: FontWeight.w600))))
                        ]);
                      }).toList()))))
    ]);
  }

  Widget _lancamentosPorAtividade(
      List<dynamic> alunos, List<dynamic> criterios, List<dynamic> atividades) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Lançamento por atividade',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text(
          'Cada bloco identifica claramente o tipo de pontuação, o nome da atividade e quanto ela vale.'),
      const SizedBox(height: 12),
      ...atividades.map((atividade) {
        final tipo = _nomeCriterio(atividade, criterios);
        return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFBFCDE0), width: 1.4)),
            clipBehavior: Clip.antiAlias,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: double.infinity,
                  color: const Color(0xFFEAF1FB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFB8C8DE)),
                            label: Text(tipo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                        Text(atividade['title'].toString(),
                            style: Theme.of(context).textTheme.titleMedium),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: const Color(0xFFDCE8FA),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                'Valor máximo: ${_numero(atividade['nota_maxima'] as num?)} pts',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        TextButton.icon(
                            onPressed: () => _abrirAtividade(atividade),
                            icon: const Icon(Icons.open_in_new, size: 17),
                            label: const Text('Abrir atividade'))
                      ])),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(builder: (context, limites) {
                    final largura = limites.maxWidth < 700
                        ? limites.maxWidth
                        : (limites.maxWidth - 14) / 2;
                    return Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        children: alunos.asMap().entries.map((item) {
                          final al = item.value;
                          return Container(
                              width: largura,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: item.key.isEven
                                      ? const Color(0xFFF8FAFD)
                                      : const Color(0xFFF3F7FC),
                                  border: Border.all(
                                      color: const Color(0xFFD5DFEC)),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                Expanded(
                                    child: Text(al['nome'].toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500))),
                                const SizedBox(width: 10),
                                _campoNota(al, atividade)
                              ]));
                        }).toList());
                  }))
            ]));
      })
    ]);
  }

  Widget _metricaEscala(
      {required IconData icone,
      required String rotulo,
      required String valor,
      String? detalhe,
      Color cor = const Color(0xFF214F9B)}) {
    return Container(
        width: 245,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: cor.withValues(alpha: .07),
            border: Border.all(color: cor.withValues(alpha: .24)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(rotulo,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF53657A))),
                const SizedBox(height: 3),
                Text(valor,
                    style: TextStyle(
                        color: cor, fontSize: 18, fontWeight: FontWeight.w700)),
                if (detalhe != null) ...[
                  const SizedBox(height: 2),
                  Text(detalhe,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF66778B)))
                ]
              ]))
        ]));
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
    final etapas = _dados!['etapas'] as List;
    final etapasConsideradas =
        etapas.where((e) => _etapa == null || e['id'] == _etapa).toList();
    final idsEtapas = etapasConsideradas.map((e) => e['id'].toString()).toSet();
    final criterios = (_dados!['criterios'] as List? ?? const [])
        .where((c) =>
            idsEtapas.contains(c['etapa_id'].toString()) &&
            ((c['peso'] as num?) ?? 0) > 0)
        .toList();
    final criteriosAgrupados = _agruparCriterios(criterios, atividades);
    final etapaEncontrada = etapas.where((e) => e['id'] == _etapa);
    final etapaSelecionada =
        etapaEncontrada.isEmpty ? null : etapaEncontrada.first;
    final totalOficial = etapasConsideradas.fold<double>(
        0, (soma, e) => soma + ((e['nota_maxima'] as num?)?.toDouble() ?? 0));
    final minimoOficial = etapasConsideradas.fold<double>(
        0, (soma, e) => soma + ((e['nota_minima'] as num?)?.toDouble() ?? 0));
    final totalDistribuido = _totalDistribuido(atividades);
    final faltaDistribuir = totalOficial - totalDistribuido;
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
        child: ListView(key: const ValueKey('grade-lista'), children: [
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
                        key: const ValueKey('busca-aluno'),
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
          Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFBFCDE0), width: 1.3)),
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            etapaSelecionada?['nome']?.toString() ??
                                'Todas as etapas',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        const Text(
                            'A escala e o mínimo vêm da configuração da Coordenação. As atividades mostram quanto dessa pontuação o professor já planejou.'),
                        const SizedBox(height: 14),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          _metricaEscala(
                              icone: Icons.flag_outlined,
                              rotulo: 'Total oficial',
                              valor: '${_numero(totalOficial)} pontos',
                              detalhe: _etapa == null
                                  ? 'Soma de todas as etapas'
                                  : 'Valor total desta etapa'),
                          _metricaEscala(
                              icone: Icons.verified_outlined,
                              rotulo: 'Mínimo para aprovação',
                              valor: '${_numero(minimoOficial)} pontos',
                              detalhe: _etapa == null
                                  ? 'Soma dos mínimos das etapas'
                                  : 'Mínimo desta etapa',
                              cor: const Color(0xFF21734A)),
                          _metricaEscala(
                              icone: Icons.edit_note_outlined,
                              rotulo: 'Já distribuído pelo professor',
                              valor: '${_numero(totalDistribuido)} pontos',
                              detalhe: 'Soma do valor máximo das atividades',
                              cor: const Color(0xFF7A4B00)),
                          _metricaEscala(
                              icone: faltaDistribuir >= 0
                                  ? Icons.pending_actions_outlined
                                  : Icons.warning_amber_outlined,
                              rotulo: faltaDistribuir >= 0
                                  ? 'Ainda falta distribuir'
                                  : 'Acima do total oficial',
                              valor: '${_numero(faltaDistribuir.abs())} pontos',
                              detalhe: faltaDistribuir >= 0
                                  ? 'Pontuação ainda sem atividade'
                                  : 'Revise o valor das atividades',
                              cor: faltaDistribuir >= 0
                                  ? const Color(0xFF5D6470)
                                  : const Color(0xFFB42318))
                        ])
                      ]))),
          const SizedBox(height: 20),
          if (criteriosAgrupados.isNotEmpty) ...[
            Text(
                _etapa == null
                    ? 'Distribuição por critério'
                    : 'Planejamento da etapa',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'Em cada critério, compare o limite definido pela Coordenação com os pontos que já foram transformados em atividades.'),
            const SizedBox(height: 10),
            Wrap(
                spacing: 12,
                runSpacing: 12,
                children: criteriosAgrupados.map((c) {
                  final distribuido = c['distribuido'] as double;
                  final limite = c['maximo'] as double;
                  final restante = limite - distribuido;
                  final progresso = limite <= 0
                      ? 0.0
                      : (distribuido / limite).clamp(0.0, 1.0).toDouble();
                  return SizedBox(
                      width: 260,
                      child: Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFCFD9E8))),
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['nome'].toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16)),
                                    const SizedBox(height: 10),
                                    Text(
                                        'Total permitido: ${_numero(limite)} pts'),
                                    Text(
                                        'Já distribuído: ${_numero(distribuido)} pts',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                        value: progresso,
                                        minHeight: 7,
                                        borderRadius: BorderRadius.circular(8),
                                        color: restante < 0
                                            ? Colors.red[700]
                                            : const Color(0xFF2C57D6),
                                        backgroundColor:
                                            const Color(0xFFE4EAF3)),
                                    const SizedBox(height: 7),
                                    Text(
                                        restante >= 0
                                            ? 'Restam ${_numero(restante)} pts para distribuir'
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
          if (atividades.isEmpty && criterios.isEmpty)
            const Text(
                'A Coordenação ainda não configurou os tipos de pontuação desta etapa.')
          else if (alunos.isEmpty)
            const Text('Nenhum aluno corresponde aos filtros.')
          else ...[
            _boletimRapido(alunos, criteriosAgrupados, atividades, totalOficial,
                minimoOficial),
            const SizedBox(height: 28),
            if (atividades.isEmpty)
              const Text(
                  'Nenhuma atividade cadastrada nesta etapa. Use Nova atividade para distribuir os pontos.')
            else
              _lancamentosPorAtividade(alunos, criterios, atividades),
          ],
          const SizedBox(height: 24),
        ]));
  }
}
