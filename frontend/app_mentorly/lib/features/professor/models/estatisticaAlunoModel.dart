// Desempenho de um aluno, usado na tela de detalhes.
//
// Vem de GET /api/professor/alunos/{id}/estatisticas. Desde o Marco 2 o
// campo que importa e "etapas": o desempenho do aluno calculado pela
// regra central do backend (services/academico/calculo.py), ja
// ponderado pelos criterios e comparado com a nota minima de CADA etapa
// - nunca um numero calculado aqui no app.
class CriterioDesempenhoModel {
  final String criterio;
  final double? peso;
  final bool temAtividade;
  final double? pontosObtidos;
  final double? pontosPossiveis;
  final double? desempenhoPercentual;
  final double? contribuicao;
  final bool completo;

  CriterioDesempenhoModel({
    required this.criterio,
    this.peso,
    this.temAtividade = false,
    this.pontosObtidos,
    this.pontosPossiveis,
    this.desempenhoPercentual,
    this.contribuicao,
    this.completo = false,
  });

  factory CriterioDesempenhoModel.fromJson(Map<String, dynamic> json) {
    double? paraDouble(dynamic v) => v == null ? null : (v as num).toDouble();
    return CriterioDesempenhoModel(
      criterio: json['criterio'] ?? '',
      peso: paraDouble(json['peso']),
      temAtividade: json['tem_atividade'] ?? false,
      pontosObtidos: paraDouble(json['pontos_obtidos']),
      pontosPossiveis: paraDouble(json['pontos_possiveis']),
      desempenhoPercentual: paraDouble(json['desempenho_percentual']),
      contribuicao: paraDouble(json['contribuicao']),
      completo: json['completo'] ?? false,
    );
  }
}

// situacao: "adequado" | "abaixo_do_minimo" | "em_andamento" |
// "configuracao_invalida" - ver services/academico/calculo.py no backend
// para o significado exato de cada uma.
class EtapaDesempenhoModel {
  final int etapaId;
  final String etapa;
  final int? ordem;
  final double? notaMinima;
  final double? notaMaxima;
  final bool completo;
  final bool fechada;
  final String situacao;
  final String? mensagem;
  final double? notaCalculada;
  final double? percentual;
  final int totalAtividades;
  final int atividadesAvaliadas;
  final int atividadesSemNota;
  final List<CriterioDesempenhoModel> criterios;

  EtapaDesempenhoModel({
    required this.etapaId,
    required this.etapa,
    this.ordem,
    this.notaMinima,
    this.notaMaxima,
    this.completo = false,
    this.fechada = false,
    required this.situacao,
    this.mensagem,
    this.notaCalculada,
    this.percentual,
    this.totalAtividades = 0,
    this.atividadesAvaliadas = 0,
    this.atividadesSemNota = 0,
    this.criterios = const [],
  });

  bool get emRisco => situacao == 'abaixo_do_minimo';
  bool get configuracaoInvalida => situacao == 'configuracao_invalida';

  factory EtapaDesempenhoModel.fromJson(Map<String, dynamic> json) {
    double? paraDouble(dynamic v) => v == null ? null : (v as num).toDouble();
    return EtapaDesempenhoModel(
      etapaId: json['etapa_id'] as int,
      etapa: json['etapa'] ?? 'Etapa',
      ordem: json['ordem'] as int?,
      notaMinima: paraDouble(json['nota_minima']),
      notaMaxima: paraDouble(json['nota_maxima']),
      completo: json['completo'] ?? false,
      fechada: json['fechada'] ?? false,
      situacao: json['situacao'] ?? 'em_andamento',
      mensagem: json['mensagem'] as String?,
      notaCalculada: paraDouble(json['nota_calculada']),
      percentual: paraDouble(json['percentual']),
      totalAtividades: json['total_atividades'] ?? 0,
      atividadesAvaliadas: json['atividades_avaliadas'] ?? 0,
      atividadesSemNota: json['atividades_sem_nota'] ?? 0,
      criterios: ((json['criterios'] as List?) ?? [])
          .map((c) => CriterioDesempenhoModel.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Consolidado geral: media das etapas ja FECHADAS (ver calcular_consolidado_
// geral no backend). Sem etapa fechada ainda, situacao vem "em_andamento" -
// nunca um numero inventado.
class ConsolidadoModel {
  final String situacao;
  final double? percentual;
  final int etapasConsideradas;
  final String? mensagem;

  ConsolidadoModel({
    required this.situacao,
    this.percentual,
    this.etapasConsideradas = 0,
    this.mensagem,
  });

  factory ConsolidadoModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ConsolidadoModel(situacao: 'em_andamento', etapasConsideradas: 0);
    }
    return ConsolidadoModel(
      situacao: json['situacao'] ?? 'em_andamento',
      percentual: (json['percentual'] as num?)?.toDouble(),
      etapasConsideradas: json['etapas_consideradas'] ?? 0,
      mensagem: json['mensagem'] as String?,
    );
  }
}

class EstatisticaAlunoModel {
  final String alunoId;
  final String nome;
  final String turma;
  final double? media; // media bruta, sem peso - so um numero rapido
  final int totalNotas;
  final List<EtapaDesempenhoModel> etapas;
  final int? etapaAtualId;
  final ConsolidadoModel consolidado;

  EstatisticaAlunoModel({
    required this.alunoId,
    this.nome = '',
    this.turma = '',
    this.media,
    this.totalNotas = 0,
    this.etapas = const [],
    this.etapaAtualId,
    ConsolidadoModel? consolidado,
  }) : consolidado = consolidado ?? ConsolidadoModel(situacao: 'em_andamento');

  factory EstatisticaAlunoModel.fromJson(Map<String, dynamic> json) {
    return EstatisticaAlunoModel(
      alunoId: (json['id'] ?? '').toString(),
      nome: json['nome'] ?? '',
      turma: json['turma'] ?? '',
      media: (json['media'] as num?)?.toDouble(),
      totalNotas: json['totalNotas'] ?? 0,
      etapas: ((json['etapas'] as List?) ?? [])
          .map((e) => EtapaDesempenhoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      etapaAtualId: json['etapaAtualId'] as int?,
      consolidado: ConsolidadoModel.fromJson(
        json['consolidado'] as Map<String, dynamic>?,
      ),
    );
  }
}
