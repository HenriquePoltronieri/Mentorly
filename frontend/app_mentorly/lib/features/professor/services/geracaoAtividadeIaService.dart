import '../../../core/services/apiService.dart';
import '../models/sugestaoAtividadeModel.dart';

// Pede a sugestao de atividade a IA (Marco 9B).
//
// POST /api/professor/turmas/<id>/atividades/gerar
// So devolve texto: nao cria atividade. A criacao continua em
// AtividadesService.cadastrarAtividade, depois da revisao do Professor.
class GeracaoAtividadeIaService {
  final ApiService _api = ApiService();

  Future<SugestaoAtividadeModel> gerar({
    required String turmaId,
    required String tema,
    String objetivo = '',
    String observacoes = '',
    String dificuldade = 'media',
    int quantidadeQuestoes = 5,
    String tipo = 'mista',
    int? etapaId,
    int? criterioId,
  }) async {
    final resposta = await _api.post('/professor/turmas/$turmaId/atividades/gerar', {
      'tema': tema,
      if (objetivo.trim().isNotEmpty) 'objetivo': objetivo.trim(),
      if (observacoes.trim().isNotEmpty) 'observacoes': observacoes.trim(),
      'dificuldade': dificuldade,
      'quantidadeQuestoes': quantidadeQuestoes,
      'tipo': tipo,
      // Etapa e criterio andam juntos: so alinham o conteudo, nao sao salvos.
      if (etapaId != null && criterioId != null) 'etapaId': etapaId,
      if (etapaId != null && criterioId != null) 'criterioId': criterioId,
    });
    return SugestaoAtividadeModel.fromJson(
      (resposta as Map).cast<String, dynamic>(),
    );
  }
}
