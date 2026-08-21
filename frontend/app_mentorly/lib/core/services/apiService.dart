import 'dart:convert';
import 'package:http/http.dart' as http;

// Erro devolvido pela API quando o status sai da faixa 2xx.
// Guarda o codigo HTTP e a mensagem que o Flask manda em {"error": "..."},
// pra tela conseguir mostrar o motivo real em vez de um texto generico.
class ApiException implements Exception {
  final int statusCode;
  final String mensagem;

  ApiException(this.statusCode, this.mensagem);

  @override
  String toString() => 'ApiException($statusCode): $mensagem';
}

// Servico central que fala com o backend Flask
// Troca a baseUrl pelo endereco real do seu servidor quando for pra producao
class ApiService {
  // Endereco unico da API, usado por todos os Services.
  // - Chrome / Web / Windows: 'http://localhost:5000/api'  (valor atual)
  // - Emulador Android:       'http://10.0.2.2:5000/api'
  // 10.0.2.2 e o apelido que o emulador Android usa pro localhost do host;
  // no navegador esse endereco nao existe, por isso o padrao aqui e localhost.
  static const String baseUrl = 'http://localhost:5000/api';

  static const Duration _timeout = Duration(seconds: 5);

  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String endpoint) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers,
        )
        .timeout(_timeout);
    return _tratarResposta(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _tratarResposta(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _tratarResposta(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers,
        )
        .timeout(_timeout);
    return _tratarResposta(response);
  }

  dynamic _tratarResposta(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, _extrairMensagem(response));
  }

  // O Flask responde erro como {"error": "mensagem"}. Se vier outra coisa,
  // cai no texto padrao com o codigo HTTP.
  String _extrairMensagem(http.Response response) {
    if (response.body.isNotEmpty) {
      try {
        final corpo = jsonDecode(response.body);
        if (corpo is Map && corpo['error'] != null) {
          return corpo['error'].toString();
        }
      } catch (_) {
        // corpo nao era JSON, ignora e usa o texto padrao
      }
    }
    return 'Erro ${response.statusCode}';
  }
}