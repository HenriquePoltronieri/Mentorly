import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../services/apiService.dart';
import '../services/authService.dart';
import 'identidade_visual.dart';

class BarraMentorly extends StatelessWidget implements PreferredSizeWidget {
  final bool professor;
  final String aba;
  final String? titulo;
  final String? email;
  final VoidCallback? onVoltar;
  const BarraMentorly(
      {super.key,
      required this.professor,
      required this.aba,
      this.titulo,
      this.email,
      this.onVoltar});
  Map<String, (String, String)> get abas => professor
      ? {
          'dashboard': ('Início', AppRoutes.dashboard),
          'turmas': ('Turmas', AppRoutes.listaTurmas),
          'atividades': ('Atividades', AppRoutes.listaAtividades),
        }
      : {
          'inicio': ('Início', AppRoutes.coordenacaoHome),
          'professores': ('Professores', AppRoutes.listaProfessores),
          'turmas': ('Turmas', AppRoutes.gerenciarTurmas),
          'ano': ('Ano letivo', AppRoutes.anosLetivos),
        };
  void abrir(BuildContext context, String chave) {
    if (chave != aba || titulo != null) {
      Navigator.pushNamed(context, abas[chave]!.$2);
    }
  }

  Future<void> sair(BuildContext context) async {
    await AuthService().sair();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.perfilSelection, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, tamanho) {
        final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
        final compacto = tamanho.maxWidth < (professor ? 760 : 1000) * escala;
        final tablet = !compacto && tamanho.maxWidth < 1000;
        final usuario = ApiService().usuario;
        final identificacao = email ??
            usuario?['email']?.toString() ??
            usuario?['nome']?.toString() ??
            (professor ? 'Professor' : 'Coordenação');
        return AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: compacto || tablet ? 4 : 24,
          title: Row(children: [
            if (titulo != null)
              BackButton(
                  onPressed: onVoltar ??
                      () => Navigator.canPop(context)
                          ? Navigator.pop(context)
                          : Navigator.pushNamed(context, abas.values.first.$2)),
            MarcaMentorly(
                compacta: true, somenteIcone: tablet || tamanho.maxWidth < 390),
            if (!compacto) ...[
              const Spacer(),
              ...abas.entries.map((e) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: tablet ? 0 : 4),
                  child: TextButton(
                      style: TextButton.styleFrom(
                          backgroundColor: e.key == aba
                              ? AppCores.azulForma
                              : Colors.transparent),
                      onPressed: () => abrir(context, e.key),
                      child: Text(e.value.$1)))),
              const Spacer(),
            ],
          ]),
          actions: [
            if (compacto)
              PopupMenuButton<String>(
                  tooltip: 'Navegar',
                  icon: const Icon(Icons.menu),
                  onSelected: (valor) => abrir(context, valor),
                  itemBuilder: (_) => abas.entries
                      .map((e) =>
                          PopupMenuItem(value: e.key, child: Text(e.value.$1)))
                      .toList()),
            PopupMenuButton<String>(
                tooltip: 'Conta',
                onSelected: (valor) => valor == 'acesso'
                    ? Navigator.pushNamed(context, AppRoutes.acesso)
                    : sair(context),
                itemBuilder: (_) => [
                      const PopupMenuItem(value: 'acesso', child: Text('Plano e acesso da escola')),
                      PopupMenuItem(
                          value: 'sair',
                          child: Row(children: [
                            const Icon(Icons.logout),
                            const SizedBox(width: 12),
                            const Text('Sair')
                          ]))
                    ],
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.account_circle_outlined),
                      if (!compacto) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: tablet ? 160 : 200),
                            child: Text(identificacao,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)))
                      ],
                    ]))),
            const SizedBox(width: 12),
          ],
          bottom: PreferredSize(
              preferredSize: Size.fromHeight(titulo == null ? 1 : 37),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titulo != null)
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
                          child: Text(titulo!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500))),
                    const Divider(height: 1),
                  ])),
        );
      });
  @override
  Size get preferredSize => Size.fromHeight(titulo == null ? 73 : 109);
}
