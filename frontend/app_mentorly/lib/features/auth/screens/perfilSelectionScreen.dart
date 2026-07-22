import 'package:flutter/material.dart';
import '../../../app/routes.dart';

// tela inicial do app, onde o usuario escolhe se é coordenacao ou professor
class PerfilSelectionScreen extends StatelessWidget {
  const PerfilSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // logo / nome do app
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3DDC97),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFF0D1B2A)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mentorly',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              const Text(
                'Quem é você?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha seu perfil para continuar',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 40),

              // card coordenacao
              _PerfilCard(
                titulo: 'Coordenação',
                subtitulo: 'Gerencie turmas, professores e critérios de avaliação',
                icone: Icons.admin_panel_settings_rounded,
                corIcone: const Color(0xFF3DDC97),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.login);
                },
              ),

              const SizedBox(height: 20),

              // card professor
              _PerfilCard(
                titulo: 'Professor',
                subtitulo: 'Acompanhe turmas, lance notas e atividades',
                icone: Icons.person_rounded,
                corIcone: const Color(0xFFFFB84D),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.professorLogin);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// card reutilizavel de selecao de perfil
class _PerfilCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color corIcone;
  final VoidCallback onTap;

  const _PerfilCard({
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.corIcone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: corIcone.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icone, color: corIcone, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}