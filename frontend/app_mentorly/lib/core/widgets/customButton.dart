import 'package:flutter/material.dart';

// Botao padrao usado em quase todas as telas
class CustomButton extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  final bool carregando;

  const CustomButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: carregando ? null : onPressed,
      child: carregando
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(texto),
    );
  }
}
