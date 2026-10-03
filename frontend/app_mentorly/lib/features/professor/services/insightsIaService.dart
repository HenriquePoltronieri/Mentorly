import '../../../core/services/apiService.dart';
import '../models/insightsTurmaModel.dart';

class InsightsIaService {
  final ApiService _api = ApiService();

  Future<InsightsTurmaModel> gerar(int turmaId) async {
    final resposta = await _api.post('/professor/turmas/$turmaId/insights', {});
    return InsightsTurmaModel.fromJson(
      (resposta as Map).cast<String, dynamic>(),
    );
  }
}
