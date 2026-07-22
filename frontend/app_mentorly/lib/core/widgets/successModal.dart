import 'package:flutter/material.dart';

// Modal de sucesso reaproveitado em Turma, Aluno, Atividade e Notas
// Uso: showDialog(context: context, builder: (_) => SuccessModal(mensagem: '...'));
class SuccessModal extends StatelessWidget {
  final String mensagem;

  const SuccessModal({super.key, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 40),
            SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Mostra o modal e fecha sozinho depois de alguns segundos
Future<void> mostrarSucesso(BuildContext context, String mensagem) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => SuccessModal(mensagem: mensagem),
  );
  await Future.delayed(Duration(seconds: 2));
  if (context.mounted) Navigator.of(context).pop();
}
