import '../../../core/services/apiService.dart';
import '../models/correcaoSugeridaModel.dart';

// Pede a sugestao de avaliacao de uma resposta discursiva a IA (Marco 9C).
//
// POST /api/professor/atividades/<id>/correcao-assistida
// So devolve uma sugestao: nao lanca nota. O lancamento continua em
// POST /api/atividades/<id>/notas, pelo botao "Salvar notas" da tela de notas.
// Nenhum dado do aluno vai na requisicao: so o texto da resposta.
class CorrecaoAssistidaIaService {
  final ApiService _api = ApiService();

  Future<CorrecaoSugeridaModel> corrigir({
    required String atividadeId,
    required String questao,
    required String respostaEsperada,
    required String respostaAluno,
    required double valorMaximo,
    List<Map<String, dynamic>> rubrica = const [],
  }) async {
    final resposta =
        await _api.post('/professor/atividades/$atividadeId/correcao-assistida', {
      'questao': questao.trim(),
      'respostaEsperada': respostaEsperada.trim(),
      'respostaAluno': respostaAluno.trim(),
      'valorMaximo': valorMaximo,
      if (rubrica.isNotEmpty) 'rubrica': rubrica,
    });
    return CorrecaoSugeridaModel.fromJson(
      (resposta as Map).cast<String, dynamic>(),
    );
  }
}
