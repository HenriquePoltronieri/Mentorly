import '../../../core/services/apiService.dart';
import '../models/historicoTurmaAlunoModel.dart';

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

  // DELETE {baseUrl}/coordenacao/alunos/{alunoId}
  Future<void> excluirAluno(int alunoId) async {
    await _api.delete('/coordenacao/alunos/$alunoId');
  }

  Future<Map<String, dynamic>> transferirAluno({
    required int alunoId,
    required int turmaDestinoId,
    String? motivo,
  }) async {
    final resposta =
        await _api.post('/coordenacao/alunos/$alunoId/transferir', {
      'turma_id': turmaDestinoId,
      if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
    });
    return resposta as Map<String, dynamic>;
  }

  Future<List<HistoricoTurmaAlunoModel>> historicoAluno(int alunoId) async {
    final resposta = await _api.get('/coordenacao/alunos/$alunoId/historico');
    return (resposta as List)
        .map((item) => HistoricoTurmaAlunoModel.fromJson(item))
        .toList();
  }
}
