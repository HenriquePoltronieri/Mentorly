import '../../../core/services/apiService.dart';
import '../models/insightsTurmaModel.dart';

class InsightsIaService {
  final ApiService _api = ApiService();

  Future<InsightsTurmaModel> gerar(int turmaId, {int? etapaId}) async {
    final resposta = await _api.post('/professor/turmas/$turmaId/insights', {
      if (etapaId != null) 'etapa_id': etapaId,
    });
    return InsightsTurmaModel.fromJson(
      (resposta as Map).cast<String, dynamic>(),
    );
  }
}
