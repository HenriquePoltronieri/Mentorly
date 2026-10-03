class ProfessorModel {
  static const String ativo = 'ativo';
  static const String convitePendente = 'convite_pendente';
  static const String desativado = 'desativado';

  final int id;
  final String nome;
  final String email;
  final String? disciplina;
  final bool habilitado;
  final bool senhaConfigurada;
  final String status;
  final int totalTurmas;

  const ProfessorModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.disciplina,
    required this.habilitado,
    required this.senhaConfigurada,
    required this.status,
    required this.totalTurmas,
  });

  factory ProfessorModel.fromJson(Map<String, dynamic> json) {
    final habilitado = json['habilitado'] != false;
    final senhaConfigurada = json['senhaConfigurada'] == true || json['ativo'] == true;
    final status = json['status'] as String? ?? (habilitado
        ? (senhaConfigurada ? ativo : convitePendente)
        : desativado);
    return ProfessorModel(
      id: (json['id'] as num).toInt(),
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      disciplina: json['disciplina']?.toString(),
      habilitado: habilitado,
      senhaConfigurada: senhaConfigurada,
      status: status,
      totalTurmas: (json['totalTurmas'] as num?)?.toInt() ?? 0,
    );
  }

  String get rotuloStatus => switch (status) {
        desativado => 'Desativado',
        convitePendente => 'Convite pendente',
        _ => 'Ativo',
      };
}
