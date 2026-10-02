// Nota de um aluno em uma atividade.
//
// Vem de GET /api/atividades/{id}/notas, que devolve TODOS os alunos da
// turma - quem ainda nao tem nota vem com valor nulo, pra tela conseguir
// listar a turma inteira.
class NotaModel {
  // Nulo quando o aluno ainda nao tem nota lancada nesta atividade (a
  // listagem traz a turma inteira, com ou sem nota - ver comentario
  // acima). So da pra excluir uma nota que ja tem id.
  final int? id;
  final int alunoId;
  final String alunoNome;
  final String matricula;
  final double? valor;
  final double? notaMaxima;
  final String? observacao;

  NotaModel({
    this.id,
    required this.alunoId,
    this.alunoNome = '',
    this.matricula = '',
    this.valor,
    this.notaMaxima,
    this.observacao,
  });

  bool get temNota => valor != null;

  factory NotaModel.fromJson(Map<String, dynamic> json) {
    double? paraDouble(dynamic bruto) =>
        bruto == null ? null : (bruto as num).toDouble();

    return NotaModel(
      id: json['id'] as int?,
      alunoId: json['alunoId'] is int
          ? json['alunoId'] as int
          : int.parse('${json['alunoId']}'),
      alunoNome: (json['aluno'] ?? '').toString(),
      matricula: (json['matricula'] ?? '').toString(),
      valor: paraDouble(json['valor']),
      notaMaxima: paraDouble(json['notaMaxima']),
      observacao: json['observacao'] as String?,
    );
  }

  // Contrato do POST /api/atividades/{id}/notas
  Map<String, dynamic> toJson() => {
        'aluno_id': alunoId,
        'valor': valor,
        if (observacao != null) 'observacao': observacao,
      };
}
