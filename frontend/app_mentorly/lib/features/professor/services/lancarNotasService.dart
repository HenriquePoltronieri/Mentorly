import '../../../core/services/apiService.dart';

// Servico responsavel por falar com a API de lancamento de notas
class LancarNotasService {
  final ApiService _api = ApiService();

  // GET {baseUrl}/api/atividades/{atividadeId}/notas/modelo-planilha
  Future<void> baixarModelo(String atividadeId) async {
    final url = '${ApiService.baseUrl}/atividades/$atividadeId/notas/modelo-planilha';
    // This would typically open in browser
    throw UnimplementedError('Open URL in browser for download');
  }

  // POST {baseUrl}/api/atividades/{atividadeId}/notas/importar
  Future<Map<String, dynamic>> importarNotas({
    required String atividadeId,
    required List<int> fileBytes,
    required String filename,
  }) async {
    // For multipart, we need to use http.MultipartRequest directly
    // This is a placeholder - the actual implementation uses http directly
    throw UnimplementedError('Use http.MultipartRequest directly for file upload');
  }
}