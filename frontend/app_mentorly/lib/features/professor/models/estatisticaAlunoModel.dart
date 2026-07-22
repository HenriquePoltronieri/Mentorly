// Estatisticas de um aluno especifico, usadas no grafico da tela de detalhes
class EstatisticaAlunoModel {
  final String alunoId;
  final List<double> notas;
  final double media;
  final double percentualConclusao;
  final bool emRisco;

  EstatisticaAlunoModel({
    required this.alunoId,
    required this.notas,
    required this.media,
    required this.percentualConclusao,
    this.emRisco = false,
  });

  factory EstatisticaAlunoModel.fromJson(Map<String, dynamic> json) {
    return EstatisticaAlunoModel(
      alunoId: json['alunoId'].toString(),
      notas: List<double>.from(
        (json['notas'] ?? []).map((n) => n.toDouble()),
      ),
      media: (json['media'] ?? 0).toDouble(),
      percentualConclusao: (json['percentualConclusao'] ?? 0).toDouble(),
      emRisco: json['emRisco'] ?? false,
    );
  }
}
