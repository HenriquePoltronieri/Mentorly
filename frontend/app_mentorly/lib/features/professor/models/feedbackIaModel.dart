// Feedback e plano sugeridos pela IA para um aluno em uma etapa (Marco 9D).
//
// So leitura: nada daqui e gravado. O resultado OFICIAL (nota, percentual e
// situacao) vem do motor academico em `resultadoOficial`; a IA apenas
// interpreta esses numeros. O tipo de plano tambem e decidido pelo backend
// a partir da situacao oficial.

class PontoAtencaoFeedback {
  final String descricao;
  final String evidencia;

  const PontoAtencaoFeedback({required this.descricao, this.evidencia = ''});

  factory PontoAtencaoFeedback.fromJson(Map<String, dynamic> json) {
    return PontoAtencaoFeedback(
      descricao: json['descricao']?.toString() ?? '',
      evidencia: json['evidencia']?.toString() ?? '',
    );
  }
}

class AcaoSugerida {
  final String acao;
  final String motivo;

  const AcaoSugerida({required this.acao, this.motivo = ''});

  factory AcaoSugerida.fromJson(Map<String, dynamic> json) {
    return AcaoSugerida(
      acao: json['acao']?.toString() ?? '',
      motivo: json['motivo']?.toString() ?? '',
    );
  }
}

class FeedbackIaModel {
  final String etapa;
  final int anoLetivo;
  final bool fechada;
  final String tipoPlano; // recuperacao | continuidade | acompanhamento
  final double? notaOficial;
  final double? percentualOficial;
  final String situacaoOficial;
  final int atividadesAvaliadas;
  final int atividadesSemNota;
  final String modelo;
  final String resumo;
  final List<String> pontosConsolidados;
  final List<PontoAtencaoFeedback> pontosAtencao;
  final List<String> objetivos;
  final List<AcaoSugerida> acoes;
  final List<String> atividadesSugeridas;
  final String acompanhamento;

  const FeedbackIaModel({
    required this.etapa,
    required this.anoLetivo,
    required this.fechada,
    required this.tipoPlano,
    required this.situacaoOficial,
    this.notaOficial,
    this.percentualOficial,
    this.atividadesAvaliadas = 0,
    this.atividadesSemNota = 0,
    this.modelo = '',
    this.resumo = '',
    this.pontosConsolidados = const [],
    this.pontosAtencao = const [],
    this.objetivos = const [],
    this.acoes = const [],
    this.atividadesSugeridas = const [],
    this.acompanhamento = '',
  });

  String get tituloDoPlano {
    switch (tipoPlano) {
      case 'continuidade':
        return 'Plano de continuidade';
      case 'acompanhamento':
        return 'Plano de acompanhamento';
      default:
        return 'Plano de recuperação';
    }
  }

  String get tituloDosObjetivos {
    switch (tipoPlano) {
      case 'continuidade':
        return 'Objetivos de consolidação e aprofundamento';
      case 'acompanhamento':
        return 'Objetivos';
      default:
        return 'Objetivos de recuperação';
    }
  }

  factory FeedbackIaModel.fromJson(Map<String, dynamic> json) {
    final contexto =
        ((json['contexto'] as Map?) ?? const {}).cast<String, dynamic>();
    final oficial = ((contexto['resultadoOficial'] as Map?) ?? const {})
        .cast<String, dynamic>();
    final atividades =
        ((contexto['atividades'] as Map?) ?? const {}).cast<String, dynamic>();
    final sugestao =
        ((json['sugestao'] as Map?) ?? const {}).cast<String, dynamic>();

    double? numero(dynamic bruto) => bruto is num ? bruto.toDouble() : null;
    List<String> textos(String chave) =>
        ((sugestao[chave] as List?) ?? const [])
            .map((item) => item.toString())
            .toList();
    List<T> lista<T>(String chave, T Function(Map<String, dynamic>) criar) {
      return ((sugestao[chave] as List?) ?? const [])
          .map((item) => criar((item as Map).cast<String, dynamic>()))
          .toList();
    }

    return FeedbackIaModel(
      etapa: contexto['etapa']?.toString() ?? '',
      anoLetivo: (contexto['anoLetivo'] as num?)?.toInt() ?? 0,
      fechada: contexto['fechada'] == true,
      tipoPlano: contexto['tipoPlano']?.toString() ?? 'recuperacao',
      notaOficial: numero(oficial['nota']),
      percentualOficial: numero(oficial['percentual']),
      situacaoOficial: oficial['situacao']?.toString() ?? '',
      atividadesAvaliadas: (atividades['avaliadas'] as num?)?.toInt() ?? 0,
      atividadesSemNota: (atividades['semNotaLancada'] as num?)?.toInt() ?? 0,
      modelo: json['modelo']?.toString() ?? '',
      resumo: sugestao['resumo']?.toString() ?? '',
      pontosConsolidados: textos('pontosConsolidados'),
      pontosAtencao: lista('pontosAtencao', PontoAtencaoFeedback.fromJson),
      objetivos: textos('objetivosRecuperacao'),
      acoes: lista('acoesSugeridas', AcaoSugerida.fromJson),
      atividadesSugeridas: textos('atividadesSugeridas'),
      acompanhamento: sugestao['acompanhamento']?.toString() ?? '',
    );
  }
}
