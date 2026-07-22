import '../../../core/services/apiService.dart';
import '../models/alunoModel.dart';

// Cadastro de alunos vinculados a uma turma
class AlunosController {
  final ApiService _api = ApiService();

  List<AlunoModel> alunos = [];

  Future<void> carregarAlunos(String turmaId) async {
    final resposta = await _api.get('/turmas/$turmaId/alunos');
    alunos =
        (resposta as List).map((item) => AlunoModel.fromJson(item)).toList();
  }

  Future<void> adicionarAluno(String turmaId, String nome) async {
    final resposta = await _api.post('/turmas/$turmaId/alunos', {
      'nome': nome,
    });
    alunos.add(AlunoModel.fromJson(resposta));
  }

  // Cadastro de alunos em lote via planilha
  Future<void> adicionarAlunosPlanilha(
    String turmaId,
    List<Map<String, dynamic>> linhas,
  ) async {
    final resposta = await _api.post('/turmas/$turmaId/alunos/lote', {
      'alunos': linhas,
    });
    alunos.addAll(
      (resposta as List).map((item) => AlunoModel.fromJson(item)),
    );
  }
}
