// representa uma nota lancada pelo professor numa atividade
class NotaModel {
  final int alunoId;
  final double valorObtido;
  final double valorTotal;

  NotaModel({
    required this.alunoId,
    required this.valorObtido,
    required this.valorTotal,
  });

  factory NotaModel.fromJson(Map<String, dynamic> json) {
    return NotaModel(
      alunoId: json['alunoId'],
      valorObtido: (json['valorObtido'] as num).toDouble(),
      valorTotal: (json['valorTotal'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alunoId': alunoId,
      'valorObtido': valorObtido,
      'valorTotal': valorTotal,
    };
  }
}