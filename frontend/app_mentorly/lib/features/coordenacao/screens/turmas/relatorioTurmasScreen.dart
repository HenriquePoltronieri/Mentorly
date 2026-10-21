import 'package:flutter/material.dart';

import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/barra_mentorly.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../services/turmasService.dart';

class RelatorioTurmasScreen extends StatefulWidget {
  const RelatorioTurmasScreen({super.key});

  @override
  State<RelatorioTurmasScreen> createState() => _RelatorioTurmasScreenState();
}

class _RelatorioTurmasScreenState extends State<RelatorioTurmasScreen> {
  final _service = TurmasService();
  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _turmas = const [];

  Future<void> _carregar({bool atualizar = false}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      if (atualizar) ApiService().invalidarCache();
      final resultado = await _service.relatorioTurmasAtividades();
      if (!mounted) return;
      setState(() => _turmas = resultado
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList());
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = erro is ApiException
          ? erro.mensagem
          : 'Não foi possível carregar o relatório de turmas.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final totalAtividades = _turmas.fold<int>(
        0,
        (total, turma) =>
            total + ((turma['total_atividades'] as num?)?.toInt() ?? 0));
    return Scaffold(
      appBar: const BarraMentorly(professor: false, aba: 'inicio'),
      body: ConteudoPagina(
        vidro: false,
        child: _carregando
            ? const CarregamentoPagina()
            : _erro != null
                ? EstadoPagina(
                    titulo: 'Não foi possível abrir o relatório',
                    mensagem: _erro!,
                    acao: 'Tentar novamente',
                    onPressed: _carregar,
                  )
                : RefreshIndicator(
                    onRefresh: () => _carregar(atualizar: true),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text('Relatório de turmas',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${_turmas.length} turmas · $totalAtividades atividades',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        if (_turmas.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                  'Cadastre uma turma para acompanhar suas atividades.'),
                            ),
                          )
                        else
                          ..._turmas.map(_cardTurma),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _cardTurma(Map<String, dynamic> turma) {
    final nome = (turma['turma'] ?? turma['name'] ?? turma['nome'] ?? 'Turma')
        .toString();
    final quantidade = (turma['total_atividades'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.assessment_outlined),
        title: Text(nome),
        subtitle: Text(
            '$quantidade ${quantidade == 1 ? 'atividade cadastrada' : 'atividades cadastradas'}'),
      ),
    );
  }
}
