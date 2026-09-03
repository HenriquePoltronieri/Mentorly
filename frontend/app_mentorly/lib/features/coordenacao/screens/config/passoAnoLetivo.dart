import 'package:flutter/material.dart';

// Indicador de progresso do fluxo de configuracao do ano letivo.
//
// As tres telas do fluxo eram praticamente identicas (mesmo cabecalho
// "Ola coordenacao", mesmo botao "Proximo"), entao a troca de tela nao era
// percebida como troca - dava a impressao de que o app tinha pulado
// sozinho. Este indicador deixa visivel em que passo o usuario esta.
class PassoAnoLetivo extends StatelessWidget {
  final int passoAtual;

  static const List<String> _rotulos = ['Etapas', 'Notas', 'Critérios'];

  const PassoAnoLetivo({super.key, required this.passoAtual});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    return Row(
      children: List.generate(_rotulos.length, (indice) {
        final numero = indice + 1;
        final concluido = numero < passoAtual;
        final atual = numero == passoAtual;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: concluido || atual
                        ? cor
                        : cor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$numero. ${_rotulos[indice]}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: atual ? FontWeight.w700 : FontWeight.w400,
                    color: concluido || atual ? cor : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
