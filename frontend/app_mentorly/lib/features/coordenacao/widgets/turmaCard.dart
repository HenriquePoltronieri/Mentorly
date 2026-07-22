import 'package:flutter/material.dart';
import '../models/turmaModel.dart';

// Card usado na lista de turmas
class TurmaCard extends StatelessWidget {
  final TurmaModel turma;
  final VoidCallback onTap;

  const TurmaCard({super.key, required this.turma, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.school_outlined),
        title: Text(turma.nome),
        subtitle: Text(turma.disciplina),
        onTap: onTap,
      ),
    );
  }
}
