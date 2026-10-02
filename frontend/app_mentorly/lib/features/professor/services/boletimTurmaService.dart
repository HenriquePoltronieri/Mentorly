import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de boletim da turma (Marco 3)
class BoletimTurmaService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/professor/turmas/{turmaId}/boletim
  Future<Map<String, dynamic>> buscarBoletim(int turmaId) async {
    final resposta = await _api.get('/professor/turmas/$turmaId/boletim');
    return resposta as Map<String, dynamic>;
  }
}
