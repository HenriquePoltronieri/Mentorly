class TurmaModel {
  final String id;
  final String nome;
  final String disciplina;
  final String turno;
  final String professorId;

  TurmaModel({
    required this.id,
    required this.nome,
    this.disciplina = '',
    this.turno = '',
    required this.professorId,
  });

  factory TurmaModel.fromJson(Map<String, dynamic> json) {
    return TurmaModel(
      id: json['id'].toString(),
      nome: json['nome'] ?? '',
      disciplina: json['disciplina'] ?? '',
      turno: json['turno'] ?? '',
      professorId: json['professorId'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'disciplina': disciplina,
        'turno': turno,
        'professorId': professorId,
      };
}
