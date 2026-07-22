import '../../features/coordenacao/models/etapaModel.dart';
import '../../features/professor/models/notaModel.dart';

// Calcula a nota final do aluno de acordo com a configuracao da escola
// (nota minima e maxima definidas pela coordenacao pra cada etapa)
class GradeCalculator {
  // Media das notas convertida pra escala de 0 ate a notaMaxima da etapa
  static double calcularMediaEtapa(List<NotaModel> notas, EtapaModel etapa) {
    if (notas.isEmpty) return 0;

    final notaMaxima = etapa.notaMaxima ?? 10;

    double somaConvertida = 0;
    for (final nota in notas) {
      final proporcao =
          nota.valorTotal == 0 ? 0.0 : nota.valorObtido / nota.valorTotal;
      somaConvertida += proporcao * notaMaxima;
    }

    return somaConvertida / notas.length;
  }

  static bool aprovado(double media, EtapaModel etapa) {
    final notaMinima = etapa.notaMinima ?? 0;
    return media >= notaMinima;
  }

  // Identifica os alunos com media abaixo da nota minima (alunos em risco)
  static List<String> alunosEmRisco(
    Map<String, double> mediaPorAluno,
    EtapaModel etapa,
  ) {
    final notaMinima = etapa.notaMinima ?? 0;
    return mediaPorAluno.entries
        .where((entrada) => entrada.value < notaMinima)
        .map((entrada) => entrada.key)
        .toList();
  }
}