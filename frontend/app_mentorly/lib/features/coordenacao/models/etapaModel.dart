// representa uma etapa do ano letivo (ex: 1º Bimestre, 2º Bimestre...)
class EtapaModel {
  String? id;
  final String nome;
  final int numero;
  final int anoLetivo;
  final String? dataInicio;
  final String? dataFim;
  final bool ativa;
  double? notaMinima;
  double? notaMaxima;

  EtapaModel({
    this.id,
    required this.nome,
    required this.numero,
    this.anoLetivo = 0,
    this.dataInicio,
    this.dataFim,
    this.ativa = true,
    this.notaMinima,
    this.notaMaxima,
  });

  factory EtapaModel.fromJson(Map<String, dynamic> json) {
    return EtapaModel(
      id: json['id']?.toString(),
      nome: json['nome'] ?? '',
      numero: json['numero'] ?? 0,
      anoLetivo: json['ano_letivo'] ?? 0,
      dataInicio: json['data_inicio'],
      dataFim: json['data_fim'],
      ativa: json['ativa'] ?? true,
      notaMinima: (json['nota_minima'] as num?)?.toDouble(),
      notaMaxima: (json['nota_maxima'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'numero': numero,
      'ano_letivo': anoLetivo,
      'data_inicio': dataInicio,
      'data_fim': dataFim,
      'ativa': ativa,
      'nota_minima': notaMinima,
      'nota_maxima': notaMaxima,
    };
  }
}