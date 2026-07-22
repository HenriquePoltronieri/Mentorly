// representa uma etapa do ano letivo (ex: 1º Bimestre, 2º Bimestre...)
class EtapaModel {
  final int numero;
  double? notaMinima;
  double? notaMaxima;

  EtapaModel({
    required this.numero,
    this.notaMinima,
    this.notaMaxima,
  });

  factory EtapaModel.fromJson(Map<String, dynamic> json) {
    return EtapaModel(
      numero: json['numero'],
      notaMinima: (json['notaMinima'] as num?)?.toDouble(),
      notaMaxima: (json['notaMaxima'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'notaMinima': notaMinima,
      'notaMaxima': notaMaxima,
    };
  }
}