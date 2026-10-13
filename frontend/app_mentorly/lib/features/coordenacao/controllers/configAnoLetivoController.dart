import '../../../core/services/apiService.dart';
import '../services/anosLetivosService.dart';
import '../services/etapasService.dart';
import '../models/etapaModel.dart';
import '../models/criterioAvaliacaoModel.dart';

// Rascunho compartilhado pelos três passos. O banco só muda ao concluir.
class ConfigAnoLetivoController {
  static final _instancia = ConfigAnoLetivoController._interno();
  factory ConfigAnoLetivoController() => _instancia;
  ConfigAnoLetivoController._interno();
  final _api = ApiService();
  final _etapasService = EtapasService();
  final _anosService = AnosLetivosService();
  List<EtapaModel> etapas = [];
  List<CriterioAvaliacaoModel> criterios = [];
  final Map<int, List<String>> rascunhosNotas = {};
  final Map<String, String> rascunhosPesos = {};
  List<String>? criteriosSelecionados;
  int? anoLetivo;
  String? _sessaoRascunho;
  bool get temRascunhoDaSessao =>
      etapas.isNotEmpty && _sessaoRascunho == _api.token;
  bool get jaConfigurado => etapas.any((e) => e.id != null);

  Future<void> usarAnoAtualDaEscola() async {
    final anos = await _anosService.listarAnos();
    anoLetivo = null;
    for (final ano in anos) {
      if (ano.ehAtual) anoLetivo = ano.ano;
    }
  }

  void _lerConfiguracao(List<dynamic> resposta) {
    etapas = resposta
        .map((e) => EtapaModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
    criterios = [];
    for (final etapa in resposta) {
      for (final criterio in (etapa['criterios'] as List? ?? [])) {
        criterios.add(
            CriterioAvaliacaoModel.fromJson(criterio as Map<String, dynamic>));
      }
    }
  }

  Future<void> carregarConfiguracaoExistente() async {
    _sessaoRascunho = _api.token;
    rascunhosNotas.clear();
    rascunhosPesos.clear();
    criteriosSelecionados = null;
    etapas = [];
    criterios = [];
    if (anoLetivo != null) {
      _lerConfiguracao(await _etapasService.listarEtapas(anoLetivo: anoLetivo));
    }
  }

  Future<void> definirQuantidadeEtapas(int quantidade) async {
    if (anoLetivo == null) throw Exception('Escolha um ano letivo.');
    if (quantidade < 1 || quantidade > 12) {
      throw Exception('Escolha de 1 a 12 etapas.');
    }
    final antigas = {for (final e in etapas) e.numero: e};
    etapas = List.generate(
        quantidade,
        (i) =>
            antigas[i + 1] ??
            EtapaModel(
              nome: 'Etapa ${i + 1}',
              numero: i + 1,
              anoLetivo: anoLetivo!,
            ));
  }

  EtapaModel? etapaPorNumero(int numero) {
    for (final etapa in etapas) {
      if (etapa.numero == numero) return etapa;
    }
    return null;
  }

  Future<void> salvarNotasEtapa(
      int numero, double minima, double maxima) async {
    final etapa = etapaPorNumero(numero);
    if (etapa == null) throw Exception('Etapa não encontrada.');
    if (!minima.isFinite ||
        !maxima.isFinite ||
        minima < 0 ||
        minima >= maxima ||
        maxima > 999.99) {
      throw Exception(
          'O mínimo deve ser menor que os pontos da etapa (até 999,99).');
    }
    etapa.notaMinima = minima;
    etapa.notaMaxima = maxima;
  }

  Future<void> salvarConfiguracao(Map<String, double> pesos) async {
    if (anoLetivo == null) throw Exception('Escolha um ano letivo.');
    final resposta =
        await _api.put('/config/anos-letivos/$anoLetivo/configuracao', {
      'etapas': etapas
          .map((e) => {
                'nome': e.nome,
                'nota_minima': e.notaMinima,
                'nota_maxima': e.notaMaxima,
              })
          .toList(),
      'criterios':
          pesos.entries.map((e) => {'nome': e.key, 'peso': e.value}).toList(),
    });
    _lerConfiguracao(resposta as List);
  }

  List<String> get nomesDosCriterios =>
      criterios.map((c) => c.nome).toSet().toList();
}
