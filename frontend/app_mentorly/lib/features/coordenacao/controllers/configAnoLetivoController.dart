import '../services/etapasService.dart';
import '../services/criteriosService.dart';
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

  final EtapasService _etapasService = EtapasService();
  final CriteriosService _criteriosService = CriteriosService();

  List<EtapaModel> etapas = [];
  List<CriterioAvaliacaoModel> criterios = [];

  Future<void> definirQuantidadeEtapas(int quantidade) async {
    // Create etapas sequentially - the backend expects one at a time
    // For now, just store locally and sync later
    etapas = List.generate(quantidade, (i) => EtapaModel(nome: 'Etapa ${i + 1}', numero: i + 1));
    // Note: The backend expects individual etapa creation
    // We'll sync when the user navigates to the next screen
  }

  Future<void> salvarNotasEtapa(
    int numeroEtapa,
    double notaMinima,
    double notaMaxima,
  ) async {
    // Find the etapa by numero and sync to backend
    final etapa = etapas.firstWhere((e) => e.numero == numeroEtapa);
    if (etapa.id != null && etapa.id!.isNotEmpty) {
      await _etapasService.definirNotas(
        etapaId: int.parse(etapa.id!),
        notaMinima: notaMinima,
        notaMaxima: notaMaxima,
      );
    }
    etapa.notaMinima = notaMinima;
    etapa.notaMaxima = notaMaxima;
  }

  Future<void> adicionarCriterio(String nome) async {
    if (etapas.isEmpty) return;
    // Associate with the first etapa for now
    final etapa = etapas.first;
    if (etapa.id != null && etapa.id!.isNotEmpty) {
      final resposta = await _criteriosService.criarCriterio(
        etapaId: int.parse(etapa.id!),
        nome: nome,
      );
      criterios.add(CriterioAvaliacaoModel.fromJson(resposta));
    }
  }

  Future<void> finalizarConfiguracao() async {
    // Create all etapas in backend
    for (final etapa in etapas) {
      if (etapa.id == null || etapa.id!.isEmpty) {
        final resposta = await _etapasService.criarEtapa(
          nome: etapa.nome.isNotEmpty ? etapa.nome : 'Etapa ${etapa.numero}',
          ordem: etapa.numero,
          anoLetivo: DateTime.now().year,
          ativa: etapa.ativa,
        );
        etapa.id = resposta['id'].toString();
      }
    }
    // Note: criterios are already created in adicionarCriterio
  }

  // reseta tudo - util pra quando a coordenacao terminar uma configuracao
  // completa e for comecar outra do zero
  void resetar() {
    etapas = [];
    criterios = [];
  }
}