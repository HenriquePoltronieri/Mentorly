// Sugestao de avaliacao devolvida pela IA (Marco 9C).
//
// E so uma SUGESTAO: nada daqui existe no banco. O Professor revisa e, se
// quiser, usa a nota sugerida para preencher o campo de nota; quem grava e o
// botao "Salvar notas" de sempre. O percentual vem calculado pelo backend.

class AvaliacaoCriterioIa {
  final String criterio;
  final String resultado; // atendido | atendido_parcialmente | nao_atendido
  final String evidencia;
  final String faltou;

  const AvaliacaoCriterioIa({
    required this.criterio,
    required this.resultado,
    this.evidencia = '',
    this.faltou = '',
  });

  String get rotuloResultado {
    switch (resultado) {
      case 'atendido':
        return 'Atendido';
      case 'atendido_parcialmente':
        return 'Parcialmente atendido';
      default:
        return 'Não atendido';
    }
  }

  factory AvaliacaoCriterioIa.fromJson(Map<String, dynamic> json) {
    return AvaliacaoCriterioIa(
      criterio: json['criterio']?.toString() ?? '',
      resultado: json['resultado']?.toString() ?? 'nao_atendido',
      evidencia: json['evidencia']?.toString() ?? '',
      faltou: json['faltou']?.toString() ?? '',
    );
  }
}

class CorrecaoSugeridaModel {
  final double notaSugerida;
  final double percentual;
  final double valorMaximo;
  final List<AvaliacaoCriterioIa> avaliacao;
  final List<String> pontosPositivos;
  final List<String> pontosMelhorar;
  final String justificativa;
  final String feedbackAluno;
  final String modelo;

  const CorrecaoSugeridaModel({
    required this.notaSugerida,
    required this.percentual,
    required this.valorMaximo,
    this.avaliacao = const [],
    this.pontosPositivos = const [],
    this.pontosMelhorar = const [],
    this.justificativa = '',
    this.feedbackAluno = '',
    this.modelo = '',
  });

  factory CorrecaoSugeridaModel.fromJson(Map<String, dynamic> json) {
    final sugestao =
        ((json['sugestao'] as Map?) ?? const {}).cast<String, dynamic>();
    double numero(dynamic bruto) => bruto is num ? bruto.toDouble() : 0;
    List<String> textos(String chave) => ((sugestao[chave] as List?) ?? const [])
        .map((item) => item.toString())
        .toList();

    return CorrecaoSugeridaModel(
      notaSugerida: numero(sugestao['notaSugerida']),
      percentual: numero(sugestao['percentual']),
      valorMaximo: numero(sugestao['valorMaximo']),
      avaliacao: ((sugestao['avaliacao'] as List?) ?? const [])
          .map((item) => AvaliacaoCriterioIa.fromJson(
              (item as Map).cast<String, dynamic>()))
          .toList(),
      pontosPositivos: textos('pontosPositivos'),
      pontosMelhorar: textos('pontosMelhorar'),
      justificativa: sugestao['justificativa']?.toString() ?? '',
      feedbackAluno: sugestao['feedbackAluno']?.toString() ?? '',
      modelo: json['modelo']?.toString() ?? '',
    );
  }
}
