import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/apiService.dart';

/// Rascunhos ficam apenas neste dispositivo e separados por servidor/escola/usuário.
class RascunhoNotasService {
  final String recurso;
  late final String? _chave;
  Future<void> _fila = Future.value();
  RascunhoNotasService(this.recurso) {
    final u = ApiService().usuario;
    _chave = u?['id'] == null
        ? null
        : 'mentorly.rascunho.v1.${ApiService.baseUrl}.${u?['coordenacao_id']}.${u?['tipo']}.${u?['id']}.$recurso';
  }
  Future<Map<String, dynamic>?> ler() async {
    if (_chave == null) return null;
    await _fila;
    final texto = (await SharedPreferences.getInstance()).getString(_chave!);
    if (texto == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(texto) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> gravar(Map<String, dynamic> dados) {
    final texto = jsonEncode(dados);
    return _enfileirar(() async {
      if (_chave != null &&
          !await (await SharedPreferences.getInstance())
              .setString(_chave!, texto)) {
        throw StateError('Falha ao salvar rascunho');
      }
    });
  }

  Future<void> apagar() => _enfileirar(() async {
        if (_chave != null) {
          await (await SharedPreferences.getInstance()).remove(_chave!);
        }
      });
  Future<void> _enfileirar(Future<void> Function() acao) {
    final atual = _fila.then((_) => acao());
    _fila = atual.catchError((Object _) {});
    return atual;
  }
}
