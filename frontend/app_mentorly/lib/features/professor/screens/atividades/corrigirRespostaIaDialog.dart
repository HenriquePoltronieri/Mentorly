import 'package:flutter/material.dart';

import '../../../../core/services/apiService.dart';
import '../../models/correcaoSugeridaModel.dart';
import '../../services/correcaoAssistidaIaService.dart';

// Correcao assistida de resposta discursiva (Marco 9C).
//
// Fase 1: o Professor cola a questao, a resposta esperada e a resposta do
// aluno. Fase 2: ve a SUGESTAO da IA. O dialogo NAO lanca nada: "Usar nota
// sugerida" so devolve o numero, que a tela de notas coloca no campo de nota.
// Quem grava continua sendo o botao "Salvar notas", depois da decisao do
// Professor, que pode mudar o valor antes.
class CorrigirRespostaIaDialog extends StatefulWidget {
  final String atividadeId;
  final double valorMaximoAtividade;
  final String alunoNome; // so para exibir na tela; nunca vai para a IA
  final CorrecaoAssistidaIaService? service;

  const CorrigirRespostaIaDialog({
    super.key,
    required this.atividadeId,
    required this.valorMaximoAtividade,
    this.alunoNome = '',
    this.service,
  });

  @override
  State<CorrigirRespostaIaDialog> createState() =>
      _CorrigirRespostaIaDialogState();
}

class _CorrigirRespostaIaDialogState extends State<CorrigirRespostaIaDialog> {
  late final CorrecaoAssistidaIaService _service;

  final _questao = TextEditingController();
  final _esperada = TextEditingController();
  final _resposta = TextEditingController();
  final _rubrica = TextEditingController();
  late final TextEditingController _valorMaximo;

  bool _analisando = false;
  String? _erro;
  CorrecaoSugeridaModel? _sugestao;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CorrecaoAssistidaIaService();
    _valorMaximo =
        TextEditingController(text: _formatar(widget.valorMaximoAtividade));
  }

  @override
  void dispose() {
    _questao.dispose();
    _esperada.dispose();
    _resposta.dispose();
    _rubrica.dispose();
    _valorMaximo.dispose();
    super.dispose();
  }

  // 2.0 vira "2"; 7.5 continua "7,5" (virgula, como o professor digita).
  static String _formatar(double valor) {
    final texto = valor == valor.roundToDouble()
        ? valor.toInt().toString()
        : valor.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return texto.replaceAll('.', ',');
  }

  // "Compreensão do conceito: 50" -> {item, peso}; sem numero, so o item.
  List<Map<String, dynamic>> _lerRubrica() {
    final itens = <Map<String, dynamic>>[];
    for (final linha in _rubrica.text.split('\n')) {
      final texto = linha.trim();
      if (texto.isEmpty) continue;
      final corte = texto.lastIndexOf(':');
      if (corte > 0) {
        final peso =
            double.tryParse(texto.substring(corte + 1).trim().replaceAll(',', '.'));
        if (peso != null) {
          itens.add({'item': texto.substring(0, corte).trim(), 'peso': peso});
          continue;
        }
      }
      itens.add({'item': texto});
    }
    return itens;
  }

  String? _validar() {
    if (_questao.text.trim().isEmpty) return 'Cole a questão';
    if (_esperada.text.trim().isEmpty) return 'Informe a resposta esperada';
    if (_resposta.text.trim().isEmpty) return 'Cole a resposta do aluno';
    final valor = double.tryParse(_valorMaximo.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      return 'O valor máximo precisa ser maior que zero';
    }
    if (valor > widget.valorMaximoAtividade) {
      return 'O valor máximo não pode passar do valor da atividade '
          '(${_formatar(widget.valorMaximoAtividade)})';
    }
    if (_lerRubrica().length > 6) return 'A rubrica aceita até 6 itens';
    return null;
  }

  Future<void> _analisar() async {
    if (_analisando) return; // evita pedido duplicado por duplo clique
    final invalido = _validar();
    if (invalido != null) {
      setState(() => _erro = invalido);
      return;
    }
    setState(() {
      _analisando = true;
      _erro = null;
    });
    try {
      final sugestao = await _service.corrigir(
        atividadeId: widget.atividadeId,
        questao: _questao.text,
        respostaEsperada: _esperada.text,
        respostaAluno: _resposta.text,
        valorMaximo:
            double.parse(_valorMaximo.text.trim().replaceAll(',', '.')),
        rubrica: _lerRubrica(),
      );
      if (mounted) setState(() => _sugestao = sugestao);
    } on ApiException catch (erro) {
      // Os textos digitados ficam nos campos: nada se perde.
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (_) {
      if (mounted) {
        setState(() => _erro =
            'Não foi possível analisar a resposta agora. Tente novamente em instantes ou lance a nota manualmente.');
      }
    } finally {
      if (mounted) setState(() => _analisando = false);
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
            child: _sugestao == null ? _construirEntrada() : _construirResultado(),
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
              'A avaliação gerada por IA é apenas uma sugestão. Revise antes de lançar a nota.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensagemErro() {
    if (_erro == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }

  Widget _construirEntrada() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Corrigir resposta com IA', style: TextStyle(fontSize: 18)),
        if (widget.alunoNome.isNotEmpty)
          Text('Aluno: ${widget.alunoNome}',
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 4),
        const Text(
          'O nome do aluno não é enviado à IA, só o texto abaixo.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _aviso(),
        const SizedBox(height: 12),
        TextField(
          controller: _questao,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Questão'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _esperada,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Resposta esperada'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _resposta,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Resposta do aluno'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _valorMaximo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor máximo desta resposta',
            helperText:
                'Até ${_formatar(widget.valorMaximoAtividade)} (valor da atividade)',
            suffixText: 'pontos',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _rubrica,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Rubrica (opcional)',
            helperText: 'Um item por linha. Exemplo: Compreensão do conceito: 50',
          ),
        ),
        _mensagemErro(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _analisando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _analisando ? null : _analisar,
              icon: _analisando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_analisando ? 'Analisando...' : 'Analisar resposta'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _secao(String titulo, List<String> itens, IconData icone) {
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
    final s = _sugestao!;
    final percentual = s.percentual == s.percentual.roundToDouble()
        ? s.percentual.toInt().toString()
        : s.percentual.toStringAsFixed(1).replaceAll('.', ',');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sugestão da IA', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        _aviso(),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nota sugerida', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(
                '${_formatar(s.notaSugerida)} de ${_formatar(s.valorMaximo)}  ·  $percentual%',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'O percentual é calculado pelo Mentorly. A nota oficial é a que você lançar.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        if (s.justificativa.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Justificativa', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(s.justificativa, style: const TextStyle(fontSize: 13)),
        ],
        if (s.avaliacao.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Avaliação por critério',
              style: TextStyle(fontWeight: FontWeight.w600)),
          for (final item in s.avaliacao)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.criterio} · ${item.rotuloResultado}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Evidência: ${item.evidencia}',
                        style: const TextStyle(fontSize: 13)),
                    if (item.faltou.isNotEmpty)
                      Text('Faltou: ${item.faltou}',
                          style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
        _secao('Pontos positivos', s.pontosPositivos, Icons.check_circle_outline),
        _secao('Pontos a melhorar', s.pontosMelhorar, Icons.arrow_circle_up_outlined),
        if (s.feedbackAluno.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Feedback sugerido ao aluno',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(s.feedbackAluno, style: const TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => setState(() => _sugestao = null),
              child: const Text('Voltar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(s.notaSugerida),
              child: const Text('Usar nota sugerida'),
            ),
          ],
        ),
      ],
    );
  }
}
