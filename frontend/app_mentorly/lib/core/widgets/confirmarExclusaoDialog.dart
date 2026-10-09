import 'package:flutter/material.dart';

// Avisos de impacto das exclusoes destrutivas. Cada texto descreve o que o
// banco realmente faz (ON DELETE CASCADE em schema.sql):
//   turma     -> alunos, atividades, notas e vinculos de professor da turma
//   atividade -> notas da atividade
//   aluno     -> notas e historico de turmas do aluno
// "Pode excluir" na turma porque o backend ainda pode recusar (409) quando ha
// historico protegido; a mensagem amigavel dele aparece depois, na tela.
class AvisosDeExclusao {
  static const String turma =
      'Esta ação pode excluir alunos, atividades e notas vinculados a esta '
      'turma e não pode ser desfeita.';
  static const String atividade =
      'As notas vinculadas a esta atividade também serão excluídas. '
      'Esta ação não pode ser desfeita.';
  static const String aluno =
      'As notas e o histórico de turmas deste aluno também serão excluídos. '
      'Esta ação não pode ser desfeita.';
}

// Confirmacao padrao das exclusoes destrutivas: mesmo AlertDialog de antes
// (Cancelar / Excluir em vermelho), agora com o impacto escrito.
// Devolve true so quando o usuario confirma.
Future<bool> confirmarExclusao(
  BuildContext context, {
  required String titulo,
  required String nome,
  required String aviso,
}) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text('"$nome"\n\n$aviso\n\nDeseja continuar?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(contexto, true),
          child: const Text('Excluir', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmou == true;
}
