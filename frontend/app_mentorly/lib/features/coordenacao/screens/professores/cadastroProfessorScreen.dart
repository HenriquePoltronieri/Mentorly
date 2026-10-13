import 'package:flutter/material.dart';
import '../../../../core/widgets/barra_mentorly.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../../core/widgets/convite_dialog.dart';
import '../../../../core/services/apiService.dart';
import '../../services/professoresService.dart';
import '../../../../core/utils/mensagensConvite.dart';

class CadastroProfessorScreen extends StatefulWidget {
  const CadastroProfessorScreen({super.key});
  @override
  State<CadastroProfessorScreen> createState() =>
      _CadastroProfessorScreenState();
}

class _CadastroProfessorScreenState extends State<CadastroProfessorScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController(), _email = TextEditingController();
  final _selecionadas = <int>{};
  List<dynamic> _turmas = [];
  bool _salvando = false;
  String? _erro, _erroTurmas;
  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  Future<void> _carregarTurmas() async {
    try {
      final turmas = await ApiService().get('/classes');
      if (mounted) {
        setState(() {
          _turmas = turmas as List;
          _erroTurmas = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erroTurmas = 'Não foi possível carregar as turmas.');
      }
    }
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final resultado = await ProfessoresService().cadastrarProfessor(
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          turmaIds: _selecionadas.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(MensagensConvite.cadastro(resultado))));
      if (resultado['conviteEnviado'] != true &&
          resultado['conviteLink'] != null) {
        await mostrarConvite(context, resultado);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível cadastrar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const BarraMentorly(
          professor: false, aba: 'professores', titulo: 'Novo professor'),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: Text(_salvando
                      ? 'Cadastrando…'
                      : 'Cadastrar e enviar convite')))),
      body: ConteudoPagina(
          largura: 640,
          child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                TextFormField(
                    controller: _nome,
                    textInputAction: TextInputAction.next,
                    decoration:
                        const InputDecoration(labelText: 'Nome completo'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Informe o nome completo.'
                        : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch((v ?? '').trim())
                        ? null
                        : 'Informe um e-mail válido.'),
                const SizedBox(height: 24),
                const Text('Turmas (opcional)'),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _turmas
                        .map((t) => FilterChip(
                            label: Text(t['nome'].toString()),
                            selected: _selecionadas.contains(t['id']),
                            onSelected: _salvando
                                ? null
                                : (v) => setState(() {
                                      if (v) {
                                        _selecionadas.add(t['id'] as int);
                                      } else {
                                        _selecionadas.remove(t['id']);
                                      }
                                    })))
                        .toList()),
                if (_erroTurmas != null) ...[
                  Text(_erroTurmas!),
                  TextButton(
                      onPressed: _carregarTurmas,
                      child: const Text('Tentar novamente'))
                ],
                if (_erro != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_erro!,
                          style: const TextStyle(color: Colors.red))),
              ]))));
}
