import 'package:flutter/material.dart';

import '../../../../core/services/apiService.dart';
import '../../models/estatisticaAlunoModel.dart';
import '../../models/feedbackIaModel.dart';
import '../../services/feedbackIaService.dart';

// Feedback e plano de recuperacao por IA (Marco 9D).
//
// So leitura: o dialogo mostra uma SUGESTAO pedagogica sobre numeros que o
// Mentorly ja calculou. Nada e salvo, nenhuma nota ou situacao muda, e nenhum
// dado pessoal do aluno vai para a IA (o nome so aparece aqui, na tela).
// A chamada so acontece quando o Professor clica em "Gerar feedback com IA".
class FeedbackIaDialog extends StatefulWidget {
  final int alunoId;
  final EtapaDesempenhoModel etapa;
  final String alunoNome; // so para exibir; nunca vai para a IA
  final FeedbackIaService? service;

  const FeedbackIaDialog({
    super.key,
    required this.alunoId,
    required this.etapa,
    this.alunoNome = '',
    this.service,
  });

  @override
  State<FeedbackIaDialog> createState() => _FeedbackIaDialogState();
}

class _FeedbackIaDialogState extends State<FeedbackIaDialog> {
  late final FeedbackIaService _service;
  bool _gerando = false;
  String? _erro;
  FeedbackIaModel? _feedback;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FeedbackIaService();
  }

  Future<void> _gerar() async {
    if (_gerando) return; // evita pedido duplicado por duplo clique
    setState(() {
      _gerando = true;
      _erro = null;
    });
    try {
      final feedback = await _service.gerar(
        alunoId: widget.alunoId,
        etapaId: widget.etapa.etapaId,
      );
      if (mounted) setState(() => _feedback = feedback);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (_) {
      if (mounted) {
        setState(() => _erro =
            'Não foi possível gerar o feedback agora. Tente novamente em instantes. O desempenho do aluno continua disponível normalmente.');
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  // Situacao OFICIAL, vinda do motor (nunca da IA).
  String _situacaoOficial() {
    final e = widget.etapa;
    String um(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    switch (e.situacao) {
      case 'adequado':
        return 'Nota ${um(e.notaCalculada!)} de ${e.notaMaxima!.toStringAsFixed(0)} — adequado';
      case 'abaixo_do_minimo':
        return 'Nota ${um(e.notaCalculada!)} de ${e.notaMaxima!.toStringAsFixed(0)} — abaixo do mínimo (${e.notaMinima!.toStringAsFixed(0)})';
      case 'configuracao_invalida':
        return e.mensagem ?? 'Configuração da etapa inválida';
      default:
        return 'Em andamento — ainda faltam notas para calcular';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: _feedback == null ? _construirPedido() : _construirResultado(),
          ),
        ),
      ),
    );
  }

  Widget _aviso() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sugestões geradas por IA com base nos dados acadêmicos disponíveis. Revise antes de utilizar.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _situacaoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Situação oficial · ${widget.etapa.etapa}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(_situacaoOficial(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const Text(
            'Calculada pelo Mentorly. A IA não altera nota, situação, critério nem etapa.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _construirPedido() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Feedback com IA', style: TextStyle(fontSize: 18)),
        if (widget.alunoNome.isNotEmpty)
          Text('Aluno: ${widget.alunoNome}',
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 4),
        const Text(
          'Nenhum dado pessoal do aluno é enviado à IA: só os resultados já calculados desta etapa.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _aviso(),
        const SizedBox(height: 12),
        _situacaoCard(),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_erro!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _gerando ? null : () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _gerando ? null : _gerar,
              icon: _gerando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_gerando ? 'Gerando...' : 'Gerar feedback com IA'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lista(String titulo, List<String> itens, IconData icone) {
    if (itens.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final item in itens)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icone, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirResultado() {
    final f = _feedback!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(f.tituloDoPlano, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        _aviso(),
        const SizedBox(height: 12),
        _situacaoCard(),
        if (f.resumo.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Resumo da situação',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(f.resumo, style: const TextStyle(fontSize: 13)),
        ],
        _lista('Pontos consolidados', f.pontosConsolidados,
            Icons.check_circle_outline),
        if (f.pontosAtencao.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Pontos de atenção',
              style: TextStyle(fontWeight: FontWeight.w600)),
          for (final p in f.pontosAtencao)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.descricao,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Evidência: ${p.evidencia}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
        _lista(f.tituloDosObjetivos, f.objetivos, Icons.flag_outlined),
        if (f.acoes.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Ações sugeridas',
              style: TextStyle(fontWeight: FontWeight.w600)),
          for (final a in f.acoes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${a.acao}', style: const TextStyle(fontSize: 13)),
                  if (a.motivo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text('Motivo: ${a.motivo}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ),
                ],
              ),
            ),
        ],
        _lista('Atividades sugeridas', f.atividadesSugeridas,
            Icons.edit_note_outlined),
        if (f.acompanhamento.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Acompanhamento recomendado',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(f.acompanhamento, style: const TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ),
      ],
    );
  }
}
