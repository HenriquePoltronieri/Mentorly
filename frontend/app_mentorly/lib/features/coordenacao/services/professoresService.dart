import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de professores
// (listagem e cadastro feitos pela coordenacao)
class ProfessoresService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/coordenacao/professores
  Future<List<dynamic>> listarProfessores() async {
    final resposta = await _api.get('/coordenacao/professores');
    return resposta as List;
  }

  // POST {baseUrl}/api/coordenacao/professores
  Future<Map<String, dynamic>> cadastrarProfessor({
    required String nome,
    required String email,
    required String disciplina,
  }) async {
    final resposta = await _api.post('/coordenacao/professores', {
      'nome': nome,
      'email': email,
      'disciplina': disciplina,
    });
    return resposta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> editarProfessor({
    required int professorId,
    required String nome,
    required String email,
    String? disciplina,
  }) async {
    final resposta = await _api.put('/coordenacao/professores/$professorId', {
      'nome': nome,
      'email': email,
      if (disciplina != null) 'disciplina': disciplina,
    });
    return resposta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> desativarProfessor(int professorId) async {
    final resposta = await _api.post('/coordenacao/professores/$professorId/desativar', {});
    return resposta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reativarProfessor(int professorId) async {
    final resposta = await _api.post('/coordenacao/professores/$professorId/reativar', {});
    return resposta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reenviarConvite(int professorId) async {
    final resposta = await _api.post('/coordenacao/professores/$professorId/reenviar-convite', {});
    return resposta as Map<String, dynamic>;
  }
}
