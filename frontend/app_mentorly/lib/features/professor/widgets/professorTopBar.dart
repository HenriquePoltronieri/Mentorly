import 'package:flutter/material.dart';
import '../../../core/widgets/barra_mentorly.dart';

class ProfessorTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String abaAtiva;
  final String? emailProfessor;
  const ProfessorTopBar(
      {super.key, required this.abaAtiva, this.emailProfessor});
  @override
  Widget build(BuildContext context) =>
      BarraMentorly(professor: true, aba: abaAtiva, email: emailProfessor);
  @override
  Size get preferredSize => const Size.fromHeight(73);
}
