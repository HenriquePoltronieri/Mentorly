// Atividade = entidade Activity do backend (tabela "activities").
// O JSON real da API vem em ingles:
//   { "id": 1, "title": "...", "description": "...", "class_id": 1,
//     "due_date": "...", "created_at": "...", "updated_at": "..." }
// A procedure de busca (sp_buscar_atividades) manda tambem "class_name".
// O app continua usando nomes em portugues; o mapeamento fica no fromJson/toJson.
class AtividadeModel {
  final String id;
  final String nome; // <- title
  final String descricao; // <- description
  final String turmaId; // <- class_id
  final String dataEntrega; // <- due_date (ISO, ou vazio)
  final String turmaNome; // <- class_name (so vem na busca por procedure)

  // Campos usados pela tela antiga de lancamento de notas. A API de atividades
  // nao devolve esses dados, entao ficam com o valor padrao. Mantidos apenas
  // para nao quebrar aquela tela, que esta fora do escopo desta etapa.
  final String tipo;
  final int etapa;
  final double valor;

  AtividadeModel({
    required this.id,
    required this.nome,
    this.descricao = '',
    required this.turmaId,
    this.dataEntrega = '',
    this.turmaNome = '',
    this.tipo = '',
    this.etapa = 1,
    this.valor = 0,
  });

  factory AtividadeModel.fromJson(Map<String, dynamic> json) {
    return AtividadeModel(
      id: (json['id'] ?? '').toString(),
      nome: json['title'] ?? '',
      descricao: json['description'] ?? '',
      turmaId: (json['class_id'] ?? '').toString(),
      dataEntrega: json['due_date'] ?? '',
      turmaNome: json['class_name'] ?? '',
      tipo: json['tipo'] ?? '',
      etapa: json['etapa'] ?? 1,
      valor: (json['valor'] ?? 0).toDouble(),
    );
  }

  // Contrato que o Flask espera em POST/PUT /api/activities.
  // due_date so vai quando preenchida: string vazia o backend ignora.
  Map<String, dynamic> toJson() => {
        'title': nome,
        'description': descricao,
        'class_id': int.tryParse(turmaId) ?? turmaId,
        'due_date': dataEntrega,
      };
}
