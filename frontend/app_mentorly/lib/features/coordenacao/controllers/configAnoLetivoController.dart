import '../services/etapasService.dart';
import '../services/criteriosService.dart';
import '../models/etapaModel.dart';
import '../models/criterioAvaliacaoModel.dart';

// Controla a configuracao do ano letivo (etapas, notas min/max, criterios).
//
// Singleton porque as tres telas do fluxo (configEtapas, configNotasEtapa,
// configCriterios) compartilham a mesma lista de etapas.
//
// DUAS CORRECOES IMPORTANTES EM RELACAO A VERSAO ANTERIOR:
//
// 1. As etapas eram criadas so no fim do fluxo (finalizarConfiguracao), com
//    id nulo ate la. Como salvarNotasEtapa e adicionarCriterio eram
//    guardados por "if (etapa.id != null)", a nota minima/maxima e os
//    criterios NUNCA chegavam ao backend: o usuario preenchia, avancava, e
//    o dado sumia sem nenhum erro na tela. Agora a etapa e criada no
//    backend assim que a quantidade e escolhida, entao ja tem id quando as
//    telas seguintes gravam.
//
// 2. A configuracao e PADRAO DA ESCOLA. carregarConfiguracaoExistente traz
//    o que ja foi configurado, e o POST /config/etapas faz upsert por
//    (ano_letivo, ordem) - passar pelo fluxo de novo edita em vez de
//    duplicar.
class ConfigAnoLetivoController {
  static final ConfigAnoLetivoController _instancia =
      ConfigAnoLetivoController._interno();

  factory ConfigAnoLetivoController() => _instancia;

  ConfigAnoLetivoController._interno();

  final EtapasService _etapasService = EtapasService();
  final CriteriosService _criteriosService = CriteriosService();

  List<EtapaModel> etapas = [];
  List<CriterioAvaliacaoModel> criterios = [];

  int anoLetivo = DateTime.now().year;

  bool get jaConfigurado => etapas.isNotEmpty;

  // Carrega o que a escola ja tem configurado. Chamado ao abrir o fluxo,
  // pra ele virar edicao em vez de recomecar do zero.
  Future<void> carregarConfiguracaoExistente() async {
    final resposta = await _etapasService.listarEtapas(anoLetivo: anoLetivo);

    etapas = resposta
        .map((item) => EtapaModel.fromJson(item as Map<String, dynamic>))
        .toList();
    etapas.sort((a, b) => a.numero.compareTo(b.numero));

    criterios = [];
    for (final item in resposta) {
      final lista = (item as Map<String, dynamic>)['criterios'] as List?;
      if (lista == null) continue;
      criterios.addAll(
        lista.map(
          (c) => CriterioAvaliacaoModel.fromJson(c as Map<String, dynamic>),
        ),
      );
    }
  }

  // Cria (ou reaproveita) as etapas no backend AGORA, para que elas ja
  // tenham id quando as proximas telas forem gravar notas e criterios.
  Future<void> definirQuantidadeEtapas(int quantidade) async {
    final novas = <EtapaModel>[];

    for (var numero = 1; numero <= quantidade; numero++) {
      final existente = etapas.where((e) => e.numero == numero).firstOrNull;
      final nome = (existente != null && existente.nome.isNotEmpty)
          ? existente.nome
          : 'Etapa $numero';

      final resposta = await _etapasService.criarEtapa(
        nome: nome,
        ordem: numero,
        anoLetivo: anoLetivo,
      );

      final etapa = EtapaModel.fromJson(resposta);
      novas.add(etapa);
    }

    // Se a escola diminuiu a quantidade de etapas, apaga as que sobraram.
    for (final antiga in etapas) {
      if (antiga.numero > quantidade && antiga.id != null) {
        await _etapasService.excluirEtapa(int.parse(antiga.id!));
      }
    }

    etapas = novas;
  }

  EtapaModel? etapaPorNumero(int numero) =>
      etapas.where((e) => e.numero == numero).firstOrNull;

  Future<void> salvarNotasEtapa(
    int numeroEtapa,
    double notaMinima,
    double notaMaxima,
  ) async {
    final etapa = etapaPorNumero(numeroEtapa);
    if (etapa == null || etapa.id == null) {
      throw Exception('A etapa $numeroEtapa ainda não foi criada');
    }

    await _etapasService.definirNotas(
      etapaId: int.parse(etapa.id!),
      notaMinima: notaMinima,
      notaMaxima: notaMaxima,
    );

    etapa.notaMinima = notaMinima;
    etapa.notaMaxima = notaMaxima;
  }

  // Criterios valem para o ano letivo inteiro: sao criados em todas as
  // etapas, para o professor poder classificar a atividade em qualquer uma.
  Future<void> adicionarCriterio(String nome) async {
    if (etapas.isEmpty) {
      throw Exception('Configure as etapas antes dos critérios');
    }

    for (final etapa in etapas) {
      if (etapa.id == null) continue;
      final resposta = await _criteriosService.criarCriterio(
        etapaId: int.parse(etapa.id!),
        nome: nome,
      );
      criterios.add(CriterioAvaliacaoModel.fromJson(resposta));
    }
  }

  Future<void> removerCriterio(String nome) async {
    final alvos = criterios.where((c) => c.nome == nome).toList();
    for (final criterio in alvos) {
      final id = int.tryParse(criterio.id);
      if (id == null) continue;
      await _criteriosService.excluirCriterio(id);
      criterios.remove(criterio);
    }
  }

  // Nomes distintos dos criterios ja configurados (eles se repetem por
  // etapa, entao a tela mostra o conjunto).
  List<String> get nomesDosCriterios =>
      criterios.map((c) => c.nome).toSet().toList();

  // Reseta o estado em memoria. Nao apaga nada no backend: a configuracao
  // continua sendo o padrao da escola.
  void resetar() {
    etapas = [];
    criterios = [];
  }
}

extension _PrimeiroOuNulo<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
