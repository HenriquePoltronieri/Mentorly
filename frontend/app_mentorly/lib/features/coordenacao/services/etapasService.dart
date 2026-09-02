import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de etapas
class EtapasService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/config/etapas
  Future<List<dynamic>> listarEtapas({int? anoLetivo}) async {
    String endpoint = '/config/etapas';
    if (anoLetivo != null) {
      endpoint += '?ano_letivo=$anoLetivo';
    }
    final resposta = await _api.get(endpoint);
    return resposta as List;
  }

  // GET {baseUrl}/api/config/etapas/{etapaId}
  Future<Map<String, dynamic>> buscarEtapa(int etapaId) async {
    final resposta = await _api.get('/config/etapas/$etapaId');
    return resposta as Map<String, dynamic>;
  }

  // POST {baseUrl}/api/config/etapas
  Future<Map<String, dynamic>> criarEtapa({
    required String nome,
    required int ordem,
    required int anoLetivo,
    String? dataInicio,
    String? dataFim,
    bool ativa = true,
  }) async {
    final resposta = await _api.post('/config/etapas', {
      'nome': nome,
      'ordem': ordem,
      'ano_letivo': anoLetivo,
      if (dataInicio != null) 'data_inicio': dataInicio,
      if (dataFim != null) 'data_fim': dataFim,
      'ativa': ativa,
    });
    return resposta as Map<String, dynamic>;
  }

  // PUT {baseUrl}/api/config/etapas/{etapaId}
  Future<Map<String, dynamic>> atualizarEtapa({
    required int etapaId,
    String? nome,
    int? ordem,
    String? dataInicio,
    String? dataFim,
    bool? ativa,
  }) async {
    final body = <String, dynamic>{};
    if (nome != null) body['nome'] = nome;
    if (ordem != null) body['ordem'] = ordem;
    if (dataInicio != null) body['data_inicio'] = dataInicio;
    if (dataFim != null) body['data_fim'] = dataFim;
    if (ativa != null) body['ativa'] = ativa;

    final resposta = await _api.put('/config/etapas/$etapaId', body);
    return resposta as Map<String, dynamic>;
  }

  // DELETE {baseUrl}/api/config/etapas/{etapaId}
  Future<void> excluirEtapa(int etapaId) async {
    await _api.delete('/config/etapas/$etapaId');
  }

  // POST {baseUrl}/api/config/etapas/{etapaId}/notas
  Future<Map<String, dynamic>> definirNotas({
    required int etapaId,
    required double notaMinima,
    required double notaMaxima,
  }) async {
    final resposta = await _api.post('/config/etapas/$etapaId/notas', {
      'nota_minima': notaMinima,
      'nota_maxima': notaMaxima,
    });
    return resposta as Map<String, dynamic>;
  }
}