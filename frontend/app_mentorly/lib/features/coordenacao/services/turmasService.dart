import '../../../core/services/apiService.dart';
import '../models/turmaModel.dart';

// Servico que fala com a API de turmas (entidade Class no backend).
// Toda chamada passa pelo ApiService, que centraliza a baseUrl.
//
// Endpoints usados:
//   GET    /api/classes
//   GET    /api/classes/<id>
//   POST   /api/classes
//   PUT    /api/classes/<id>
//   DELETE /api/classes/<id>
//   GET    /api/classes/relatorio/atividades   (procedure)
class TurmasService {
  final ApiService _api = ApiService();

  Future<List<TurmaModel>> listarTurmas() async {
    final resposta = await _api.get('/classes');
    return (resposta as List)
        .map((item) => TurmaModel.fromJson(item))
        .toList();
  }

  Future<TurmaModel> buscarTurma(String id) async {
    final resposta = await _api.get('/classes/$id');
    return TurmaModel.fromJson(resposta);
  }

  Future<TurmaModel> cadastrarTurma({
    required String nome,
    String descricao = '',
  }) async {
    final resposta = await _api.post('/classes', {
      'name': nome,
      'description': descricao,
    });
    return TurmaModel.fromJson(resposta);
  }

  Future<TurmaModel> atualizarTurma({
    required String id,
    required String nome,
    String descricao = '',
  }) async {
    final resposta = await _api.put('/classes/$id', {
      'name': nome,
      'description': descricao,
    });
    return TurmaModel.fromJson(resposta);
  }

  Future<void> excluirTurma(String id) async {
    await _api.delete('/classes/$id');
  }

  // Relatorio vindo da procedure sp_relatorio_turmas_atividades.
  // Cada item tem: id, name, description, total_atividades.
  Future<List<dynamic>> relatorioTurmasAtividades() async {
    final resposta = await _api.get('/classes/relatorio/atividades');
    return resposta as List;
  }
}
