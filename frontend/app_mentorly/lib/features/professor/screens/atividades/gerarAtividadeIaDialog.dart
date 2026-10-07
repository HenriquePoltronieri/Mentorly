import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/apiService.dart';
import '../../models/sugestaoAtividadeModel.dart';
import '../../services/geracaoAtividadeIaService.dart';

// Geracao assistida de atividade (Marco 9B).
//
// Fase 1: o Professor descreve o que quer. Fase 2: revisa e edita a sugestao.
// O dialogo NAO salva nada: ao confirmar devolve o texto revisado, e o
// formulario normal de atividade e quem cria (POST /api/activities), com as
// mesmas validacoes de sempre. Cancelar descarta a sugestao.
class GerarAtividadeIaDialog extends StatefulWidget {
  final String turmaId;
  final int? etapaId;
  final int? criterioId;
  final GeracaoAtividadeIaService? service;

  const GerarAtividadeIaDialog({
    super.key,
    required this.turmaId,
    this.etapaId,
    this.criterioId,
    this.service,
  });

  @override
  State<GerarAtividadeIaDialog> createState() => _GerarAtividadeIaDialogState();
}

class _QuestaoEditavel {
  final String tipo;
  final TextEditingController enunciado;
  final List<TextEditingController> alternativas;
  final TextEditingController resposta; // gabarito (discursiva) ou letra
  final TextEditingController explicacao;

  _QuestaoEditavel(QuestaoSugerida q)
      : tipo = q.tipo,
        enunciado = TextEditingController(text: q.enunciado),
        alternativas =
            q.alternativas.map((a) => TextEditingController(text: a)).toList(),
        resposta = TextEditingController(text: q.respostaEsperada),
        explicacao = TextEditingController(text: q.explicacao);

  bool get objetiva => tipo == 'objetiva';

  QuestaoSugerida paraModelo() => QuestaoSugerida(
        tipo: tipo,
        enunciado: enunciado.text,
        alternativas: alternativas.map((c) => c.text).toList(),
        respostaEsperada: resposta.text,
        explicacao: explicacao.text,
      );

  void dispose() {
    enunciado.dispose();
    for (final c in alternativas) {
      c.dispose();
    }
    resposta.dispose();
    explicacao.dispose();
  }
}

class _GerarAtividadeIaDialogState extends State<GerarAtividadeIaDialog> {
  late final GeracaoAtividadeIaService _service;

  final _tema = TextEditingController();
  final _objetivo = TextEditingController();
  final _observacoes = TextEditingController();
  String _dificuldade = 'media';
  String _tipo = 'mista';
  int _quantidade = 4;

  bool _gerando = false;
  String? _erro;

