import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de vinculação professor-turma
class ProfessorTurmasService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/coordenacao/professores
  Future<List<dynamic>> listarProfessores() async {
    final resposta = await _api.get('/coordenacao/professores');
    return resposta as List;
  }

  // GET {baseUrl}/api/classes
  Future<List<dynamic>> listarTurmas() async {
    final resposta = await _api.get('/classes');
    return resposta as List;
  }

  // POST {baseUrl}/api/coordenacao/professores/{professorId}/turmas
  Future<Map<String, dynamic>> vincularTurmas({
    required int professorId,
    required List<int> turmaIds,
  }) async {
    final resposta = await _api.post('/coordenacao/professores/$professorId/turmas', {
      'turma_ids': turmaIds,
    });
    return resposta as Map<String, dynamic>;
  }

  // GET {baseUrl}/api/coordenacao/professores/{professorId}/turmas
  Future<List<dynamic>> getTurmasDoProfessor(int professorId) async {
    final resposta = await _api.get('/coordenacao/professores/$professorId/turmas');
    return resposta as List;
  }
}