import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de alunos
class AlunosService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos
  Future<List<dynamic>> listarAlunos(int turmaId) async {
    final resposta = await _api.get('/coordenacao/turmas/$turmaId/alunos');
    return resposta as List;
  }

  // POST {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos
  Future<Map<String, dynamic>> cadastrarAluno({
    required int turmaId,
    required String nome,
    required String matricula,
    String? email,
  }) async {
    final resposta = await _api.post('/coordenacao/turmas/$turmaId/alunos', {
      'nome': nome,
      'matricula': matricula,
      if (email != null) 'email': email,
    });
    return resposta as Map<String, dynamic>;
  }

  // POST {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos/importar
  Future<Map<String, dynamic>> importarAlunos({
    required int turmaId,
    required List<int> fileBytes,
    required String filename,
  }) async {
    // Note: For multipart upload, we need a different approach
    // This is a simplified version - in production you'd use http.MultipartRequest
    throw UnimplementedError('Use http.MultipartRequest directly for file upload');
  }

  // GET {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos/modelo-planilha
  Future<void> baixarModelo(int turmaId) async {
    // This would typically open a URL in the browser
    throw UnimplementedError('Open URL in browser for download');
  }
}