class AlunoModel {
  final String id;
  final String nome;
  final String turmaId;

  AlunoModel({
    required this.id,
    required this.nome,
    required this.turmaId,
  });

  factory AlunoModel.fromJson(Map<String, dynamic> json) {
    return AlunoModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
      turmaId: json['turmaId'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'turmaId': turmaId,
      };
}
