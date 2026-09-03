import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
// Singleton para compartilhar o token entre todos os services
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Endereco unico da API, usado por todos os Services.
  // - Chrome / Web / Windows: 'http://localhost:5000/api'  (valor atual)
  // - Emulador Android:       'http://10.0.2.2:5000/api'
  // 10.0.2.2 e o apelido que o emulador Android usa pro localhost do host;
  // no navegador esse endereco nao existe, por isso o padrao aqui e localhost.
  static const String baseUrl = 'http://localhost:5000/api';

  static const Duration _timeout = Duration(seconds: 15);

  static const String _chaveToken = 'mentorly.token';
  static const String _chaveUsuario = 'mentorly.usuario';

  String? token;

  // Dados do usuario logado: {id, nome, email, tipo}.
  // O 'tipo' e o que decide se o app abre o painel da coordenacao ou a
  // area do professor, entao precisa sobreviver ao refresh da pagina.
  Map<String, dynamic>? usuario;

  bool get estaLogado => token != null;

  String? get tipoUsuario => usuario?['tipo'] as String?;

  bool get ehCoordenacao => tipoUsuario == 'coordenacao';

  bool get ehProfessor => tipoUsuario == 'professor';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ---------------------------------------------------------------------
  // Sessao
  //
  // Antes o token vivia so em memoria: qualquer refresh do navegador
  // deslogava o usuario e todas as chamadas passavam a voltar 401.
  // ---------------------------------------------------------------------

  Future<void> salvarSessao(String novoToken, Map<String, dynamic> dados) async {
    token = novoToken;
    usuario = dados;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveToken, novoToken);
    await prefs.setString(_chaveUsuario, jsonEncode(dados));
  }

  // Chamado no main() antes do runApp, pra decidir a rota inicial.
  Future<bool> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenSalvo = prefs.getString(_chaveToken);
    final usuarioSalvo = prefs.getString(_chaveUsuario);

    if (tokenSalvo == null || usuarioSalvo == null) return false;

    token = tokenSalvo;
    try {
      usuario = jsonDecode(usuarioSalvo) as Map<String, dynamic>;
    } catch (_) {
      // Sessao gravada por uma versao antiga do app: descarta e pede login.
      await limparSessao();
      return false;
    }
    return true;
  }

  Future<void> limparSessao() async {
    token = null;
    usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveToken);
    await prefs.remove(_chaveUsuario);
  }

  // Monta a URL de um download que o navegador abre em outra aba
  // (launchUrl nao manda cabecalho, entao o token vai na query string).
  String urlComToken(String endpoint) {
    final separador = endpoint.contains('?') ? '&' : '?';
    return '$baseUrl$endpoint${token == null ? '' : '${separador}token=$token'}';
  }

  // ---------------------------------------------------------------------
  // Verbos HTTP
  // ---------------------------------------------------------------------

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

  // Upload de planilha (multipart). O campo do arquivo se chama "arquivo",
  // que e o nome que os endpoints de importacao esperam.
  Future<Map<String, dynamic>> enviarArquivo(
    String endpoint, {
    required List<int> bytes,
    required String nomeArquivo,
  }) async {
    final requisicao = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );
    if (token != null) {
      requisicao.headers['Authorization'] = 'Bearer $token';
    }
    requisicao.files.add(
      http.MultipartFile.fromBytes('arquivo', bytes, filename: nomeArquivo),
    );

    final streamed = await requisicao.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    final corpo = _tratarResposta(response);
    return (corpo as Map).cast<String, dynamic>();
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
