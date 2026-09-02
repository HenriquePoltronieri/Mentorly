import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de alunos do professor
class ProfessorAlunosService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/professor/turmas/{turmaId}/alunos
  Future<List<dynamic>> listarAlunos(int turmaId) async {
    final resposta = await _api.get('/professor/turmas/$turmaId/alunos');
    return resposta as List;
  }
}