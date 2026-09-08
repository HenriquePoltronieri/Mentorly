// Turma = entidade Class do backend (tabela "classes").
// O JSON real da API vem em ingles:
//   { "id": 1, "name": "...", "description": "...", "created_at": "...", "updated_at": "..." }
// O app continua usando nomes em portugues; o mapeamento fica no fromJson/toJson.
class TurmaModel {
  final String id;
  final String nome; // <- name
  final String descricao; // <- description

  // Campos usados pelas telas antigas de professor/alunos. A API de turmas
  // nao devolve esses dados, entao ficam vazios. Mantidos apenas para nao
  // quebrar aquelas telas, que estao fora do escopo desta etapa.
  final String disciplina;
  final String turno;
  final String professorId;

  // Ano letivo da turma. Nulo enquanto a Coordenacao nao informar - quem
  // precisa do ano (as etapas configuradas) cai no ano corrente.
  final int? anoLetivo;

  TurmaModel({
    required this.id,
    required this.nome,
    this.descricao = '',
    this.disciplina = '',
    this.turno = '',
    this.professorId = '',
    this.anoLetivo,
  });

  factory TurmaModel.fromJson(Map<String, dynamic> json) {
    return TurmaModel(
      id: (json['id'] ?? '').toString(),
      nome: json['name'] ?? '',
      descricao: json['description'] ?? '',
      disciplina: json['disciplina'] ?? '',
      turno: json['turno'] ?? '',
      professorId: (json['professorId'] ?? '').toString(),
      anoLetivo: json['anoLetivo'] is int
          ? json['anoLetivo']
          : int.tryParse((json['anoLetivo'] ?? json['ano_letivo'] ?? '')
              .toString()),
    );
  }

  // Contrato que o Flask espera em POST/PUT /api/classes
  Map<String, dynamic> toJson() => {
        'name': nome,
        'description': descricao,
      };
}
