// Sugestao de atividade devolvida pela IA (Marco 9B).
//
// E so um rascunho: nada daqui existe no banco. O Professor revisa, e a
// atividade so e criada pelo formulario normal (POST /api/activities), com o
// texto que ele confirmou. As questoes viram texto na descricao da atividade.

class QuestaoSugerida {
  final String tipo; // 'discursiva' | 'objetiva'
  final String enunciado;
  final List<String> alternativas;
  final String respostaEsperada;
  final String explicacao;

  const QuestaoSugerida({
    required this.tipo,
    required this.enunciado,
    this.alternativas = const [],
    this.respostaEsperada = '',
    this.explicacao = '',
  });

  bool get objetiva => tipo == 'objetiva';

  factory QuestaoSugerida.fromJson(Map<String, dynamic> json) {
    return QuestaoSugerida(
      tipo: json['tipo']?.toString() ?? 'discursiva',
      enunciado: json['enunciado']?.toString() ?? '',
      alternativas: ((json['alternativas'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      respostaEsperada: json['respostaEsperada']?.toString() ?? '',
      explicacao: json['explicacao']?.toString() ?? '',
    );
  }
}

class RubricaSugerida {
  final String criterio;
  final String descricao;
  final num peso;

  const RubricaSugerida({
    required this.criterio,
    this.descricao = '',
    this.peso = 0,
  });

  factory RubricaSugerida.fromJson(Map<String, dynamic> json) {
    return RubricaSugerida(
      criterio: json['criterio']?.toString() ?? '',
      descricao: json['descricao']?.toString() ?? '',
      peso: json['peso'] is num ? json['peso'] as num : 0,
    );
  }
}

class SugestaoAtividadeModel {
  final String titulo;
  final String descricao;
  final String objetivo;
  final List<QuestaoSugerida> questoes;
  final List<RubricaSugerida> rubrica;
  final String modelo;

  const SugestaoAtividadeModel({
    required this.titulo,
    this.descricao = '',
    this.objetivo = '',
    this.questoes = const [],
    this.rubrica = const [],
    this.modelo = '',
  });

  factory SugestaoAtividadeModel.fromJson(Map<String, dynamic> json) {
    final sugestao =
        ((json['sugestao'] as Map?) ?? const {}).cast<String, dynamic>();
    List<T> lista<T>(String chave, T Function(Map<String, dynamic>) criar) {
      return ((sugestao[chave] as List?) ?? const [])
          .map((item) => criar((item as Map).cast<String, dynamic>()))
          .toList();
    }

    return SugestaoAtividadeModel(
      titulo: sugestao['titulo']?.toString() ?? '',
      descricao: sugestao['descricao']?.toString() ?? '',
      objetivo: sugestao['objetivo']?.toString() ?? '',
      questoes: lista('questoes', QuestaoSugerida.fromJson),
      rubrica: lista('rubricaSugerida', RubricaSugerida.fromJson),
      modelo: json['modelo']?.toString() ?? '',
    );
  }

  /// Texto que vai para o campo "Descricao" da atividade normal.
  ///
  /// Inclui gabarito e explicacao porque so o Professor acessa o Mentorly; o
  /// aluno nunca ve este texto aqui. A rubrica e opcional e continua sendo
  /// apenas texto: nao cria criterio oficial.
  String descricaoFormatada({bool incluirRubrica = false}) {
    const letras = ['A', 'B', 'C', 'D', 'E', 'F'];
    final partes = <String>[];

    if (objetivo.trim().isNotEmpty) {
      partes.add('Objetivo: ${objetivo.trim()}');
    }
    if (descricao.trim().isNotEmpty) partes.add(descricao.trim());

    for (var i = 0; i < questoes.length; i++) {
      final q = questoes[i];
      final linhas = <String>['${i + 1}. ${q.enunciado.trim()}'];
      if (q.objetiva) {
        for (var j = 0; j < q.alternativas.length && j < letras.length; j++) {
          linhas.add('   ${letras[j]}) ${q.alternativas[j].trim()}');
        }
      }
      if (q.respostaEsperada.trim().isNotEmpty) {
        linhas.add('   Gabarito: ${q.respostaEsperada.trim()}');
      }
      if (q.explicacao.trim().isNotEmpty) {
        linhas.add('   Explicação: ${q.explicacao.trim()}');
      }
      partes.add(linhas.join('\n'));
    }

    if (incluirRubrica && rubrica.isNotEmpty) {
      final itens = rubrica.map((r) {
        final peso = r.peso == r.peso.roundToDouble()
            ? r.peso.toInt().toString()
            : r.peso.toString();
        final detalhe =
            r.descricao.trim().isEmpty ? '' : ' — ${r.descricao.trim()}';
        return '- ${r.criterio.trim()} ($peso%)$detalhe';
      });
      partes.add('Rubrica sugerida:\n${itens.join('\n')}');
    }

    return partes.join('\n\n');
  }
}
