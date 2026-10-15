import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/apiService.dart';
import '../../../core/services/authService.dart';
import '../../../core/widgets/identidade_visual.dart';

class ProfessorScaffold extends StatelessWidget {
  final String aba;
  final Widget body;
  final Widget? floatingActionButton;
  const ProfessorScaffold(
      {super.key,
      required this.aba,
      required this.body,
      this.floatingActionButton});
  static const _rotas = [
    AppRoutes.dashboard,
    AppRoutes.listaTurmas,
    AppRoutes.listaAtividades
  ];
  static const _abas = ['dashboard', 'turmas', 'atividades'];
  static const _titulos = ['Início', 'Minhas turmas', 'Atividades'];
  void _abrir(BuildContext context, int index) {
    if (_abas[index] != aba) {
      Navigator.pushReplacementNamed(context, _rotas[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final index = _abas.indexOf(aba).clamp(0, 2);
    final nome = ApiService().usuario?['nome']?.toString() ?? 'Professor';
    final conta = PopupMenuButton<String>(
      tooltip: 'Minha conta',
      onSelected: (_) async {
        await AuthService().sair();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.perfilSelection, (_) => false);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(nome)),
        const PopupMenuItem(value: 'sair', child: Text('Sair'))
      ],
      icon: const Icon(Icons.account_circle_outlined),
    );
    final conteudo = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: desktop
            ? Text(_titulos[index])
            : const MarcaMentorly(compacta: true),
        actions: [conta, const SizedBox(width: 16)],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => _abrir(context, i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard),
                    label: 'Início'),
                NavigationDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: 'Turmas'),
                NavigationDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: 'Atividades'),
              ],
            ),
    );
    if (!desktop) return conteudo;
    return Scaffold(
        body: Row(children: [
      Container(
          width: 236,
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppCores.linha))),
          child: SafeArea(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: MarcaMentorly(compacta: true)),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('ESPAÇO DO PROFESSOR',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            color: AppCores.secundario))),
                const SizedBox(height: 16),
                for (var i = 0; i < 3; i++)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        selected: i == index,
                        selectedTileColor: const Color(0xFFEAF1FC),
                        selectedColor: AppCores.coordenacao,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        leading: Icon([
                          Icons.space_dashboard_outlined,
                          Icons.groups_outlined,
                          Icons.assignment_outlined
                        ][i]),
                        title: Text(_titulos[i]),
                        onTap: () => _abrir(context, i),
                      )),
                const Spacer(),
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.chatIa),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Assistente'))),
                const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Text('Mais tempo para ensinar.',
                        style: TextStyle(
                            fontSize: 12, color: AppCores.secundario))),
              ]))),
      Expanded(child: conteudo),
    ]));
  }
}
