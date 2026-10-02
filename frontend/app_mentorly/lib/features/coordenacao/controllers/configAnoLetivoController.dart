import '../services/anosLetivosService.dart';
import '../services/etapasService.dart';
import '../services/criteriosService.dart';
import '../models/etapaModel.dart';
import '../models/criterioAvaliacaoModel.dart';

// Controla a configuracao do ano letivo (etapas, notas min/max, criterios)
// de UM ano da escola por vez.
//
// Singleton porque as tres telas do fluxo (configEtapas, configNotasEtapa,
// configCriterios) compartilham a mesma lista de etapas.
//
// O ano configurado vem do cadastro de anos letivos da escola: a tela de Anos
// Letivos escolhe um ano explicitamente, e quem entra pelo menu "Configurar
// Ano Letivo" usa o ano ATUAL (usarAnoAtualDaEscola). Nao existe mais um
// ano "assumido" pelo calendario do aparelho.
class ConfigAnoLetivoController {
  static final ConfigAnoLetivoController _instancia =
      ConfigAnoLetivoController._interno();

  factory ConfigAnoLetivoController() => _instancia;

  ConfigAnoLetivoController._interno();

  final EtapasService _etapasService = EtapasService();
  final CriteriosService _criteriosService = CriteriosService();

  List<EtapaModel> etapas = [];
  List<CriterioAvaliacaoModel> criterios = [];

  final AnosLetivosService _anosService = AnosLetivosService();

  // Ano em configuracao. Nulo ate alguem escolher um (ou a escola ter um ano
  // atual): nesse caso nao ha o que configurar.
  int? anoLetivo;

  bool get jaConfigurado => etapas.isNotEmpty;

  // Define o ano a configurar como o ano ATUAL cadastrado pela escola.
  // Fica nulo se a escola ainda nao marcou nenhum.
  Future<void> usarAnoAtualDaEscola() async {
    final anos = await _anosService.listarAnos();
    anoLetivo = null;
    for (final ano in anos) {
      if (ano.ehAtual) anoLetivo = ano.ano;
    }
  }

  // Carrega o que a escola ja tem configurado no ano escolhido. Chamado ao
  // abrir o fluxo, pra ele virar edicao em vez de recomecar do zero.
  Future<void> carregarConfiguracaoExistente() async {
    final ano = anoLetivo;
    if (ano == null) {
      etapas = [];
      criterios = [];
      return;
    }
    final resposta = await _etapasService.listarEtapas(anoLetivo: ano);

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
    final ano = anoLetivo;
    if (ano == null) {
      throw Exception('Escolha um ano letivo antes de configurar as etapas');
    }
    final novas = <EtapaModel>[];

    for (var numero = 1; numero <= quantidade; numero++) {
      final existente = etapas.where((e) => e.numero == numero).firstOrNull;
      final nome = (existente != null && existente.nome.isNotEmpty)
          ? existente.nome
          : 'Etapa $numero';

      final resposta = await _etapasService.criarEtapa(
        nome: nome,
        ordem: numero,
        anoLetivo: ano,
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

  // Grava o peso de um criterio em TODAS as etapas onde ele existe - o
  // mesmo nome de criterio ("Provas") vale para o ano letivo inteiro,
  // entao o peso tambem. Backend valida no calculo (Marco 2) que a soma
  // dos pesos ativos de cada etapa fecha em 100; esta tela so evita que
  // uma configuracao errada chegue ate la sem o usuario perceber.
  Future<void> definirPeso(String nome, double peso) async {
    final alvos = criterios.where((c) => c.nome == nome).toList();
    for (final criterio in alvos) {
      final id = int.tryParse(criterio.id);
      if (id == null) continue;
      await _criteriosService.atualizarCriterio(criterioId: id, peso: peso);
      criterio.peso = peso;
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

}

extension _PrimeiroOuNulo<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
