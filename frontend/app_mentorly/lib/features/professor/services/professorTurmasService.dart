import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de turmas do professor
class ProfessorTurmasService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/professor/turmas
  Future<List<dynamic>> listarTurmas() async {
    final resposta = await _api.get('/professor/turmas');
    return resposta as List;
  }
}