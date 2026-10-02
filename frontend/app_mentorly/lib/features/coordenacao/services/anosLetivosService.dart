import '../../../core/services/apiService.dart';
import '../models/anoLetivoModel.dart';

// Servico que fala com a API de anos letivos (so a Coordenacao usa).
// Toda chamada passa pelo ApiService, que centraliza a baseUrl e o token.
//
// Endpoints usados:
//   GET    /api/config/anos-letivos
//   POST   /api/config/anos-letivos
//   PUT    /api/config/anos-letivos/<id>
//   DELETE /api/config/anos-letivos/<id>
class AnosLetivosService {
  final ApiService _api = ApiService();

  // Anos da escola, do mais novo para o mais antigo.
  Future<List<AnoLetivoModel>> listarAnos() async {
    final resposta = await _api.get('/config/anos-letivos');
    return (resposta as List)
        .map((item) => AnoLetivoModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Sem [status], o ano nasce em planejamento. Para marcar como atual quando
  // ja existe outro atual, e preciso confirmar a troca com [encerrarAtual]:
  // o backend encerra o atual na mesma operacao.
  Future<AnoLetivoModel> criarAno({
    required int ano,
    String? status,
    bool encerrarAtual = false,
  }) async {
    final resposta = await _api.post('/config/anos-letivos', {
      'ano': ano,
      if (status != null) 'status': status,
      if (encerrarAtual) 'encerrar_atual': true,
    });
    return AnoLetivoModel.fromJson(resposta as Map<String, dynamic>);
  }

  // So o status muda: o numero do ano e a chave que turma e etapa usam.
  Future<AnoLetivoModel> alterarStatus({
    required int id,
    required String status,
    bool encerrarAtual = false,
  }) async {
    final resposta = await _api.put('/config/anos-letivos/$id', {
      'status': status,
      if (encerrarAtual) 'encerrar_atual': true,
    });
    return AnoLetivoModel.fromJson(resposta as Map<String, dynamic>);
  }

  // Backend recusa (409) ano que ainda tem turma ou etapa.
  Future<void> excluirAno(int id) async {
    await _api.delete('/config/anos-letivos/$id');
  }
}
