import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/rascunho_notas_service.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../../core/widgets/identidade_visual.dart';
import '../../models/atividadeModel.dart';
import '../../models/notaModel.dart';
import '../../widgets/professorTopBar.dart';
import 'corrigirRespostaIaDialog.dart';
import 'lancarNotasModal.dart';

class AtividadeNotasScreen extends StatefulWidget {
  const AtividadeNotasScreen({super.key});
  @override
  State<AtividadeNotasScreen> createState() => _AtividadeNotasScreenState();
}

class _AtividadeNotasScreenState extends State<AtividadeNotasScreen> {
  final _form = GlobalKey<FormState>();
  final _campos = <int, TextEditingController>{};
  final _focos = <int, FocusNode>{};
  final _situacoes = <int, String>{};
  List<NotaModel> _notas = [];
  AtividadeModel? _atividade;
  bool _iniciou = false, _carregando = true, _salvando = false;
  String? _erro;
  RascunhoNotasService? _rascunho;
  Timer? _debounce;
  String _estadoRascunho = '';
  final _originais = <int, String>{};
  bool _preenchendo = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciou) {
      _iniciou = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _atividade = args?['atividade'] as AtividadeModel?;
      if (_atividade != null) {
        _rascunho = RascunhoNotasService('atividade.${_atividade!.id}');
      }
      _carregar();
    }
  }

  Future<void> _carregar({bool preservarRascunho = true}) async {
    if (preservarRascunho && _notas.isNotEmpty && !_carregando) {
      _debounce?.cancel();
      await _guardar();
      if (!mounted) return;
    }
    if (_atividade == null) {
      setState(() {
        _carregando = false;
        _erro = 'Atividade não informada.';
      });
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados =
          await ApiService().get('/atividades/${_atividade!.id}/notas');
      if (!mounted) return;
      final notas = (dados['notas'] as List)
          .map((n) => NotaModel.fromJson(Map<String, dynamic>.from(n as Map)))
          .toList();
      _preenchendo = true;
      for (final n in notas) {
        final campo = _campos.putIfAbsent(
            n.alunoId, () => TextEditingController()..addListener(_alterou));
        campo.text = n.valor?.toString() ?? '';
        _focos.putIfAbsent(n.alunoId, () => FocusNode());
        _situacoes[n.alunoId] = n.situacao ??
            (['Ausente', 'Não entregou'].contains(n.observacao)
                ? n.observacao!
                : 'Nota');
        _originais[n.alunoId] = '${campo.text}|${_situacoes[n.alunoId]}';
      }
      _preenchendo = false;
      setState(() => _notas = notas);
      await _restaurar();
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar as notas.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _alterou() {
    if (_preenchendo || _carregando || _salvando) return;
    _debounce?.cancel();
    setState(() => _estadoRascunho = 'Alterações ainda não publicadas');
    _debounce = Timer(const Duration(milliseconds: 450), _guardar);
  }

  Map<String, dynamic> _dadosRascunho() => {
        'campos': {
          for (final n in _notas)
            '${n.alunoId}': {
              'texto': _campos[n.alunoId]!.text,
              'situacao': _situacoes[n.alunoId],
              'original': _originais[n.alunoId]
            }
        }
      };
  Future<void> _guardar() async {
    try {
      await _rascunho?.gravar(_dadosRascunho());
      if (mounted) {
        setState(() => _estadoRascunho = 'Rascunho salvo neste dispositivo');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _estadoRascunho =
            'Não foi possível guardar o rascunho neste dispositivo');
      }
    }
  }

  Future<void> _restaurar() async {
    Map<String, dynamic>? salvo;
    try {
      salvo = await _rascunho?.ler();
    } catch (_) {
      return;
    }
    if (!mounted || salvo?['campos'] is! Map) return;
    final campos = Map<String, dynamic>.from(salvo!['campos'] as Map);
    if (!campos.entries.any((e) =>
        e.value is Map &&
        '${e.value['texto']}|${e.value['situacao']}' != e.value['original'])) {
      return;
    }
    final restaurar = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Continuar rascunho?'),
                content: const Text(
                    'Há lançamentos guardados neste dispositivo. Serão recuperados apenas os campos cuja nota oficial não mudou desde o rascunho.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Descartar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Recuperar'))
                ]));
    if (!mounted) return;
    if (restaurar != true) {
      await _rascunho?.apagar();
      return;
    }
    _preenchendo = true;
    var conflitos = 0;
    for (final n in _notas) {
      final d = campos['${n.alunoId}'];
      if (d is! Map || '${d['texto']}|${d['situacao']}' == d['original']) {
        continue;
      }
      if (d['original'] != _originais[n.alunoId]) {
        conflitos++;
        continue;
      }
      if (!['Nota', 'Ausente', 'Não entregou', 'Não corrigido']
          .contains(d['situacao'])) {
        continue;
      }
      _campos[n.alunoId]!.text = d['texto'].toString();
      _situacoes[n.alunoId] = d['situacao'].toString();
    }
    _preenchendo = false;
    setState(() => _estadoRascunho = conflitos == 0
        ? 'Rascunho recuperado. Revise e salve as notas.'
        : '$conflitos campos mudaram no servidor e não foram recuperados.');
  }

  String? _validar(String? v) {
    if ((v ?? '').trim().isEmpty) return null;
    final n = double.tryParse(v!.replaceAll(',', '.'));
    if (RegExp(r'[.,]\d{3,}').hasMatch(v)) {
      return 'Use até 2 casas decimais';
    }
    return n == null ||
            !n.isFinite ||
            n < 0 ||
            n > (_atividade?.notaMaxima ?? 0)
        ? 'De 0 a ${_atividade?.notaMaxima ?? "?"}'
        : null;
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    if (_notas.any(
        (n) => n.valor != null && _campos[n.alunoId]!.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Para retirar uma nota já salva, use Excluir nota no aluno.')));
      return;
    }
    _debounce?.cancel();
    setState(() => _salvando = true);
    try {
      final lancamentos = _notas
          .where((n) =>
              '${_campos[n.alunoId]!.text}|${_situacoes[n.alunoId]}' !=
              _originais[n.alunoId])
          .map((n) => {
                'aluno_id': n.alunoId,
                'valor': double.tryParse(
                    _campos[n.alunoId]!.text.replaceAll(',', '.')),
                'situacao': _situacoes[n.alunoId],
                'observacao': _situacoes[n.alunoId] == 'Nota'
                    ? n.observacao == 'Ausente' ||
                            n.observacao == 'Não entregou'
                        ? null
                        : n.observacao
                    : _situacoes[n.alunoId],
              })
          .toList();
      await ApiService()
          .post('/atividades/${_atividade!.id}/notas', {'notas': lancamentos});
      _debounce?.cancel();
      await _rascunho?.apagar();
      _estadoRascunho = 'Notas salvas no servidor';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notas salvas! Estatísticas atualizadas.')));
      await _carregar(preservarRascunho: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível salvar. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _mesmaNota() async {
    final campo = TextEditingController();
    final chave = GlobalKey<FormState>();
    final valor = await showDialog<double>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Aplicar a mesma nota para todos'),
                content: Form(
                    key: chave,
                    child: TextFormField(
                        controller: campo,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Nota'),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Informe a nota.'
                            : _validar(v))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () {
                        if (chave.currentState!.validate()) {
                          Navigator.pop(
                              c, double.parse(campo.text.replaceAll(',', '.')));
                        }
                      },
                      child: const Text('Aplicar'))
                ]));
    if (valor != null && mounted) {
      setState(() {
        for (final n in _notas) {
          _campos[n.alunoId]!.text = valor.toString();
          _situacoes[n.alunoId] = 'Nota';
        }
      });
    }
  }

  Future<void> _corrigir(NotaModel nota) async {
    if (_atividade?.notaMaxima == null) return;
    final valor = await showDialog<double>(
        context: context,
        builder: (_) => CorrigirRespostaIaDialog(
            atividadeId: _atividade!.id,
            valorMaximoAtividade: _atividade!.notaMaxima!,
            alunoNome: nota.alunoNome));
    if (valor != null && mounted) {
      setState(() {
        _campos[nota.alunoId]!.text = valor.toString();
        _situacoes[nota.alunoId] = 'Nota';
      });
    }
  }

  Future<void> _excluir(NotaModel nota) async {
    final confirmar = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Excluir nota?'),
                content: Text('Excluir a nota de ${nota.alunoNome}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Excluir'))
                ]));
    if (confirmar != true || !mounted) return;
    setState(() => _salvando = true);
    try {
      await ApiService().delete('/professor/notas/${nota.id}');
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível excluir a nota.')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    if (_debounce?.isActive == true) {
      _debounce!.cancel();
      _rascunho?.gravar(_dadosRascunho()).catchError((Object _) {});
    }
    for (final c in _campos.values) {
      c.dispose();
    }
    for (final f in _focos.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'atividades'),
      bottomNavigationBar: _notas.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${_notas.where((n) => _campos[n.alunoId]!.text.trim().isNotEmpty).length}/${_notas.length} preenchidas')),
                    FilledButton(
                        onPressed: _salvando || _carregando ? null : _salvar,
                        child: Text(_salvando ? 'Salvando…' : 'Salvar tudo')),
                  ]))),
      body: ConteudoPagina(
          vidro: false,
          child: _carregando
              ? const CarregamentoPagina()
              : _erro != null
                  ? EstadoPagina(
                      titulo: 'Não foi possível abrir as notas',
                      mensagem: _erro!,
                      acao: 'Tentar novamente',
                      onPressed: _carregar)
                  : Form(
                      key: _form,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(_atividade?.nome ?? '',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                'Valor máximo: ${_atividade?.notaMaxima ?? "não definido"}'),
                            const SizedBox(height: 8),
                            const Text(
                                'Ausente e Não entregou registram a situação. O valor só entra no cálculo quando você informa uma nota. Para atribuir zero, digite 0. Para retirar uma nota salva, use Excluir nota.'),
                            if (_estadoRascunho.isNotEmpty)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(_estadoRascunho,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall)),
                            Wrap(spacing: 12, children: [
                              TextButton.icon(
                                  onPressed: _salvando ? null : _mesmaNota,
                                  icon: const Icon(Icons.copy_all),
                                  label: const Text(
                                      'Aplicar a mesma nota para todos')),
                              TextButton.icon(
                                  onPressed: _salvando
                                      ? null
                                      : () async {
                                          final salvou = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => LancarNotasModal(
                                                  atividadeId: _atividade!.id));
                                          if (salvou == true && mounted) {
                                            _carregar();
                                          }
                                        },
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Importar notas'))
                            ]),
                            if (_notas.isEmpty)
                              const Text(
                                  'A Coordenação ainda não cadastrou alunos nesta turma.'),
                            ...List.generate(_notas.length, (i) {
                              final n = _notas[i];
                              return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: VidroCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(children: [
                                        Row(children: [
                                          Expanded(child: Text(n.alunoNome)),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                              width: 110,
                                              child: TextFormField(
                                                  controller:
                                                      _campos[n.alunoId],
                                                  focusNode: _focos[n.alunoId],
                                                  enabled: !_salvando,
                                                  validator: _validar,
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true),
                                                  textInputAction: i ==
                                                          _notas.length - 1
                                                      ? TextInputAction.done
                                                      : TextInputAction.next,
                                                  onFieldSubmitted: (_) {
                                                    if (i + 1 < _notas.length) {
                                                      _focos[_notas[i + 1]
                                                              .alunoId]!
                                                          .requestFocus();
                                                    }
                                                  },
                                                  onChanged: (_) =>
                                                      setState(() {}),
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText: 'Nota',
                                                          isDense: true))),
                                        ]),
                                        Wrap(
                                            spacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              DropdownButton<String>(
                                                  value: _situacoes[n.alunoId],
                                                  items: [
                                                    'Nota',
                                                    'Ausente',
                                                    'Não entregou',
                                                    'Não corrigido'
                                                  ]
                                                      .map((v) =>
                                                          DropdownMenuItem(
                                                              value: v,
                                                              child: Text(v)))
                                                      .toList(),
                                                  onChanged: _salvando
                                                      ? null
                                                      : (v) => setState(() {
                                                            _situacoes[
                                                                n.alunoId] = v!;
                                                            _alterou();
                                                          })),
                                              IconButton(
                                                  tooltip:
                                                      'Corrigir resposta com IA',
                                                  onPressed: _salvando
                                                      ? null
                                                      : () => _corrigir(n),
                                                  icon: const Icon(Icons
                                                      .auto_awesome_outlined)),
                                              if (n.id != null)
                                                IconButton(
                                                    tooltip: 'Excluir nota',
                                                    onPressed: _salvando
                                                        ? null
                                                        : () => _excluir(n),
                                                    icon: const Icon(
                                                        Icons.delete_outline)),
                                            ])
                                      ])));
                            }),
                          ]))));
}
