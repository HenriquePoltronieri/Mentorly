import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de critérios
class CriteriosService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/config/criterios/etapa/{etapaId}
  Future<List<dynamic>> listarCriterios(int etapaId) async {
    final resposta = await _api.get('/config/criterios/etapa/$etapaId');
    return resposta as List;
  }

  // GET {baseUrl}/api/config/criterios/{criterioId}
  Future<Map<String, dynamic>> buscarCriterio(int criterioId) async {
    final resposta = await _api.get('/config/criterios/$criterioId');
    return resposta as Map<String, dynamic>;
  }

  // POST {baseUrl}/api/config/criterios/etapa/{etapaId}
  Future<Map<String, dynamic>> criarCriterio({
    required int etapaId,
    required String nome,
    double peso = 0,
    double notaMaxima = 10,
  }) async {
    final resposta = await _api.post('/config/criterios/etapa/$etapaId', {
      'nome': nome,
      'peso': peso,
      'nota_maxima': notaMaxima,
    });
    return resposta as Map<String, dynamic>;
  }

  // PUT {baseUrl}/api/config/criterios/{criterioId}
  Future<Map<String, dynamic>> atualizarCriterio({
    required int criterioId,
    String? nome,
    double? peso,
    double? notaMaxima,
  }) async {
    final body = <String, dynamic>{};
    if (nome != null) body['nome'] = nome;
    if (peso != null) body['peso'] = peso;
    if (notaMaxima != null) body['nota_maxima'] = notaMaxima;

    final resposta = await _api.put('/config/criterios/$criterioId', body);
    return resposta as Map<String, dynamic>;
  }

  // DELETE {baseUrl}/api/config/criterios/{criterioId}
  Future<void> excluirCriterio(int criterioId) async {
    await _api.delete('/config/criterios/$criterioId');
  }
}