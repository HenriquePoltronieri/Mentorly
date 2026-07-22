import '../../../core/services/apiService.dart';

// Servico que conversa com a IA que organiza as informacoes dos alunos
// e sugere solucoes pros alunos com mais dificuldade
class IaInsightsService {
  final ApiService _api = ApiService();

  // Retorna sugestoes de estudo pros alunos com nota abaixo da minima
  Future<List<Map<String, dynamic>>> gerarSolucoesAlunosEmDificuldade(
    String turmaId,
  ) async {
    final resposta = await _api.get('/turmas/$turmaId/ia/solucoes');
    return List<Map<String, dynamic>>.from(resposta ?? []);
  }

  // Aponta quais atividades tiveram o pior desempenho geral da turma
  Future<List<Map<String, dynamic>>> atividadesComPiorDesempenho(
    String turmaId,
  ) async {
    final resposta = await _api.get('/turmas/$turmaId/ia/piores-atividades');
    return List<Map<String, dynamic>>.from(resposta ?? []);
  }
}
