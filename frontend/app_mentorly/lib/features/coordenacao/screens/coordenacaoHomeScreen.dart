import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/services/apiService.dart';
import '../../../core/services/authService.dart';

// Tela principal da coordenacao, depois do login. Funciona como um menu.
//
// O que a Coordenacao faz: cadastrar turmas, adicionar alunos nas turmas,
// vincular professores as turmas e configurar o ano letivo.
// O que ela NAO faz: criar atividade e lancar nota - isso e do Professor,
// e o backend recusa (403) mesmo que a chamada seja feita na mao.
class CoordenacaoHomeScreen extends StatelessWidget {
  const CoordenacaoHomeScreen({super.key});

  Future<void> _sair(BuildContext context) async {
    await AuthService().sair();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.perfilSelection,
      (rota) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = ApiService().usuario?['nome'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel da Coordenação'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => _sair(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (nome != null && nome.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                nome,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
            subtitulo: 'Criar turmas, editar, excluir e gerenciar os alunos',
            icone: Icons.class_outlined,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.gerenciarTurmas);
            },
          ),
          _ItemMenu(
            titulo: 'Vincular Professores',
            subtitulo: 'Definir quais turmas cada professor leciona',
            icone: Icons.link,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.listaTurmasProfessor);
            },
          ),
          // As tres telas de configuracao formam UM fluxo com passos
          // encadeados (etapas -> notas -> criterios). Entrar direto no
          // passo 2 ou 3 deixava a tela sem as etapas carregadas, entao o
          // menu agora tem uma unica porta de entrada: o passo 1.
          _ItemMenu(
            titulo: 'Configurar Ano Letivo',
            subtitulo: 'Etapas, notas de aprovação e critérios de avaliação',
            icone: Icons.calendar_month_outlined,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.configEtapas);
            },
          ),
          _ItemMenu(
            titulo: 'Buscar Atividades',
            subtitulo: 'Consultar as atividades criadas pelos professores',
            icone: Icons.search,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.buscarAtividades);
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
