import '../../features/coordenacao/models/etapaModel.dart';
import '../../features/professor/models/notaModel.dart';

// Calcula a nota final do aluno de acordo com a configuracao da escola
// (nota minima e maxima definidas pela coordenacao pra cada etapa)
class GradeCalculator {
  // Media das notas convertida pra escala de 0 ate a notaMaxima da etapa
  static double calcularMediaEtapa(List<NotaModel> notas, EtapaModel etapa) {
    if (notas.isEmpty) return 0;

    final notaMaxima = etapa.notaMaxima ?? 10;

    // Converte cada nota para a escala da etapa. A referencia e a
    // notaMaxima da propria atividade; quando ela nao foi definida, a nota
    // ja esta na escala da etapa e entra direto.
    double somaConvertida = 0;
    int consideradas = 0;
    for (final nota in notas) {
      final valor = nota.valor;
      if (valor == null) continue; // aluno sem nota lancada nao entra na media

      final total = nota.notaMaxima;
      if (total == null || total == 0) {
        somaConvertida += valor;
      } else {
        somaConvertida += (valor / total) * notaMaxima;
      }
      consideradas++;
    }

    if (consideradas == 0) return 0;
    return somaConvertida / consideradas;
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