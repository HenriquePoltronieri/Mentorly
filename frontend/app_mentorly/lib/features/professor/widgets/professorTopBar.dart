import 'package:flutter/material.dart';
import '../../../app/routes.dart';

// barra de navegacao superior usada nas telas principais do professor
// (Dashboard, Turmas, Atividades) - fica fixa no topo
class ProfessorTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String abaAtiva; // 'dashboard', 'turmas' ou 'atividades'
  final String? emailProfessor;

  const ProfessorTopBar({
    super.key,
    required this.abaAtiva,
    this.emailProfessor,
  });

  void _navegar(BuildContext context, String rota, String aba) {
    if (aba == abaAtiva) return; // ja esta nessa aba
    Navigator.pushReplacementNamed(context, rota);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.auto_stories_outlined, size: 26),
              const SizedBox(width: 24),
              _AbaBotao(
                titulo: 'Dashboard',
                selecionada: abaAtiva == 'dashboard',
                onTap: () => _navegar(context, AppRoutes.dashboard, 'dashboard'),
              ),
              const SizedBox(width: 8),
              _AbaBotao(
                titulo: 'Turmas',
                selecionada: abaAtiva == 'turmas',
                onTap: () => _navegar(context, AppRoutes.listaTurmas, 'turmas'),
              ),
              const SizedBox(width: 8),
              _AbaBotao(
                titulo: 'Atividades',
                selecionada: abaAtiva == 'atividades',
                onTap: () => _navegar(context, AppRoutes.listaAtividades, 'atividades'),
              ),
              const Spacer(),
              const Icon(Icons.account_circle_outlined, size: 22),
              const SizedBox(width: 6),
              Text(
                emailProfessor ?? '',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _AbaBotao extends StatelessWidget {
  final String titulo;
  final bool selecionada;
  final VoidCallback onTap;

  const _AbaBotao({
    required this.titulo,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionada ? const Color(0xFFDCEBFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          titulo,
          style: TextStyle(
            fontWeight: selecionada ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}