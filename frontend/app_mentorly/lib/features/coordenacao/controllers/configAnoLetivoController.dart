import '../../../core/services/apiService.dart';
import '../models/etapaModel.dart';
import '../models/criterioAvaliacaoModel.dart';

// Controla a configuracao do ano letivo (etapas, notas min/max, criterios)
//
// IMPORTANTE: esse controller e um singleton (so existe UMA instancia dele
// em todo o app). Isso e necessario porque 3 telas diferentes
// (configEtapasScreen, configCriteriosScreen, configNotasEtapaScreen)
// precisam compartilhar a mesma lista de "etapas" - se cada tela tivesse
// sua propria instancia, a lista preenchida na primeira tela nao apareceria
// nas outras.
class ConfigAnoLetivoController {
  static final ConfigAnoLetivoController _instancia =
      ConfigAnoLetivoController._interno();

  factory ConfigAnoLetivoController() => _instancia;

  ConfigAnoLetivoController._interno();

  final ApiService _api = ApiService();

  List<EtapaModel> etapas = [];
  List<CriterioAvaliacaoModel> criterios = [];

  Future<void> definirQuantidadeEtapas(int quantidade) async {
    etapas = List.generate(quantidade, (i) => EtapaModel(numero: i + 1));
    await _api.post('/config/etapas', {'quantidade': quantidade});
  }

  Future<void> salvarNotasEtapa(
    int numeroEtapa,
    double notaMinima,
    double notaMaxima,
  ) async {
    final etapa = etapas.firstWhere((e) => e.numero == numeroEtapa);
    etapa.notaMinima = notaMinima;
    etapa.notaMaxima = notaMaxima;

    await _api.post('/config/etapas/$numeroEtapa/notas', {
      'notaMinima': notaMinima,
      'notaMaxima': notaMaxima,
    });
  }

  Future<void> adicionarCriterio(String nome) async {
    final resposta = await _api.post('/config/criterios', {'nome': nome});
    criterios.add(CriterioAvaliacaoModel.fromJson(resposta));
  }

  Future<void> finalizarConfiguracao() async {
    await _api.post('/config/finalizar', {});
  }

  // reseta tudo - util pra quando a coordenacao terminar uma configuracao
  // completa e for comecar outra do zero
  void resetar() {
    etapas = [];
    criterios = [];
  }
}