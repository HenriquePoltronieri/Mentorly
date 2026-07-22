import '../../../core/services/apiService.dart';
import '../models/estatisticaAlunoModel.dart';

// Estatisticas de um aluno especifico (grafico de notas, media, conclusao)
class AlunoDetailController {
  final ApiService _api = ApiService();

  EstatisticaAlunoModel? estatistica;

  Future<void> carregarEstatisticas(String alunoId) async {
    final resposta = await _api.get('/alunos/$alunoId/estatisticas');
    estatistica = EstatisticaAlunoModel.fromJson(resposta);
  }
}
