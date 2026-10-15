import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/apiService.dart';
import '../../../core/widgets/estrutura_pagina.dart';
import '../../../core/widgets/identidade_visual.dart';
import '../../coordenacao/models/turmaModel.dart';
import '../models/atividadeModel.dart';
import '../widgets/professor_scaffold.dart';
import '../services/professorTurmasService.dart';
import '../services/professorDashboardService.dart';
import 'atividades/adicionarAtividadeModal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _carregando = true;
  String? _erro, _erroTrabalho;
  Map<String, dynamic> _dados = {}, _trabalho = {};
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _erroTrabalho = null;
    });
    ApiService().invalidarCache();
    await Future.wait([_resumo(), _tarefas()]);
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _resumo() async {
    try {
      final dados = await ProfessorDashboardService().buscarDashboard();
      if (mounted) setState(() => _dados = dados);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar o painel.');
      }
    }
  }

  Future<void> _tarefas() async {
    try {
      final dados = await ApiService().get('/professor/trabalho');
      if (mounted) {
        setState(() => _trabalho = Map<String, dynamic>.from(dados as Map));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erroTrabalho = e is ApiException
            ? e.mensagem
            : 'Não foi possível consultar as pendências.');
      }
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

  Future<void> _abrirPendencia(dynamic p) async {
    await Navigator.pushNamed(context, AppRoutes.atividadeNotas, arguments: {
      'atividade': AtividadeModel.fromJson({
        'id': p['id'],
        'title': p['titulo'],
        'class_id': p['turma_id'],
        'etapa_id': p['etapa_id'],
        'criterio_id': p['criterio_id'],
        'nota_maxima': p['nota_maxima']
      })
    });
    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) => ProfessorScaffold(
      aba: 'dashboard',
      body: ConteudoPagina(
          vidro: false,
          child: RefreshIndicator(
              onRefresh: _carregar,
              child: _carregando
                  ? const CarregamentoPagina()
                  : _erro != null
                      ? EstadoPagina(
                          titulo: 'Não foi possível abrir o início',
                          mensagem: _erro!,
                          acao: 'Tentar novamente',
                          onPressed: _carregar)
                      : _corpo())));

  Widget _secao(String titulo, String subtitulo, Widget child,
          {Widget? acao}) =>
      VidroCard(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(titulo, style: Theme.of(context).textTheme.titleLarge),
                  if (acao != null) acao
                ]),
            const SizedBox(height: 4),
            Text(subtitulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child
          ]));

  Widget _corpo() {
    final pendencias = _trabalho['pendencias'] as List? ?? [];
    final turmas = _trabalho['turmas'] as List? ?? [];
    final retornos = _trabalho['acompanhamentos'] as List? ?? [];
    final risco = _dados['alunosEmRisco'] as List? ?? [];
    final nome = _dados['nome']?.toString().trim() ?? '';
    return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Text(
              nome.isEmpty
                  ? 'Seu espaço de trabalho'
                  : 'Olá, ${nome.split(' ').first}',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
              _dados['anoLetivo'] == null
                  ? 'Peça à coordenação para definir o ano letivo atual.'
                  : 'Ano letivo ${_dados['anoLetivo']} · Mais tempo para ensinar.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.icon(
                onPressed: _novaAtividade,
                icon: const Icon(Icons.add),
                label: const Text('Nova atividade')),
            OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.listaTurmas),
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('Abrir minhas turmas')),
          ]),
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 8, children: [
            _indicador(
                Icons.groups_outlined, '${_dados['totalTurmas'] ?? 0} turmas'),
            _indicador(
                Icons.people_outline, '${_dados['totalAlunos'] ?? 0} alunos'),
            if (_erroTrabalho == null)
              _indicador(Icons.edit_note,
                  '${pendencias.length} atividades com notas pendentes'),
          ]),
          const SizedBox(height: 24),
          _secao(
              'O que precisa da sua atenção',
              'Pendências de lançamento. Uma nota em branco não significa falta de entrega.',
              _erroTrabalho != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(_erroTrabalho!),
                          TextButton(
                              onPressed: _carregar,
                              child: const Text('Tentar novamente'))
                        ])
                  : pendencias.isEmpty
                      ? _vazio(
                          Icons.task_alt,
                          'Tudo em dia nos lançamentos',
                          turmas.isEmpty
                              ? 'As pendências aparecerão quando você tiver turmas e atividades.'
                              : 'Nenhuma nota pendente nas atividades de etapas abertas.')
                      : Column(
                          children: pendencias
                              .map((p) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFFFF3E0),
                                      foregroundColor: AppCores.atencao,
                                      child: Icon(Icons.edit_note)),
                                  title: Text(p['titulo'].toString()),
                                  subtitle: Text(
                                      '${p['turma']} · ${p['sem_nota']} de ${p['total_alunos']} sem nota\n${p['etapa']}${p['data_entrega'] == '' ? '' : ' · Entrega: ${_data(p['data_entrega'])}'}'),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _abrirPendencia(p)))
                              .toList())),
          const SizedBox(height: 20),
          _secao(
              'Minhas turmas',
              'Abra uma turma para consultar alunos, atividades e notas.',
              turmas.isEmpty
                  ? _vazio(Icons.groups_outlined, 'Suas turmas aparecerão aqui',
                      'A coordenação faz o vínculo das turmas ao seu perfil.')
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: turmas
                          .map((t) => SizedBox(
                              width: 280,
                              child: Card(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                      leading:
                                          const Icon(Icons.school_outlined),
                                      title: Text(t['nome'].toString()),
                                      subtitle:
                                          Text('${t['totalAlunos']} alunos'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.pushNamed(
                                          context, AppRoutes.turmaAlunos,
                                          arguments: Map<String, dynamic>.from(
                                              t as Map))))))
                          .toList())),
          const SizedBox(height: 20),
          _secao(
              'Retornos de acompanhamento',
              'Intervenções registradas por você, em ordem de retorno.',
              retornos.isEmpty
                  ? _vazio(
                      Icons.event_available_outlined,
                      'Nenhum retorno agendado',
                      'No perfil do aluno, registre uma intervenção e combine uma data para revisar.')
                  : Column(
                      children: retornos
                          .map((r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event_note_outlined),
                              title: Text(r['aluno'].toString()),
                              subtitle: Text(
                                  '${r['turma']} · Retorno: ${_data(r['retorno_em'])}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.pushNamed(
                                    context, AppRoutes.acompanhamentos,
                                    arguments: {
                                      'turma_id': r['turma_id'],
                                      'id': r['aluno_id'],
                                      'nome': r['aluno']
                                    });
                                if (mounted) _carregar();
                              }))
                          .toList())),
          const SizedBox(height: 20),
          _secao(
              'Alunos que precisam de acompanhamento',
              'Sinais calculados com as regras da escola. Confira também os lançamentos pendentes.',
              risco.isEmpty
                  ? _vazio(
                      Icons.insights_outlined,
                      'Nenhum alerta de risco no momento',
                      'Com avaliações lançadas, o Mentorly ajuda a identificar quem precisa de atenção.')
                  : Column(
                      children: risco
                          .map((a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(a['nome'].toString()),
                              subtitle:
                                  Text('${a['turma']} · Risco ${a['risco']}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.alunoDetail,
                                  arguments:
                                      Map<String, dynamic>.from(a as Map))))
                          .toList()),
              acao: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.listaTurmas),
                  child: const Text('Ver turmas'))),
          const SizedBox(height: 20),
          _secao(
              'Assistente pedagógico',
              'Prepare atividades, revise respostas e planeje a recuperação a partir do contexto da turma.',
              Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.chatIa),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Conversar com o assistente')))),
          const SizedBox(height: 24),
        ]);
  }

  Widget _indicador(IconData icon, String texto) => Chip(
      avatar: Icon(icon, size: 18),
      label: Text(texto),
      backgroundColor: Colors.white);
  Widget _vazio(IconData icon, String titulo, String descricao) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppCores.secundario),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(descricao, style: Theme.of(context).textTheme.bodySmall)
        ]))
      ]));
  String _data(dynamic valor) {
    final d = DateTime.tryParse(valor.toString());
    return d == null
        ? valor.toString()
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
