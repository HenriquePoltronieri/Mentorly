import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/menu_card.dart';
import '../../../core/services/apiService.dart';
import '../../../core/widgets/estrutura_pagina.dart';
import '../../../core/widgets/barra_mentorly.dart';
import '../controllers/configAnoLetivoController.dart';

class CoordenacaoHomeScreen extends StatefulWidget {
  const CoordenacaoHomeScreen({super.key});
  @override
  State<CoordenacaoHomeScreen> createState() => _CoordenacaoHomeScreenState();
}

class _CoordenacaoHomeScreenState extends State<CoordenacaoHomeScreen> {
  bool _carregando = true;
  String? _erro;
  Map<String, dynamic> _resumo = {};
  Map<String, dynamic>? _ano;
  bool _configurado = false;
  Future<void> _carregar({bool atualizar = false}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final api = ApiService();
      final respostas = await Future.wait([
        api.get('/dashboard/resumo'),
        api.get('/config/anos-letivos', atualizar: atualizar),
        api.get('/config/etapas', atualizar: atualizar),
      ]);
      if (!mounted) return;
      final atuais =
          (respostas[1] as List).where((a) => a['status'] == 'atual');
      setState(() {
        _resumo = Map<String, dynamic>.from(respostas[0] as Map);
        _ano = atuais.isEmpty ? null : Map<String, dynamic>.from(atuais.first);
        final etapas = respostas[2] as List;
        _configurado = etapas.isNotEmpty &&
            etapas.every((e) =>
                e['pesoValido'] == true &&
                e['nota_minima'] != null &&
                e['nota_maxima'] != null);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar os dados da escola.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _abrir(String rota) async {
    if (rota == AppRoutes.configEtapas) {
      ConfigAnoLetivoController().anoLetivo = null;
    }
    await Navigator.pushNamed(context, rota);
    if (mounted) _carregar(atualizar: true);
  }

  @override
  Widget build(BuildContext context) {
    final nome = ApiService().usuario?['nome']?.toString() ?? '';
    final titulo = nome.trim().isEmpty || nome.toLowerCase() == 'coordenacao'
        ? 'Sua escola'
        : nome;
    return Scaffold(
      appBar: const BarraMentorly(professor: false, aba: 'inicio'),
      body: ConteudoPagina(
          vidro: false,
          child: RefreshIndicator(
              onRefresh: () => _carregar(atualizar: true),
              child: _carregando
                  ? const CarregamentoPagina()
                  : _erro != null
                      ? EstadoPagina(
                          titulo: 'Não foi possível abrir o painel',
                          mensagem: _erro!,
                          acao: 'Tentar novamente',
                          onPressed: _carregar)
                      : ListView(padding: const EdgeInsets.all(24), children: [
                          Text(titulo,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          Text(
                              _ano == null
                                  ? 'Defina o ano letivo atual para começar.'
                                  : 'Ano letivo ${_ano!['ano']}',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 32),
                          Text('Organização do ano',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          Text(_ano == null
                              ? 'Nenhum ano atual definido'
                              : _configurado
                                  ? 'Etapas, pontos e critérios configurados'
                                  : 'Ano letivo ainda não configurado'),
                          const SizedBox(height: 16),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                  onPressed: () => _abrir(_ano == null
                                      ? AppRoutes.anosLetivos
                                      : AppRoutes.configEtapas),
                                  icon:
                                      const Icon(Icons.calendar_month_outlined),
                                  label: Text(_ano == null
                                      ? 'Criar ano letivo'
                                      : _configurado
                                          ? 'Revisar configuração'
                                          : 'Configurar ano letivo'))),
                          const Divider(height: 48),
                          Text('Equipe e turmas',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          _tarefa(
                              'Professores',
                              '${_resumo['total_professores'] ?? 0} cadastrados · ${_resumo['convites_pendentes'] ?? 0} com convite pendente',
                              Icons.person_outline,
                              AppRoutes.listaProfessores),
                          const SizedBox(height: 16),
                          _tarefa(
                              'Turmas e alunos',
                              '${_resumo['total_turmas'] ?? 0} turmas · ${_resumo['total_alunos'] ?? 0} alunos',
                              Icons.class_outlined,
                              AppRoutes.gerenciarTurmas),
                          const SizedBox(height: 16),
                          _tarefa(
                              'Vincular professores',
                              'Escolha as turmas de cada professor',
                              Icons.link,
                              AppRoutes.listaTurmasProfessor),
                          const Divider(height: 48),
                          _tarefa(
                              'Anos letivos',
                              'Planejar, definir o atual e encerrar anos',
                              Icons.event_note_outlined,
                              AppRoutes.anosLetivos),
                        ]))),
    );
  }

  Widget _tarefa(
          String titulo, String descricao, IconData icone, String rota) =>
      MenuCard(
          titulo: titulo,
          descricao: descricao,
          icone: icone,
          onTap: () => _abrir(rota));
}
