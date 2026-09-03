import '../../../core/services/apiService.dart';
import '../models/notaModel.dart';

// Lancamento de notas de uma atividade.
//
// Endpoints (exclusivos do Professor; a Coordenacao recebe 403):
//   GET  /api/atividades/{id}/notas
//   POST /api/atividades/{id}/notas
//
// O CRUD de atividade em si fica no AtividadesService
// (features/professor/services/atividadesService.dart), que fala com
// /api/activities.
class AtividadesController {
  final ApiService _api = ApiService();

  List<NotaModel> notas = [];

  Future<void> carregarNotas(String atividadeId) async {
    final resposta = await _api.get('/atividades/$atividadeId/notas');
    final lista = (resposta['notas'] as List?) ?? [];
    notas = lista.map((item) => NotaModel.fromJson(item)).toList();
  }

  // Manda a turma inteira de uma vez. Antes era uma requisicao por aluno,
  // o que deixava as notas pela metade se a conexao caisse no meio.
  Future<int> salvarNotas({
    required String atividadeId,
    required List<Map<String, dynamic>> lancamentos,
  }) async {
    if (lancamentos.isEmpty) return 0;
    final resposta = await _api.post('/atividades/$atividadeId/notas', {
      'notas': lancamentos,
    });
    return resposta['lancadas'] ?? 0;
  }
}
