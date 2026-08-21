import '../../../core/services/apiService.dart';
import '../models/atividadeModel.dart';

// Servico que fala com a API de atividades (entidade Activity no backend).
// Toda chamada passa pelo ApiService, que centraliza a baseUrl.
//
// Endpoints usados:
//   GET    /api/activities
//   GET    /api/activities?class_id=<id>
//   GET    /api/activities/<id>
//   POST   /api/activities
//   PUT    /api/activities/<id>
//   DELETE /api/activities/<id>
//   GET    /api/activities/buscar   (procedure)
class AtividadesService {
  final ApiService _api = ApiService();

  Future<List<AtividadeModel>> listarAtividades({String? turmaId}) async {
    final endpoint = (turmaId != null && turmaId.isNotEmpty)
        ? '/activities?class_id=$turmaId'
        : '/activities';
    final resposta = await _api.get(endpoint);
    return (resposta as List)
        .map((item) => AtividadeModel.fromJson(item))
        .toList();
  }

  Future<AtividadeModel> buscarAtividade(String id) async {
    final resposta = await _api.get('/activities/$id');
    return AtividadeModel.fromJson(resposta);
  }

  Future<AtividadeModel> cadastrarAtividade({
    required String turmaId,
    required String nome,
    String descricao = '',
    String dataEntrega = '',
  }) async {
    final resposta = await _api.post('/activities', {
      'title': nome,
      'description': descricao,
      'class_id': int.tryParse(turmaId) ?? turmaId,
      'due_date': dataEntrega,
    });
    return AtividadeModel.fromJson(resposta);
  }

  Future<AtividadeModel> atualizarAtividade({
    required String id,
    required String turmaId,
    required String nome,
    String descricao = '',
    String dataEntrega = '',
  }) async {
    final resposta = await _api.put('/activities/$id', {
      'title': nome,
      'description': descricao,
      'class_id': int.tryParse(turmaId) ?? turmaId,
      'due_date': dataEntrega,
    });
    return AtividadeModel.fromJson(resposta);
  }

  Future<void> excluirAtividade(String id) async {
    await _api.delete('/activities/$id');
  }

  // Busca vinda da procedure sp_buscar_atividades.
  // GET /api/activities/buscar?termo=...&ordenar_por=...&direcao=...
  Future<List<dynamic>> buscarAtividades({
    String? termo,
    required String ordenarPor,
    required String direcao,
  }) async {
    final params = <String, String>{
      'ordenar_por': ordenarPor,
      'direcao': direcao,
      if (termo != null && termo.isNotEmpty) 'termo': termo,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final resposta = await _api.get('/activities/buscar?$query');
    return resposta as List;
  }
}
