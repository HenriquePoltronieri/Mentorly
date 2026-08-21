import 'package:flutter/material.dart';
import '../../../app/routes.dart';

// tela principal da coordenacao, depois do login
// funciona como um menu que leva pras outras secoes
class CoordenacaoHomeScreen extends StatelessWidget {
  const CoordenacaoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel da Coordenação')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ItemMenu(
            titulo: 'Professores',
            subtitulo: 'Cadastrar e listar professores',
            icone: Icons.person_outline,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.listaProfessores);
            },
          ),
          _ItemMenu(
            titulo: 'Gerenciar Turmas',
            subtitulo: 'Criar, editar, excluir turmas e ver suas atividades',
            icone: Icons.class_outlined,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.gerenciarTurmas);
            },
          ),
          _ItemMenu(
            titulo: 'Buscar Atividades',
            subtitulo: 'Filtrar atividades por termo e ordenação',
            icone: Icons.search,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.buscarAtividades);
            },
          ),
          _ItemMenu(
            titulo: 'Vincular Professores',
            subtitulo: 'Vincular professores às turmas',
            icone: Icons.link,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.listaTurmasProfessor);
            },
          ),
          _ItemMenu(
            titulo: 'Configurar Etapas',
            subtitulo: 'Definir etapas do ano letivo',
            icone: Icons.calendar_month_outlined,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.configEtapas);
            },
          ),
          _ItemMenu(
            titulo: 'Configurar Critérios',
            subtitulo: 'Definir critérios de avaliação',
            icone: Icons.rule_outlined,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.configCriterios);
            },
          ),
          _ItemMenu(
            titulo: 'Configurar Notas por Etapa',
            subtitulo: 'Definir pesos e notas de cada etapa',
            icone: Icons.grading_outlined,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.configNotasEtapa);
            },
          ),
          _ItemMenu(
            titulo: 'Relatório de Turmas',
            subtitulo: 'Turmas com contagem de atividades',
            icone: Icons.bar_chart_outlined,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.relatorioTurmas);
            },
          ),
        ],
      ),
    );
  }
}

// item reutilizavel do menu
class _ItemMenu extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icone, size: 32),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}