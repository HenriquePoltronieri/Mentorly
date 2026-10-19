import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/services/apiService.dart';
import 'admin_http_io.dart' if (dart.library.js_interop) 'admin_http_web.dart';

// Sessao separada da escola, mantida em cookie HttpOnly no navegador.
// Nenhuma senha ou cookie administrativo vai para SharedPreferences.
class AdminService {
  final http.Client _cliente;
  String? _csrf;
  String? _cookie;
  Map<String, dynamic>? usuario;

  AdminService({http.Client? cliente})
      : _cliente = cliente ?? criarClienteAdmin();

  Future<Map<String, dynamic>> _enviar(String caminho,
      {String metodo = 'GET', Map<String, dynamic>? dados}) async {
    final requisicao =
        http.Request(metodo, Uri.parse('${ApiService.baseUrl}/admin$caminho'));
    requisicao.headers['Content-Type'] = 'application/json';
    if (metodo != 'GET' && _csrf != null) {
      requisicao.headers['X-CSRF-Token'] = _csrf!;
    }
    if (cookiesManuais && _cookie != null) {
      requisicao.headers['Cookie'] = _cookie!;
    }
    if (dados != null) requisicao.body = jsonEncode(dados);
    try {
      final fluxo =
          await _cliente.send(requisicao).timeout(const Duration(seconds: 20));
      final resposta = await http.Response.fromStream(fluxo)
          .timeout(const Duration(seconds: 20));
      if (cookiesManuais && resposta.headers['set-cookie'] != null) {
        _cookie = resposta.headers['set-cookie']!.split(';').first;
      }
      Map<String, dynamic> corpo;
      try {
        corpo = Map<String, dynamic>.from(
            jsonDecode(utf8.decode(resposta.bodyBytes)) as Map);
      } catch (_) {
        throw ApiException(
            502, 'Resposta inesperada do servidor. Tente novamente.');
      }
      if (resposta.statusCode >= 400) {
        if (resposta.statusCode == 401 && caminho != '/login') usuario = null;
        throw ApiException(resposta.statusCode,
            corpo['error']?.toString() ?? 'Não foi possível concluir.');
      }
      if (corpo['csrf'] is String) _csrf = corpo['csrf'] as String;
      return corpo;
    } on TimeoutException {
      throw ApiException(
          408, 'O servidor demorou para responder. Tente novamente.');
    } on http.ClientException {
      throw ApiException(0, 'Não foi possível conectar ao servidor.');
    }
  }

  Future<void> consultarSessao() async {
    final dados = await _enviar('/sessao');
    usuario = dados['usuario'] == null
        ? null
        : Map<String, dynamic>.from(dados['usuario'] as Map);
  }

  Future<void> entrar(String email, String senha) async {
    if (_csrf == null) await consultarSessao();
    final dados = await _enviar('/login',
        metodo: 'POST', dados: {'email': email, 'senha': senha});
    usuario = Map<String, dynamic>.from(dados['usuario'] as Map);
  }

  Future<Map<String, dynamic>> listar(String busca) =>
      _enviar('/escolas?q=${Uri.encodeQueryComponent(busca)}');

  Future<void> salvar(int escolaId, Map<String, dynamic> dados) async {
    await _enviar('/escolas/$escolaId/acesso', metodo: 'PUT', dados: dados);
  }

  Future<void> excluir(int escolaId, String emailConfirmacao) async {
    await _enviar('/escolas/$escolaId',
        metodo: 'DELETE', dados: {'email_confirmacao': emailConfirmacao});
  }

  Future<void> sair() async {
    try {
      await _enviar('/sair', metodo: 'POST', dados: {});
    } finally {
      usuario = null;
      _csrf = null;
      _cookie = null;
    }
  }

  void dispose() => _cliente.close();
}
