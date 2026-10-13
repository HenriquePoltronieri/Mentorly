import 'package:flutter/material.dart';
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
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciou) {
      _iniciou = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _atividade = args?['atividade'] as AtividadeModel?;
      _carregar();
    }
  }

  Future<void> _carregar() async {
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
      for (final n in notas) {
        final campo =
            _campos.putIfAbsent(n.alunoId, () => TextEditingController());
        campo.text = n.valor?.toString() ?? '';
        _focos.putIfAbsent(n.alunoId, () => FocusNode());
        _situacoes[n.alunoId] =
            ['Ausente', 'Não entregou'].contains(n.observacao)
                ? n.observacao!
                : 'Nota';
      }
      setState(() => _notas = notas);
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

  String? _validar(String? v) {
    if ((v ?? '').trim().isEmpty) return null;
    final n = double.tryParse(v!.replaceAll(',', '.'));
    return n == null ||
            !n.isFinite ||
            n < 0 ||
            n > (_atividade?.notaMaxima ?? 0)
        ? 'De 0 a ${_atividade?.notaMaxima ?? "?"}'
        : null;
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final lancamentos = _notas
          .where((n) => _campos[n.alunoId]!.text.trim().isNotEmpty)
          .map((n) => {
                'aluno_id': n.alunoId,
                'valor':
                    double.parse(_campos[n.alunoId]!.text.replaceAll(',', '.')),
                'observacao': _situacoes[n.alunoId] == 'Nota'
                    ? null
                    : _situacoes[n.alunoId],
              })
          .toList();
      await ApiService()
          .post('/atividades/${_atividade!.id}/notas', {'notas': lancamentos});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notas salvas! Estatísticas atualizadas.')));
      await _carregar();
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
                            '${_notas.where((n) => _campos[n.alunoId]!.text.trim().isNotEmpty).length}/${_notas.length} lançadas')),
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
                                                  enabled: !_salvando &&
                                                      _situacoes[n.alunoId] ==
                                                          'Nota',
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
                                                    'Não entregou'
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
                                                            _campos[n.alunoId]!
                                                                    .text =
                                                                v == 'Nota'
                                                                    ? ''
                                                                    : '0';
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
