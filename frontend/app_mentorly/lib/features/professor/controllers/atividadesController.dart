import '../../../core/services/apiService.dart';
import '../models/atividadeModel.dart';
import '../models/notaModel.dart';

// Cadastro de atividades e lancamento de notas
class AtividadesController {
  final ApiService _api = ApiService();

  List<AtividadeModel> atividades = [];
  List<NotaModel> notas = [];

  Future<void> carregarAtividades(String turmaId) async {
    final resposta = await _api.get('/turmas/$turmaId/atividades');
    atividades = (resposta as List)
        .map((item) => AtividadeModel.fromJson(item))
        .toList();
  }

  Future<void> adicionarAtividade({
    required String turmaId,
    required String nome,
    required String tipo,
    required int etapa,
    required double valor,
  }) async {
    final resposta = await _api.post('/turmas/$turmaId/atividades', {
      'nome': nome,
      'tipo': tipo,
      'etapa': etapa,
      'valor': valor,
    });
    atividades.add(AtividadeModel.fromJson(resposta));
  }

  Future<void> carregarNotas(String atividadeId) async {
    final resposta = await _api.get('/atividades/$atividadeId/notas');
    notas =
        (resposta as List).map((item) => NotaModel.fromJson(item)).toList();
  }

  Future<void> lancarNota({
    required String atividadeId,
    required String alunoId,
    required double valorObtido,
    required double valorTotal,
  }) async {
    await _api.post('/atividades/$atividadeId/notas', {
      'alunoId': alunoId,
      'valorObtido': valorObtido,
      'valorTotal': valorTotal,
    });
  }

  // Lancamento de notas em lote via planilha
  Future<void> lancarNotasPlanilha(
    String atividadeId,
    List<Map<String, dynamic>> linhas,
  ) async {
    await _api.post('/atividades/$atividadeId/notas/lote', {
      'notas': linhas,
    });
  }
}
