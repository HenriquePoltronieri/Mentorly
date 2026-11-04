import '../../../core/services/apiService.dart';

class AtividadeAnexosService {
  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> listar(String atividadeId) async {
    final resposta = await _api.get('/activities/$atividadeId/anexos');
    return (resposta as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> enviar(
    String atividadeId, {
    required List<int> bytes,
    required String nome,
  }) =>
      _api.enviarArquivo(
        '/activities/$atividadeId/anexos',
        bytes: bytes,
        nomeArquivo: nome,
      );

  Future<Uri> autorizarDownload(String atividadeId, int anexoId) => _api
      .autorizarDownload('/activities/$atividadeId/anexos/$anexoId/download');

  Future<void> excluir(String atividadeId, int anexoId) =>
      _api.delete('/activities/$atividadeId/anexos/$anexoId');
}
