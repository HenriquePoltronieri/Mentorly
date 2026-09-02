import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de estatisticas do aluno
class ProfessorAlunoDetailService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/professor/alunos/{alunoId}/estatisticas
  Future<Map<String, dynamic>> buscarEstatisticas(int alunoId) async {
    final resposta = await _api.get('/professor/alunos/$alunoId/estatisticas');
    return resposta as Map<String, dynamic>;
  }
}