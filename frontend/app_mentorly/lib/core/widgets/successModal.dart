import 'dart:async';

import 'package:flutter/material.dart';

// Modal de sucesso reaproveitado em Turma, Aluno, Atividade e Notas.
//
// O modal se fecha SOZINHO, usando o proprio contexto do dialogo.
//
// Antes quem fechava era a funcao mostrarSucesso, com
// "await Future.delayed(...); if (context.mounted) Navigator.pop(context)",
// usando o context de quem chamou. Como as telas fecham o proprio modal
// (Navigator.pop) logo antes de mostrar o sucesso, esse context ja estava
// desmontado quando o delay terminava: o "context.mounted" dava false, o
// pop nunca acontecia e o modal de sucesso ficava preso na tela, bloqueando
// todo o resto (nem o Esc fechava, porque barrierDismissible e false).
class SuccessModal extends StatefulWidget {
  final String mensagem;
  final Duration duracao;

  const SuccessModal({
    super.key,
    required this.mensagem,
    this.duracao = const Duration(seconds: 2),
  });

  @override
  State<SuccessModal> createState() => _SuccessModalState();
}

class _SuccessModalState extends State<SuccessModal> {
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer(widget.duracao, _fechar);
  }

  void _fechar() {
    if (!mounted) return;
    final navegador = Navigator.of(context);
    if (navegador.canPop()) navegador.pop();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Tocar no modal fecha na hora, sem esperar o tempo acabar.
      child: InkWell(
        onTap: _fechar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 40),
              const SizedBox(height: 12),
              Text(widget.mensagem, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// Mostra o modal de sucesso. Ele se fecha sozinho depois de alguns segundos
// (ou quando a pessoa toca nele), entao pode ser chamado mesmo logo apos
// fechar outro dialogo.
Future<void> mostrarSucesso(
  BuildContext context,
  String mensagem, {
  Duration duracao = const Duration(seconds: 2),
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => SuccessModal(mensagem: mensagem, duracao: duracao),
  );
}
