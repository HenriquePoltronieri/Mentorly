import '../../../core/services/apiService.dart';
import '../models/turmaModel.dart';

// Cadastro de turmas vinculadas a um professor
class TurmasController {
  final ApiService _api = ApiService();

  List<TurmaModel> turmas = [];

  Future<void> carregarTurmas(String professorId) async {
    final resposta = await _api.get('/professores/$professorId/turmas');
    turmas =
        (resposta as List).map((item) => TurmaModel.fromJson(item)).toList();
  }

  Future<void> adicionarTurma({
    required String professorId,
    required String nome,
    required String disciplina,
    required String turno,
  }) async {
    final resposta = await _api.post('/professores/$professorId/turmas', {
      'nome': nome,
      'disciplina': disciplina,
      'turno': turno,
    });
    turmas.add(TurmaModel.fromJson(resposta));
  }

  // Cadastro de turmas em lote via planilha
  Future<void> adicionarTurmasPlanilha(
    String professorId,
    List<Map<String, dynamic>> linhas,
  ) async {
    final resposta = await _api.post(
      '/professores/$professorId/turmas/lote',
      {'turmas': linhas},
    );
    turmas.addAll(
      (resposta as List).map((item) => TurmaModel.fromJson(item)),
    );
  }
}
