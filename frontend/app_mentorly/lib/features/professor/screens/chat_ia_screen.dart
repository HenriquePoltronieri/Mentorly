import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/estrutura_pagina.dart';
import '../../../core/widgets/identidade_visual.dart';
import '../services/chat_ia_service.dart';

class ChatIaScreen extends StatefulWidget {
  const ChatIaScreen({super.key});
  @override
  State<ChatIaScreen> createState() => _ChatIaScreenState();
}

class _ChatIaScreenState extends State<ChatIaScreen> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  ConversaIa? _conversa;
  String? _turmaNome;
  String? _alunoNome;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_conversa == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _turmaNome = args?['nome']?.toString();
      _alunoNome = args?['aluno_nome']?.toString();
      _conversa = ChatIaService.conversa(int.tryParse('${args?['id']}'),
          alunoId: int.tryParse('${args?['aluno_id']}'));
      _conversa!.addListener(_atualizar);
      if (_alunoNome != null) {
        _texto.text =
            'Como posso ajudar $_alunoNome a melhorar as notas, considerando as atividades e provas em que teve mais dificuldade?';
      }
    }
  }

  void _atualizar() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _enviar([String? sugestao]) {
    final texto = sugestao ?? _texto.text;
    if (texto.trim().isEmpty || _conversa!.digitando) return;
    if (texto.length <= 1000) _texto.clear();
    _conversa!.enviar(texto);
  }

  @override
  void dispose() {
    _conversa?.removeListener(_atualizar);
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _conversa!;
    return Scaffold(
        appBar: AppBar(
            title: Text(_alunoNome != null
                ? 'IA · $_alunoNome'
                : _turmaNome == null
                    ? 'Assistente pedagógico'
                    : 'IA · $_turmaNome'),
            actions: [
              TextButton(
                  onPressed: c.digitando ? null : c.nova,
                  child: const Text('Nova conversa')),
            ]),
        body: ConteudoPagina(
            vidro: false,
            child: Column(children: [
              Expanded(
                  child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                    if (c.mensagens.isEmpty)
                      const VidroCard(
                          padding: EdgeInsets.all(20),
                          child: Text(
                              'Pergunte sobre desempenho, risco ou medidas pedagógicas. As respostas usam os dados das suas turmas.')),
                    ...c.mensagens.map((m) => Align(
                        alignment: m['role'] == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 640),
                                child: VidroCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              m['role'] == 'user'
                                                  ? 'Você'
                                                  : 'Mentorly',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 8),
                                          SelectableText(
                                              m['content'].toString()),
                                          if (m['atalhos'] is List)
                                            Wrap(
                                                spacing: 8,
                                                children: (m['atalhos'] as List)
                                                    .map((a) => ActionChip(
                                                        label: Text(
                                                            'Abrir ${a['nome']}'),
                                                        avatar: const Icon(
                                                            Icons.arrow_forward,
                                                            size: 16),
                                                        onPressed: () =>
                                                            Navigator.pushNamed(
                                                                context,
                                                                a['aluno_id'] ==
                                                                        null
                                                                    ? AppRoutes
                                                                        .turmaAlunos
                                                                    : AppRoutes
                                                                        .alunoDetail,
                                                                arguments: {
                                                                  'id': a['aluno_id'] ??
                                                                      a['turma_id'],
                                                                  'nome':
                                                                      a['nome'],
                                                                  'turma_id': a[
                                                                      'turma_id']
                                                                })))
                                                    .toList()),
                                        ])))))),
                    if (c.digitando)
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Mentorly está digitando…'),
                          ])),
                    if (c.erro != null)
                      VidroCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.erro!,
                                    style: const TextStyle(color: Colors.red)),
                                if (c.pendente != null)
                                  TextButton(
                                      onPressed: c.digitando
                                          ? null
                                          : () => c.enviar(c.pendente!,
                                              repetir: true),
                                      child: const Text('Tentar novamente')),
                              ])),
                  ])),
              SafeArea(
                  top: false,
                  child: VidroCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        SizedBox(
                            height: 44,
                            child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  if (_alunoNome != null) ...[
                                    'Em quais avaliações $_alunoNome teve mais dificuldade?',
                                    'Sugira reforço para $_alunoNome com base nessas avaliações.',
                                    'Como está a pontuação de $_alunoNome nesta etapa?',
                                  ] else ...[
                                    'Qual aluno precisa de atenção no final da etapa?',
                                    'Quais medidas posso aplicar?',
                                    'Onde a turma tem mais dificuldade?',
                                    'Quem melhorou nas últimas atividades?',
                                    'Resumo da turma',
                                  ],
                                ]
                                    .map((s) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: ActionChip(
                                            label: Text(s),
                                            onPressed: c.digitando
                                                ? null
                                                : () => _enviar(s))))
                                    .toList())),
                        const SizedBox(height: 8),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                  child: TextField(
                                      controller: _texto,
                                      enabled: !c.digitando,
                                      minLines: 1,
                                      maxLines: 4,
                                      maxLength: 1000,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _enviar(),
                                      decoration: const InputDecoration(
                                          hintText: 'Pergunte sobre sua turma…',
                                          counterText: ''))),
                              IconButton(
                                  tooltip: 'Enviar mensagem',
                                  onPressed:
                                      c.digitando ? null : () => _enviar(),
                                  icon: const Icon(Icons.send))
                            ]),
                      ]))),
            ])));
  }
}
