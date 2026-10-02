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

  // Ano letivo da turma: um dos anos cadastrados pela escola. Desde o Marco 6
  // toda turma tem ano (o backend nao aceita turma sem ele); o campo continua
  // anulavel so por causa de respostas antigas ou incompletas.
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

  // Texto curto do ano para listas ("Ano letivo 2026"); vazio se nao houver.
  String get rotuloAno => anoLetivo == null ? '' : 'Ano letivo $anoLetivo';

  // Contrato que o Flask espera em POST/PUT /api/classes
  Map<String, dynamic> toJson() => {
        'name': nome,
        'description': descricao,
      };
}
