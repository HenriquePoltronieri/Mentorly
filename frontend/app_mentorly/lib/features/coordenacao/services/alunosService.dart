import '../../../core/services/apiService.dart';

// Alunos de uma turma, na visao da Coordenacao.
//
// A importacao por planilha e o download do modelo nao ficam aqui: eles
// passam por ApiService.enviarArquivo e ApiService.urlComToken, usados pelo
// AdicionarAlunosModal (core/widgets), que atende Coordenacao e Professor
// com o mesmo widget.
class AlunosService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/coordenacao/turmas/{turmaId}/alunos
  Future<List<dynamic>> listarAlunos(int turmaId) async {
    final resposta = await _api.get('/coordenacao/turmas/$turmaId/alunos');
    return resposta as List;
  }

  // POST {baseUrl}/coordenacao/turmas/{turmaId}/alunos
  Future<Map<String, dynamic>> cadastrarAluno({
    required int turmaId,
    required String nome,
    String? matricula,
    String? email,
  }) async {
    final resposta = await _api.post('/coordenacao/turmas/$turmaId/alunos', {
      'nome': nome,
      if (matricula != null && matricula.isNotEmpty) 'matricula': matricula,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return resposta as Map<String, dynamic>;
  }
}
