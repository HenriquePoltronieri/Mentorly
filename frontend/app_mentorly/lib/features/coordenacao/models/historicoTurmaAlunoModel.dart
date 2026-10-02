class HistoricoTurmaAlunoModel {
  final int id;
  final int turmaId;
  final String turma;
  final int anoLetivo;
  final String dataInicio;
  final String? dataFim;
  final String? motivo;

  const HistoricoTurmaAlunoModel({
    required this.id,
    required this.turmaId,
    required this.turma,
    required this.anoLetivo,
    required this.dataInicio,
    this.dataFim,
    this.motivo,
  });

  bool get atual => dataFim == null;

  factory HistoricoTurmaAlunoModel.fromJson(Map<String, dynamic> json) {
    return HistoricoTurmaAlunoModel(
      id: json['id'] as int,
      turmaId: json['turmaId'] as int,
      turma: (json['turma'] ?? '').toString(),
      anoLetivo: json['anoLetivo'] as int,
      dataInicio: (json['dataInicio'] ?? '').toString(),
      dataFim: json['dataFim']?.toString(),
      motivo: json['motivo']?.toString(),
    );
  }
}