  SugestaoAtividadeModel? _sugestao;
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  final _objetivoSugerido = TextEditingController();
  List<_QuestaoEditavel> _questoes = [];
  bool _incluirRubrica = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GeracaoAtividadeIaService();
  }

  @override
  void dispose() {
    _tema.dispose();
    _objetivo.dispose();
    _observacoes.dispose();
    _titulo.dispose();
    _descricao.dispose();
    _objetivoSugerido.dispose();
    for (final q in _questoes) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _gerar() async {
    if (_gerando) return; // evita pedido duplicado por duplo clique
    if (_tema.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o tema da atividade');
      return;
    }
    setState(() {
      _gerando = true;
      _erro = null;
    });
    try {
      final sugestao = await _service.gerar(
        turmaId: widget.turmaId,
        tema: _tema.text.trim(),
        objetivo: _objetivo.text,
        observacoes: _observacoes.text,
        dificuldade: _dificuldade,
        quantidadeQuestoes: _quantidade,
        tipo: _tipo,
        etapaId: widget.etapaId,
        criterioId: widget.criterioId,
      );
      if (!mounted) return;
      _carregarRevisao(sugestao);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (_) {
      if (mounted) {
        setState(() => _erro =
            'Não foi possível gerar a atividade agora. Tente novamente em instantes ou crie a atividade manualmente.');
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  void _carregarRevisao(SugestaoAtividadeModel sugestao) {
    for (final q in _questoes) {
      q.dispose();
    }
    setState(() {
      _sugestao = sugestao;
      _titulo.text = sugestao.titulo;
      _descricao.text = sugestao.descricao;
      _objetivoSugerido.text = sugestao.objetivo;
      _questoes = sugestao.questoes.map(_QuestaoEditavel.new).toList();
      _incluirRubrica = false;
    });
  }

  void _voltar() {
    setState(() {
      _sugestao = null;
      _erro = null;
    });
  }

  void _confirmar() {
    if (_titulo.text.trim().isEmpty) {
      setState(() => _erro = 'O título não pode ficar vazio');
      return;
    }
    Navigator.of(context).pop(
      SugestaoAtividadeModel(
        titulo: _titulo.text.trim(),
        descricao: _descricao.text,
        objetivo: _objetivoSugerido.text,
        questoes: _questoes.map((q) => q.paraModelo()).toList(),
        rubrica: _incluirRubrica ? (_sugestao?.rubrica ?? const []) : const [],
        modelo: _sugestao?.modelo ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: _sugestao == null ? _construirPedido() : _construirRevisao(),
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
              'Conteúdo gerado por IA. Revise antes de salvar.',
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

  Widget _construirPedido() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gerar atividade com IA', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        const Text(
          'A IA só sugere. Você revisa e decide o que salvar.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tema,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Tema',
            hintText: 'Exemplo "Revolução Industrial"',
          ),
        ),
        TextField(
          controller: _objetivo,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Objetivo (opcional)',
            hintText: 'O que o aluno deve demonstrar',
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _dificuldade,
          decoration: const InputDecoration(labelText: 'Dificuldade'),
          items: const [
            DropdownMenuItem(value: 'facil', child: Text('Fácil')),
            DropdownMenuItem(value: 'media', child: Text('Média')),
            DropdownMenuItem(value: 'dificil', child: Text('Difícil')),
          ],
          onChanged: (v) => setState(() => _dificuldade = v ?? 'media'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo de questões'),
          items: const [
            DropdownMenuItem(value: 'mista', child: Text('Mista')),
            DropdownMenuItem(value: 'discursiva', child: Text('Discursivas')),
            DropdownMenuItem(value: 'objetiva', child: Text('Objetivas')),
          ],
          onChanged: (v) => setState(() => _tipo = v ?? 'mista'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _quantidade,
          decoration: const InputDecoration(labelText: 'Quantidade de questões'),
          items: [
            for (var n = 1; n <= 10; n++)
              DropdownMenuItem(value: n, child: Text('$n')),
          ],
          onChanged: (v) => setState(() => _quantidade = v ?? 4),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _observacoes,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Observações (opcional)',
          ),
        ),
        _mensagemErro(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _gerando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
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
              label: Text(_gerando ? 'Gerando...' : 'Gerar sugestão'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirRevisao() {
    final rubrica = _sugestao?.rubrica ?? const [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Revisar sugestão', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        _aviso(),
        const SizedBox(height: 16),
        TextField(
          controller: _titulo,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descricao,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Descrição'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _objetivoSugerido,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Objetivo'),
        ),
        const SizedBox(height: 16),
        Text('Questões (${_questoes.length})',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        if (_questoes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Nenhuma questão. A atividade usará só a descrição.',
                style: TextStyle(color: Colors.black54, fontSize: 13)),
          ),
        for (var i = 0; i < _questoes.length; i++) _construirQuestao(i),
        if (rubrica.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Rubrica sugerida',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const Text(
            'Apenas uma sugestão: não cria critério oficial nem altera pesos.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          for (final item in rubrica)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• ${item.criterio} (${item.peso.toStringAsFixed(item.peso == item.peso.roundToDouble() ? 0 : 1)}%)'
                '${item.descricao.isEmpty ? '' : ' — ${item.descricao}'}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _incluirRubrica,
            onChanged: (v) => setState(() => _incluirRubrica = v ?? false),
            title: const Text('Incluir a rubrica na descrição',
                style: TextStyle(fontSize: 13)),
          ),
        ],
        _mensagemErro(),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            TextButton(onPressed: _voltar, child: const Text('Voltar')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _confirmar,
              child: const Text('Usar na atividade'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirQuestao(int indice) {
    final q = _questoes[indice];
    const letras = ['A', 'B', 'C', 'D', 'E', 'F'];
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Questão ${indice + 1} · ${q.objetiva ? 'Objetiva' : 'Discursiva'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Remover questão',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    _questoes.removeAt(indice).dispose();
                  }),
                ),
              ],
            ),
            TextField(
              controller: q.enunciado,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Enunciado'),
            ),
            if (q.objetiva)
              for (var j = 0; j < q.alternativas.length && j < letras.length; j++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: q.alternativas[j],
                    decoration: InputDecoration(
                      labelText: 'Alternativa ${letras[j]}',
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            TextField(
              controller: q.resposta,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: q.objetiva
                    ? 'Gabarito (letra da alternativa correta)'
                    : 'Resposta esperada',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: q.explicacao,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Explicação'),
            ),
          ],
        ),
      ),
    );
  }
}
