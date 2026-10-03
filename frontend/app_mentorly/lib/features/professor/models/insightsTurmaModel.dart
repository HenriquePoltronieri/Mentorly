class PontoAtencaoIa {
  final String titulo;
  final String evidencia;
  final String sugestao;

  const PontoAtencaoIa({
    required this.titulo,
    required this.evidencia,
    required this.sugestao,
  });

  factory PontoAtencaoIa.fromJson(Map<String, dynamic> json) {
    return PontoAtencaoIa(
      titulo: json['titulo']?.toString() ?? '',
      evidencia: json['evidencia']?.toString() ?? '',
      sugestao: json['sugestao']?.toString() ?? '',
    );
  }
}

class InsightsTurmaModel {
  final String turma;
  final int anoLetivo;
  final String etapa;
  final String modelo;
  final String resumo;
  final List<String> pontosPositivos;
  final List<PontoAtencaoIa> pontosAtencao;
  final List<String> sugestoesGerais;

  const InsightsTurmaModel({
    required this.turma,
    required this.anoLetivo,
    required this.etapa,
    required this.modelo,
    required this.resumo,
    required this.pontosPositivos,
    required this.pontosAtencao,
    required this.sugestoesGerais,
  });

  static List<String> _textos(dynamic valor) {
    if (valor is! List) return const [];
    return valor.map((item) => item.toString()).toList(growable: false);
  }

  factory InsightsTurmaModel.fromJson(Map<String, dynamic> json) {
    final contexto = (json['contexto'] as Map?)?.cast<String, dynamic>() ?? {};
    final insights = (json['insights'] as Map?)?.cast<String, dynamic>() ?? {};
    final pontos = (insights['pontosAtencao'] as List?) ?? const [];
    return InsightsTurmaModel(
      turma: contexto['turma']?.toString() ?? '',
      anoLetivo: (contexto['anoLetivo'] as num?)?.toInt() ?? 0,
      etapa: contexto['etapa']?.toString() ?? '',
      modelo: json['modelo']?.toString() ?? '',
      resumo: insights['resumo']?.toString() ?? '',
      pontosPositivos: _textos(insights['pontosPositivos']),
      pontosAtencao: pontos
          .whereType<Map>()
          .map((item) => PontoAtencaoIa.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      sugestoesGerais: _textos(insights['sugestoesGerais']),
    );
  }
}
