import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/menu_card.dart';
import '../../../core/widgets/identidade_visual.dart';

class PerfilSelectionScreen extends StatelessWidget {
  const PerfilSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) => TelaAcesso(
      perfil: PerfilVisual.neutro,
      largura: 500,
      child: VidroCard(
          formas: true,
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Qual perfil se encaixa melhor pra você?',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                _perfil(
                    context,
                    'Coordenação',
                    'Professores, turmas e ano letivo',
                    Icons.account_tree_outlined,
                    AppRoutes.login),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Ou', textAlign: TextAlign.center)),
                _perfil(context, 'Professor', 'Atividades, notas e desempenho',
                    Icons.co_present_outlined, AppRoutes.professorLogin),
                const SizedBox(height: 24),
                TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.admin),
                  child: const Text('Administração do Mentorly')),
              ])));
  Widget _perfil(BuildContext context, String titulo, String descricao,
          IconData icone, String rota) =>
      MenuCard(
          titulo: titulo,
          descricao: descricao,
          icone: icone,
          onTap: () => Navigator.pushNamed(context, rota));
}
