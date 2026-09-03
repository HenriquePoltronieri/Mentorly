// Criterio que a escola usa pra compor a nota final
// (Provas, Trabalhos, Comportamento, etc).
//
// O criterio pertence a uma etapa: a mesma escolha ("Provas") vira um
// registro em cada etapa do ano letivo, e por isso guardamos o etapaId.
class CriterioAvaliacaoModel {
  final String id;
  final String nome;
  final String? etapaId;
  double peso;
  double? notaMaxima;

  CriterioAvaliacaoModel({
    required this.id,
    required this.nome,
    this.etapaId,
    this.peso = 0,
    this.notaMaxima,
  });

  factory CriterioAvaliacaoModel.fromJson(Map<String, dynamic> json) {
    return CriterioAvaliacaoModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
      etapaId: json['etapa_id']?.toString(),
      peso: (json['peso'] ?? 0).toDouble(),
      notaMaxima: (json['nota_maxima'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'etapa_id': etapaId,
        'peso': peso,
        'nota_maxima': notaMaxima,
      };
}
