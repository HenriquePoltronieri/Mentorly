import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de atividades
// (busca com filtro e ordenacao)
class AtividadesService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/activities/buscar?termo=...&ordenar_por=...&direcao=...
  Future<List<dynamic>> buscarAtividades({
    String? termo,
    required String ordenarPor,
    required String direcao,
  }) async {
    final params = <String, String>{
      'ordenar_por': ordenarPor,
      'direcao': direcao,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final resposta = await _api.get('/activities/buscar?$query');
    return resposta as List;
  }
}