// Criterio que a escola usa pra compor a nota final
// (Provas, Trabalhos, Comportamento, etc)
class CriterioAvaliacaoModel {
  final String id;
  final String nome;
  double peso;

  CriterioAvaliacaoModel({
    required this.id,
    required this.nome,
    this.peso = 0,
  });

  factory CriterioAvaliacaoModel.fromJson(Map<String, dynamic> json) {
    return CriterioAvaliacaoModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
      peso: (json['peso'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'peso': peso};
}
