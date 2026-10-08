import '../../../core/services/apiService.dart';
import '../models/feedbackIaModel.dart';

// Pede o feedback e o plano sugeridos pela IA para um aluno (Marco 9D).
//
// POST /api/professor/alunos/<id>/feedback-ia   body: {"etapaId": N}
// So leitura: o backend nao grava nada e nao envia dado pessoal do aluno ao
// provedor. A etapa e sempre informada explicitamente.
class FeedbackIaService {
  final ApiService _api = ApiService();

  Future<FeedbackIaModel> gerar({
    required int alunoId,
    required int etapaId,
  }) async {
    final resposta = await _api.post(
      '/professor/alunos/$alunoId/feedback-ia',
      {'etapaId': etapaId},
    );
    return FeedbackIaModel.fromJson((resposta as Map).cast<String, dynamic>());
  }
}
