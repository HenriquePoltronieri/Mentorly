import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String _dataHistorico(String bruto) {
    final data = DateTime.tryParse(bruto)?.toLocal();
    if (data == null) return '';
    String dois(int valor) => valor.toString().padLeft(2, '0');
    return '${dois(data.day)}/${dois(data.month)}/${data.year} '
        '${dois(data.hour)}:${dois(data.minute)}';
  }

  Future<void> _copiar(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resposta copiada.')),
    );
  }

  Future<void> _mostrarHistorico() async {
    final conversa = _conversa!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: conversa,
        builder: (_, __) => AlertDialog(
          title: const Text('Histórico de conversas'),
          content: SizedBox(
            width: 520,
            child: conversa.historico.isEmpty
                ? const Text(
                    'As conversas encerradas com “Nova conversa” aparecerão aqui.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: conversa.historico.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, indice) {
                      final item = conversa.historico[indice];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['titulo'].toString(),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_dataHistorico(item['data'].toString())),
                        onTap: () {
                          conversa.restaurar(item['id'].toString());
                          Navigator.of(dialogContext).pop();
                        },
                        trailing: IconButton(
                          tooltip: 'Excluir conversa',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              conversa.excluirHistorico(item['id'].toString()),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            if (conversa.historico.isNotEmpty)
              TextButton(
                onPressed: conversa.limparHistorico,
                child: const Text('Limpar histórico'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
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
              IconButton(
                tooltip: 'Histórico de conversas',
                onPressed: c.carregando ? null : _mostrarHistorico,
                icon: const Icon(Icons.history),
              ),
              TextButton(
                  onPressed: c.digitando || c.carregando ? null : c.nova,
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
                    if (c.carregando)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (c.mensagens.isEmpty)
                      const VidroCard(
                          padding: EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Pergunte sobre desempenho, risco ou medidas pedagógicas. As respostas usam os dados das suas turmas.'),
                                SizedBox(height: 8),
                                Text(
                                    'Proteção de dados: nomes e identificadores dos alunos desta turma são substituídos antes da consulta à IA. Evite digitar outros dados pessoais. O histórico fica somente neste dispositivo e pode ser apagado.',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                              ])),
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
                                          Row(children: [
                                            Text(
                                                m['role'] == 'user'
                                                    ? 'Você'
                                                    : 'Mentorly',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const Spacer(),
                                            if (m['role'] == 'assistant')
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                tooltip: 'Copiar resposta',
                                                onPressed: () => _copiar(
                                                    m['content'].toString()),
                                                icon: const Icon(
                                                    Icons.copy_outlined,
                                                    size: 18),
                                              ),
                                          ]),
                                          const SizedBox(height: 8),
                                          if (m['aviso'] is String)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: Text(m['aviso'].toString(),
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black54)),
                                            ),
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
                                      enabled: !c.digitando && !c.carregando,
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
                                  onPressed: c.digitando || c.carregando
                                      ? null
                                      : () => _enviar(),
                                  icon: const Icon(Icons.send))
                            ]),
                      ]))),
            ])));
  }
}
