import 'package:flutter/material.dart';

// grafico de barras simples mostrando a evolucao das notas do aluno
// nao usa nenhuma biblioteca externa de graficos, so widgets do Flutter
class AlunoGraficoWidget extends StatelessWidget {
  final List<double> notas;
  final double notaMaxima;

  const AlunoGraficoWidget({
    super.key,
    required this.notas,
    this.notaMaxima = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (notas.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Nenhuma nota lançada ainda')),
      );
    }

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: notas.asMap().entries.map((entrada) {
          final indice = entrada.key;
          final nota = entrada.value;
          final proporcao = (nota / notaMaxima).clamp(0.0, 1.0);
          final cor = nota < notaMaxima * 0.5
              ? Colors.red
              : nota < notaMaxima * 0.7
                  ? Colors.orange
                  : Colors.green;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    nota.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 120 * proporcao,
                    decoration: BoxDecoration(
                      color: cor.withOpacity(0.8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ativ. ${indice + 1}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}