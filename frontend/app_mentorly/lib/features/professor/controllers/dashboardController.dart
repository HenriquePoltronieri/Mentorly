import '../../../core/services/apiService.dart';

// Dados gerais mostrados na home do professor
class DashboardController {
  final ApiService _api = ApiService();

  int quantidadeTurmas = 0;
  int quantidadeAlunos = 0;
  List<Map<String, dynamic>> alunosEmRisco = [];

  Future<void> carregarResumo() async {
    final resposta = await _api.get('/professor/resumo');
    quantidadeTurmas = resposta['quantidadeTurmas'] ?? 0;
    quantidadeAlunos = resposta['quantidadeAlunos'] ?? 0;
    alunosEmRisco =
        List<Map<String, dynamic>>.from(resposta['alunosEmRisco'] ?? []);
  }
}
