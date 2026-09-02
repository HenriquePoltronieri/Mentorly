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
}