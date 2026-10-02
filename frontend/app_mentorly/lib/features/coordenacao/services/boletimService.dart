import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de boletim academico (Marco 3),
// na visao da Coordenacao.
class BoletimService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/coordenacao/turmas/{turmaId}/boletim
  Future<Map<String, dynamic>> buscarBoletim(int turmaId) async {
    final resposta = await _api.get('/coordenacao/turmas/$turmaId/boletim');
    return resposta as Map<String, dynamic>;
  }
}
