import 'package:flutter/material.dart';

// Indicador de carregamento simples, usado enquanto espera resposta da API
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator());
  }
}
