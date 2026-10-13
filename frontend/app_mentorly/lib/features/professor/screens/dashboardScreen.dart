import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/services/apiService.dart';
import '../../../core/widgets/estrutura_pagina.dart';
import '../../../core/widgets/identidade_visual.dart';
import '../widgets/professorTopBar.dart';
import '../../../features/coordenacao/models/turmaModel.dart';
import '../services/professorTurmasService.dart';
import 'atividades/adicionarAtividadeModal.dart';
import '../services/professorDashboardService.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _carregando = true;
  String? _erro;
  Map<String, dynamic> _dados = {};
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await ProfessorDashboardService().buscarDashboard();
      if (mounted) setState(() => _dados = dados);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível conectar ao servidor.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _novaAtividade() async {
    try {
      final lista = await ProfessorTurmasService().listarTurmas();
      if (!mounted) return;
      await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => AdicionarAtividadeModal(
                  turmas: lista
                      .map((t) => TurmaModel.fromJson(
                          Map<String, dynamic>.from(t as Map)))
                      .toList())));
      if (mounted) _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível carregar as turmas.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'dashboard'),
      body: ConteudoPagina(
          vidro: false,
          child: RefreshIndicator(
              onRefresh: _carregar,
              child: _carregando
                  ? const CarregamentoPagina()
                  : _erro != null
                      ? VidroCard(
                          child: EstadoPagina(
                              titulo: 'Falha ao carregar o painel',
                              mensagem: _erro!,
                              acao: 'Tentar novamente',
                              onPressed: _carregar))
                      : _corpo())));
  Widget _corpo() {
    final ano = _dados['anoLetivo'];
    final risco = _dados['alunosEmRisco'] as List? ?? [];
    return ListView(padding: const EdgeInsets.all(12), children: [
      const SizedBox(height: 16),
      Text('Olá Professor(a) ${_dados['nome']?.toString() ?? 'Professor'}.',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
          ano == null
              ? 'Peça à Coordenação para definir o ano letivo atual.'
              : 'Ano letivo $ano',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
              onPressed: _novaAtividade,
              icon: const Icon(Icons.add),
              label: const Text('+ Nova atividade'))),
      const SizedBox(height: 12),
      Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chatIa),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Conversar com IA'))),
      const SizedBox(height: 32),
      LayoutBuilder(builder: (context, tamanho) {
        final cards = [
          _numero('Quantidade de turmas total', _dados['totalTurmas'] ?? 0),
          _numero('Quantidade de alunos total', _dados['totalAlunos'] ?? 0)
        ];
        return tamanho.maxWidth < 560
            ? Column(children: [cards[0], const SizedBox(height: 16), cards[1]])
            : Row(children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 24),
                Expanded(child: cards[1])
              ]);
      }),
      const SizedBox(height: 24),
      VidroCard(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Alunos em risco',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Todas as turmas e todas as salas',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            const Text(
                'Alertas no período final da etapa, considerando os pesos dos critérios e os pontos ainda possíveis nas atividades cadastradas. Notas pendentes precisam ser conferidas.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            if (risco.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Nenhum aluno em risco agora.')),
            ...risco.map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, AppRoutes.alunoDetail,
                              arguments: Map<String, dynamic>.from(a as Map)),
                          child: Text(a['nome']?.toString() ?? '',
                              style: Theme.of(context).textTheme.titleMedium)),
                      Text('Risco ${a['risco']}'),
                      const SizedBox(height: 4),
                      Text(a['turma']?.toString() ?? ''),
                      Text(
                          'Pontos avaliados: ${_nota(a['pontos_obtidos'])}/${_nota(a['pontos_avaliados'])}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (a['acompanhamento'] != null)
                        Text(
                            '${a['acompanhamento']['etapa']} · Pontos com os pesos: ${_nota(a['acompanhamento']['pontos_ponderados'])} · Mínimo: ${_nota(a['acompanhamento']['nota_minima'])}'),
                      ...((a['motivos'] as List?) ?? [])
                          .map((m) => Text(m.toString())),
                      const Divider(height: 24),
                    ]))),
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.listaTurmas),
                    icon: const Icon(Icons.grading_outlined),
                    label: const Text('Ver boletins'))),
          ])),
    ]);
  }

  String _nota(dynamic valor) =>
      valor is num ? valor.toStringAsFixed(1).replaceAll('.', ',') : '—';
  Widget _numero(String titulo, dynamic valor) => VidroCard(
      padding: const EdgeInsets.all(24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            Text('$valor',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 48, fontWeight: FontWeight.w500)),
          ]));
}
