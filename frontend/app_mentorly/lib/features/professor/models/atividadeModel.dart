// Atividade = tabela "atividade" do backend.
// O JSON da API mistura chaves em ingles (herdadas do contrato antigo) com
// as novas em portugues:
//   { "id": 1, "title": "...", "description": "...", "class_id": 1,
//     "due_date": "...", "etapa_id": 3, "etapa_nome": "1º Bimestre",
//     "criterio_id": 7, "criterio_nome": "Prova", "nota_maxima": 20.0 }
// A procedure de busca (sp_buscar_atividades) manda tambem "class_name".
// O app usa nomes em portugues; o mapeamento fica no fromJson/toJson.
class AtividadeModel {
  final String id;
  final String nome; // <- title
  final String descricao; // <- description
  final String turmaId; // <- class_id
  final String dataEntrega; // <- due_date (ISO, ou vazio)
  final String turmaNome; // <- class_name (so vem na busca por procedure)

  // Configuracao academica da atividade. Nulos so em atividade legada,
  // criada antes de etapa/criterio/valor virarem obrigatorios.
  final int? etapaId;
  final String etapaNome;
  final int? criterioId;
  final String criterioNome;
  final double? notaMaxima; // <- nota_maxima: quanto a atividade vale

  AtividadeModel({
    required this.id,
    required this.nome,
    this.descricao = '',
    required this.turmaId,
    this.dataEntrega = '',
    this.turmaNome = '',
    this.etapaId,
    this.etapaNome = '',
    this.criterioId,
    this.criterioNome = '',
    this.notaMaxima,
  });

  // Atividade criada antes do Marco 1: nao da para lancar nota nela
  // enquanto o professor nao editar e informar quanto ela vale.
  bool get configuracaoCompleta =>
      etapaId != null && criterioId != null && notaMaxima != null;

  factory AtividadeModel.fromJson(Map<String, dynamic> json) {
    return AtividadeModel(
      id: (json['id'] ?? '').toString(),
      nome: json['title'] ?? json['titulo'] ?? '',
      descricao: json['description'] ?? json['descricao'] ?? '',
      turmaId: (json['class_id'] ?? json['turma_id'] ?? '').toString(),
      dataEntrega: json['due_date'] ?? json['data_entrega'] ?? '',
      turmaNome: json['class_name'] ?? json['turma_nome'] ?? '',
      etapaId: _paraInt(json['etapa_id']),
      etapaNome: json['etapa_nome'] ?? '',
      criterioId: _paraInt(json['criterio_id']),
      criterioNome: json['criterio_nome'] ?? '',
      notaMaxima: _paraDouble(json['nota_maxima']),
    );
  }

  // Contrato que o Flask espera em POST/PUT /api/activities.
  // due_date so vai quando preenchida: string vazia o backend ignora.
  Map<String, dynamic> toJson() => {
        'title': nome,
        'description': descricao,
        'class_id': int.tryParse(turmaId) ?? turmaId,
        'due_date': dataEntrega,
        'etapa_id': etapaId,
        'criterio_id': criterioId,
        'nota_maxima': notaMaxima,
      };

  // O MySQL devolve DECIMAL como numero, mas um id pode chegar como String
  // dependendo de quem serializou. Os dois casos caem aqui.
  static int? _paraInt(dynamic bruto) {
    if (bruto == null) return null;
    if (bruto is int) return bruto;
    if (bruto is num) return bruto.toInt();
    return int.tryParse(bruto.toString());
  }

  static double? _paraDouble(dynamic bruto) {
    if (bruto == null) return null;
    if (bruto is num) return bruto.toDouble();
    return double.tryParse(bruto.toString().replaceAll(',', '.'));
  }
}
