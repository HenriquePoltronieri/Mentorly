import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';

class AcompanhamentosScreen extends StatefulWidget {
  const AcompanhamentosScreen({super.key});
  @override
  State<AcompanhamentosScreen> createState() => _AcompanhamentosScreenState();
}

class _AcompanhamentosScreenState extends State<AcompanhamentosScreen> {
  Map<String, dynamic>? _aluno;
  List<dynamic> _registros = [];
  bool _iniciou = false, _carregando = true, _salvando = false;
  String? _erro;
  final _descricao = TextEditingController();
  DateTime? _retorno;
  final _form = GlobalKey<FormState>();
  String get _endpoint =>
      '/professor/turmas/${_aluno!['turma_id']}/alunos/${_aluno!['id']}/acompanhamentos';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciou) {
      _iniciou = true;
      _aluno =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _carregar();
    }
  }

  Future<void> _carregar() async {
    if (_aluno?['turma_id'] == null || _aluno?['id'] == null) {
      setState(() {
        _erro = 'Aluno e turma não informados.';
        _carregando = false;
      });
      return;
    }
    try {
      final dados = await ApiService().get(_endpoint);
      if (mounted) {
        setState(() {
          _registros = dados as List;
          _erro = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar os acompanhamentos.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate() || _salvando) return;
    setState(() => _salvando = true);
    try {
      await ApiService().post(_endpoint, {
        'descricao': _descricao.text.trim(),
        'retorno_em': _retorno!.toIso8601String().split('T').first
      });
      if (!mounted) return;
      _descricao.clear();
      setState(() => _retorno = null);
      _form.currentState!.reset();
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível salvar. Seu texto foi mantido.')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _concluir(dynamic r, bool valor) async {
    setState(() => _salvando = true);
    try {
      await ApiService()
          .put('/professor/acompanhamentos/${r['id']}', {'concluido': valor});
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível atualizar.')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Acompanhamento pedagógico')),
      body: ConteudoPagina(
          largura: 800,
          child: _carregando
              ? const CarregamentoPagina()
              : _erro != null
                  ? EstadoPagina(
                      titulo: 'Não foi possível abrir',
                      mensagem: _erro!,
                      acao: 'Tentar novamente',
                      onPressed: _carregar)
                  : Form(
                      key: _form,
                      child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(_aluno?['nome']?.toString() ?? 'Aluno',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            const Text(
                                'Registre a ação combinada e uma data para avaliar o resultado. Estes registros ficam no seu acompanhamento e no seu resumo para reunião.'),
                            const SizedBox(height: 24),
                            TextFormField(
                                controller: _descricao,
                                maxLines: 4,
                                maxLength: 3000,
                                enabled: !_salvando,
                                decoration: const InputDecoration(
                                    labelText: 'Intervenção / observação',
                                    hintText:
                                        'O que será feito e o que observar no retorno?'),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? 'Descreva a intervenção.'
                                    : null),
                            const SizedBox(height: 16),
                            FormField<DateTime>(
                                validator: (_) => _retorno == null
                                    ? 'Escolha uma data de retorno.'
                                    : null,
                                builder: (campo) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          OutlinedButton.icon(
                                              icon: const Icon(
                                                  Icons.event_outlined),
                                              label: Text(_retorno == null
                                                  ? 'Agendar retorno'
                                                  : 'Retorno: ${_data(_retorno!.toIso8601String())}'),
                                              onPressed: _salvando
                                                  ? null
                                                  : () async {
                                                      final d = await showDatePicker(
                                                          context: context,
                                                          initialDate: _retorno ??
                                                              DateTime.now().add(
                                                                  const Duration(
                                                                      days: 7)),
                                                          firstDate:
                                                              DateTime(2000),
                                                          lastDate:
                                                              DateTime(2100));
                                                      if (d != null &&
                                                          mounted) {
                                                        setState(
                                                            () => _retorno = d);
                                                        campo.didChange(d);
                                                      }
                                                    }),
                                          if (campo.hasError)
                                            Text(campo.errorText!,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error)),
                                        ])),
                            const SizedBox(height: 16),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                    onPressed: _salvando ? null : _salvar,
                                    icon: const Icon(Icons.add),
                                    label: Text(_salvando
                                        ? 'Salvando…'
                                        : 'Registrar acompanhamento'))),
                            const SizedBox(height: 32),
                            Text('Histórico de intervenções',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            if (_registros.isEmpty)
                              const Text(
                                  'Você ainda não registrou intervenções para este aluno.'),
                            ..._registros.map((r) => Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              'Retorno: ${_data(r['retorno_em'])} · ${r['concluido'] == true ? 'Concluído' : 'Em acompanhamento'}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 8),
                                          Text(r['descricao'].toString()),
                                          CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text(
                                                  'Retorno realizado'),
                                              value: r['concluido'] == true,
                                              onChanged: _salvando
                                                  ? null
                                                  : (v) => _concluir(r, v!)),
                                        ])))),
                          ]))));
  String _data(dynamic valor) {
    final d = DateTime.tryParse(valor.toString());
    return d == null
        ? valor.toString()
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
