import '../../../core/services/apiService.dart';
import '../models/professorModel.dart';

// Cadastro e listagem de professores feitos pela coordenacao
class ProfessoresController {
  final ApiService _api = ApiService();

  List<ProfessorModel> professores = [];

  Future<void> carregarProfessores() async {
    final resposta = await _api.get('/professores');
    professores = (resposta as List)
        .map((item) => ProfessorModel.fromJson(item))
        .toList();
  }

  // Cadastra varios professores de uma vez (nome + email de cada um)
  Future<void> adicionarProfessores(
    List<Map<String, String>> novosProfessores,
  ) async {
    final resposta = await _api.post('/professores/lote', {
      'professores': novosProfessores,
    });
    professores.addAll(
      (resposta as List).map((item) => ProfessorModel.fromJson(item)),
    );
  }
}
