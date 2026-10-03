import 'package:flutter/material.dart';

import '../../../../core/services/apiService.dart';
import '../../models/insightsTurmaModel.dart';
import '../../services/insightsIaService.dart';
import '../../widgets/professorTopBar.dart';

class InsightsTurmaScreen extends StatefulWidget {
  final Map<String, dynamic>? turmaInicial;
  final InsightsIaService? service;

  const InsightsTurmaScreen({
    super.key,
    this.turmaInicial,
    this.service,
  });

  @override
  State<InsightsTurmaScreen> createState() => _InsightsTurmaScreenState();
}

class _InsightsTurmaScreenState extends State<InsightsTurmaScreen> {
  late final InsightsIaService _service;
  Map<String, dynamic>? _turma;
  InsightsTurmaModel? _resultado;
  String? _erro;
  bool _gerando = false;
  bool _leuArgumentos = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? InsightsIaService();
    _turma = widget.turmaInicial;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_leuArgumentos) {
      _turma ??=
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _leuArgumentos = true;
    }
  }

  Future<void> _gerar() async {
    if (_turma == null || _gerando) return;
    setState(() {
      _gerando = true;
      _erro = null;
    });
    try {
      final resultado = await _service.gerar(_turma!['id'] as int);
      if (mounted) setState(() => _resultado = resultado);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro =
              'Não foi possível gerar os insights agora. Tente novamente em instantes.';
        });
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomeTurma = _turma?['nome']?.toString() ?? '';
    final ano = _turma?['anoLetivo'] ?? _turma?['ano_letivo'];
    return Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'turmas'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Insights com IA',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [nomeTurma, if (ano != null) ano.toString()]
                          .where((item) => item.isNotEmpty)
                          .join(' · '),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Insights gerados por IA com base nos dados acadêmicos registrados no Mentorly.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use como apoio pedagógico. As notas e os status oficiais são calculados pelo sistema.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _turma == null || _gerando ? null : _gerar,
                    icon: _gerando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(_gerando ? 'Gerando...' : 'Gerar insights'),
                  ),
                ],
              ),
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_erro!)),
                  ],
                ),
              ),
            ),
          ],
          if (_resultado != null) ...[
            const SizedBox(height: 20),
            Text(
              '${_resultado!.etapa} · ${_resultado!.anoLetivo}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _SecaoTexto(titulo: 'Resumo da turma', itens: [_resultado!.resumo]),
            if (_resultado!.pontosPositivos.isNotEmpty)
              _SecaoTexto(
                titulo: 'Pontos positivos',
                itens: _resultado!.pontosPositivos,
                icone: Icons.check_circle_outline,
              ),
            if (_resultado!.pontosAtencao.isNotEmpty)
              _SecaoAtencao(pontos: _resultado!.pontosAtencao),
            if (_resultado!.sugestoesGerais.isNotEmpty)
              _SecaoTexto(
                titulo: 'Sugestões pedagógicas',
                itens: _resultado!.sugestoesGerais,
                icone: Icons.lightbulb_outline,
              ),
          ],
        ],
      ),
    );
  }
}

class _SecaoTexto extends StatelessWidget {
  final String titulo;
  final List<String> itens;
  final IconData? icone;

  const _SecaoTexto({required this.titulo, required this.itens, this.icone});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...itens.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icone ?? Icons.notes, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecaoAtencao extends StatelessWidget {
  final List<PontoAtencaoIa> pontos;

  const _SecaoAtencao({required this.pontos});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pontos de atenção',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...pontos.map(
              (ponto) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ponto.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Evidência: ${ponto.evidencia}'),
                    Text('Sugestão: ${ponto.sugestao}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
