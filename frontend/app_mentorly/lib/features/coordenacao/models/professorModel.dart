class ProfessorModel {
  final String id;
  final String nome;
  final String email;
  final String materia;

  ProfessorModel({
    required this.id,
    required this.nome,
    required this.email,
    this.materia = '',
  });

  factory ProfessorModel.fromJson(Map<String, dynamic> json) {
    return ProfessorModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      materia: json['materia'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'materia': materia,
      };
}
