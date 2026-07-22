import 'package:flutter/material.dart';
import '../models/professorModel.dart';

// Card usado na lista de professores
class ProfessorCard extends StatelessWidget {
  final ProfessorModel professor;
  final VoidCallback onTap;

  const ProfessorCard({
    super.key,
    required this.professor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text('${professor.nome} - ${professor.materia}'),
        subtitle: Text(professor.email),
        onTap: onTap,
      ),
    );
  }
}
