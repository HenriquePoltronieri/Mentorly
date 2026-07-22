class AtividadeModel {
  final String id;
  final String nome;
  final String tipo;
  final int etapa;
  final double valor;
  final String turmaId;

  AtividadeModel({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.etapa,
    required this.valor,
    required this.turmaId,
  });

  factory AtividadeModel.fromJson(Map<String, dynamic> json) {
    return AtividadeModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      etapa: json['etapa'] ?? 1,
      valor: (json['valor'] ?? 0).toDouble(),
      turmaId: json['turmaId'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'tipo': tipo,
        'etapa': etapa,
        'valor': valor,
        'turmaId': turmaId,
      };
}
