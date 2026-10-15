import 'package:flutter/material.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../widgets/estatisticas_view.dart';
import 'alunoDetailScreen.dart';
import '../../../../app/routes.dart';

class EstatisticasAlunoScreen extends StatelessWidget {
  const EstatisticasAlunoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final aluno =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final turmaId = int.tryParse('${aluno?['turma_id']}');
    final alunoId = int.tryParse('${aluno?['id']}');
    if (turmaId == null || alunoId == null) return const AlunoDetailScreen();
    return Scaffold(
        appBar: AppBar(
            title: Text(aluno?['nome']?.toString() ?? 'Estatísticas do aluno'),
            actions: [
              IconButton(
                  tooltip: 'Registrar acompanhamento',
                  icon: const Icon(Icons.event_note_outlined),
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.acompanhamentos,
                      arguments: aluno)),
              IconButton(
                  tooltip: 'Desempenho e plano de recuperação',
                  icon: const Icon(Icons.grading),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(arguments: aluno),
                          builder: (_) => const AlunoDetailScreen())))
            ]),
        body: ConteudoPagina(
            vidro: false,
            child: EstatisticasView(turmaId: turmaId, alunoId: alunoId)));
  }
}
