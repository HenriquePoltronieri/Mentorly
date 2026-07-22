import 'dart:convert';
import 'package:http/http.dart' as http;

// Servico central que fala com o backend Flask
// Troca a baseUrl pelo endereco real do seu servidor quando for pra producao
class ApiService {
  // 10.0.2.2 e o endereco que o emulador Android usa pra falar com o
  // localhost do seu computador. Se for testar no Chrome ou iOS, troca
  // por 'http://localhost:5000/api'
  static const String baseUrl = 'http://10.0.2.2:5000/api';

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
    throw Exception('Erro na API: ${response.statusCode} - ${response.body}');
  }
}