import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de dashboard do professor
class ProfessorDashboardService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/professor/dashboard
  Future<Map<String, dynamic>> buscarDashboard() async {
    final resposta = await _api.get('/professor/dashboard');
    return resposta as Map<String, dynamic>;
  }
}