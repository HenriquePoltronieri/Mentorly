import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../../coordenacao/services/etapasService.dart';
import '../../models/atividadeModel.dart';
import '../../models/sugestaoAtividadeModel.dart';
import '../../services/atividadesService.dart';
import 'gerarAtividadeIaDialog.dart';

class AdicionarAtividadeModal extends StatefulWidget {
  final List<TurmaModel> turmas;
  final AtividadeModel? atividade;
  final AtividadeModel? modelo;
  const AdicionarAtividadeModal(
      {super.key, required this.turmas, this.atividade, this.modelo});
  @override
  State<AdicionarAtividadeModal> createState() =>
      _AdicionarAtividadeModalState();
}

class _AdicionarAtividadeModalState extends State<AdicionarAtividadeModal> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo, _descricao, _valor, _data;
  TurmaModel? _turma;
  List<Map<String, dynamic>> _etapas = [];
  int? _etapa;
  bool _carregando = false, _salvando = false;
  String? _erro;
  int _versaoCarga = 0;
  @override
  void initState() {
    super.initState();
    final base = widget.atividade ?? widget.modelo;
    _titulo = TextEditingController(text: base?.nome ?? '');
    _descricao = TextEditingController(text: base?.descricao ?? '');
    _valor = TextEditingController(text: base?.notaMaxima?.toString() ?? '');
    _data = TextEditingController(
        text: (widget.atividade?.dataEntrega ?? '')
            .split('T')
            .first
            .split(' ')
            .first);
    if (widget.turmas.isNotEmpty) {
      _turma = widget.turmas.firstWhere(
          (t) => t.id == widget.atividade?.turmaId,
          orElse: () => widget.turmas.first);
    }
    _carregar();
  }

  Future<void> _carregar() async {
    final versao = ++_versaoCarga;
    setState(() {
      _carregando = true;
      _etapa = null;
      _erro = null;
      _etapas = [];
    });
    try {
      final lista =
          await EtapasService().listarEtapas(anoLetivo: _turma?.anoLetivo);
      if (!mounted || versao != _versaoCarga) return;
      _etapas = lista
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['fechada'] != true && e['ativa'] != false)
          .toList();
      _etapas.sort((a, b) =>
          ((b['ordem'] ?? 0) as num).compareTo((a['ordem'] ?? 0) as num));
      final hoje = DateTime.now();
      final atuais = _etapas.where((e) {
        final inicio = DateTime.tryParse(e['data_inicio']?.toString() ?? '');
        final fim = DateTime.tryParse(e['data_fim']?.toString() ?? '');
        return inicio != null &&
            fim != null &&
            !hoje.isBefore(inicio) &&
            hoje.isBefore(fim.add(const Duration(days: 1)));
      }).toList();
      final base = widget.atividade ?? widget.modelo;
      _etapa = _etapas.any((e) => e['id'] == base?.etapaId)
          ? base!.etapaId
          : atuais.isNotEmpty
              ? atuais.first['id'] as int
              : _etapas.isNotEmpty
                  ? _etapas.first['id'] as int
                  : null;
      _padrao();
    } catch (e) {
      if (mounted && versao == _versaoCarga) {
        _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar as etapas.';
      }
    } finally {
      if (mounted && versao == _versaoCarga) {
        setState(() => _carregando = false);
      }
    }
  }

  void _padrao() {
    if (_valor.text.isEmpty && _etapa != null) {
      _valor.text = _etapas
              .firstWhere((e) => e['id'] == _etapa)['nota_maxima']
              ?.toString() ??
          '';
    }
  }

  Future<void> _gerar() async {
    if (_turma == null) return;
    final sugestao = await showDialog<SugestaoAtividadeModel>(
        context: context,
        builder: (_) =>
            GerarAtividadeIaDialog(turmaId: _turma!.id, etapaId: _etapa));
    if (sugestao != null && mounted) {
      _titulo.text = sugestao.titulo;
      _descricao.text = sugestao.descricaoFormatada();
    }
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final servico = AtividadesService();
      final valor = double.parse(_valor.text.replaceAll(',', '.'));
      final atividade = widget.atividade == null
          ? await servico.cadastrarAtividade(
              turmaId: _turma!.id,
              nome: _titulo.text.trim(),
              etapaId: _etapa!,
              criterioId: _etapa == widget.modelo?.etapaId
                  ? widget.modelo?.criterioId
                  : null,
              notaMaxima: valor,
              descricao: _descricao.text.trim(),
              dataEntrega: _data.text)
          : await servico.atualizarAtividade(
              id: widget.atividade!.id,
              turmaId: _turma!.id,
              nome: _titulo.text.trim(),
              etapaId: _etapa!,
              criterioId: _etapa == widget.atividade!.etapaId
                  ? widget.atividade!.criterioId
                  : null,
              notaMaxima: valor,
              descricao: _descricao.text.trim(),
              dataEntrega: _data.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atividade salva com sucesso!')));
      final lancar = widget.atividade == null &&
          await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                          title: const Text('Lançar notas agora?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Depois')),
                            FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Lançar notas'))
                          ])) ==
              true;
      if (!mounted) return;
      if (lancar) {
        await Navigator.pushNamed(context, AppRoutes.atividadeNotas,
            arguments: {'atividade': atividade, 'turma': _turma});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível salvar. Seus dados foram mantidos.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _valor.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.atividade == null
              ? widget.modelo == null
                  ? 'Nova atividade'
                  : 'Reaproveitar atividade'
              : 'Editar atividade')),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: _salvando || _carregando ? null : _salvar,
                  child: Text(_salvando ? 'Salvando…' : 'Salvar atividade')))),
      body: ConteudoPagina(
          largura: 720,
          child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (widget.modelo != null) ...[
                  const Text(
                      'Revise a turma, a etapa, o valor e a nova data de entrega. As notas da atividade original não serão copiadas.'),
                  const SizedBox(height: 20),
                ],
                DropdownButtonFormField<TurmaModel>(
                    initialValue: _turma,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Turma'),
                    items: widget.turmas
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t.nome)))
                        .toList(),
                    validator: (v) => v == null ? 'Escolha a turma.' : null,
                    onChanged: _salvando
                        ? null
                        : (v) {
                            setState(() {
                              _turma = v;
                              if (widget.atividade == null &&
                                  widget.modelo == null) {
                                _valor.clear();
                              }
                            });
                            _carregar();
                          }),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _titulo,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Informe o título.' : null),
                const SizedBox(height: 16),
                if (_carregando)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<int>(
                      key: ValueKey(_etapa),
                      initialValue: _etapa,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Etapa'),
                      items: _etapas
                          .map((e) => DropdownMenuItem(
                              value: e['id'] as int,
                              child: Text(e['nome'].toString())))
                          .toList(),
                      validator: (v) => v == null
                          ? 'Escolha uma etapa aberta configurada pela escola.'
                          : null,
                      onChanged: (v) => setState(() {
                            _etapa = v;
                            if (widget.atividade == null &&
                                widget.modelo == null) {
                              _valor.clear();
                            }
                            _padrao();
                          })),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _valor,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Valor / nota máxima'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return n == null || !n.isFinite || n <= 0 || n > 999.99
                          ? 'Informe um valor entre 0,01 e 999,99.'
                          : null;
                    }),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _data,
                    readOnly: true,
                    decoration: const InputDecoration(
                        labelText: 'Data de entrega',
                        suffixIcon: Icon(Icons.calendar_month)),
                    validator: (v) => DateTime.tryParse(v ?? '') == null
                        ? 'Escolha a data de entrega.'
                        : null,
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(_data.text) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (d != null) {
                        _data.text = d.toIso8601String().split('T').first;
                      }
                    }),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _descricao,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)')),
                const SizedBox(height: 12),
                TextButton.icon(
                    onPressed: _salvando ? null : _gerar,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Sugerir texto com IA')),
                if (_erro != null) ...[
                  Text(_erro!, style: const TextStyle(color: Colors.red)),
                  TextButton(
                      onPressed: _carregar,
                      child: const Text('Tentar novamente'))
                ],
              ]))));
}
