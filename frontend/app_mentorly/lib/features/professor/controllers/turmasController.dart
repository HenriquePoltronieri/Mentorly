import '../../../core/services/apiService.dart';
import '../../coordenacao/models/turmaModel.dart';
import '../../coordenacao/models/alunoModel.dart';
import '../models/notaModel.dart';

// Turmas do professor logado e alunos/notas de cada turma
class TurmasController {
  final ApiService _api = ApiService();

  List<TurmaModel> turmas = [];
  List<AlunoModel> alunosDaTurma = [];
  Map<String, List<NotaModel>> notasPorAtividade = {};

  Future<void> carregarMinhasTurmas() async {
    final resposta = await _api.get('/professor/turmas');
    turmas =
        (resposta as List).map((item) => TurmaModel.fromJson(item)).toList();
  }

  Future<void> carregarAlunosDaTurma(String turmaId) async {
    final resposta = await _api.get('/turmas/$turmaId/alunos');
    alunosDaTurma =
        (resposta as List).map((item) => AlunoModel.fromJson(item)).toList();
  }
}
