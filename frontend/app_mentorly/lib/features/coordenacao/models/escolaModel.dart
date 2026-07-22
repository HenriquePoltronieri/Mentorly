// Dados da escola cadastrados pela coordenacao
class EscolaModel {
  final String id;
  final String nome;

  EscolaModel({required this.id, required this.nome});

  factory EscolaModel.fromJson(Map<String, dynamic> json) {
    return EscolaModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome};
}
