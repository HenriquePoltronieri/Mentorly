import 'apiService.dart';
import '../../features/auth/models/userModel.dart';

// Cuida de login, cadastro e verificacao em duas etapas.
//
// Toda entrada bem-sucedida passa por _guardarSessao, que persiste token e
// usuario no SharedPreferences. Sem isso o app perdia o login a cada
// refresh da pagina e todas as chamadas voltavam 401.
class AuthService {
  final ApiService _api = ApiService();

  Future<UserModel> _guardarSessao(Map<String, dynamic> resposta) async {
    final usuario = Map<String, dynamic>.from(resposta['usuario'] as Map);
    await _api.salvarSessao(resposta['token'] as String, usuario);
    return UserModel.fromJson(usuario);
  }

  Future<UserModel> loginCoordenacao(String email, String senha) async {
    final resposta = await _api.post('/auth/login-coordenacao', {
      'email': email,
      'senha': senha,
    });
    return _guardarSessao(resposta);
  }

  Future<UserModel> loginProfessor({
    required String email,
    required String senha,
  }) async {
    final resposta = await _api.post('/auth/login-professor', {
      'email': email,
      'senha': senha,
    });
    return _guardarSessao(resposta);
  }

  Future<UserModel> cadastrarCoordenacao({
    required String nome,
    required String email,
    required String senha,
    required String telefone,
  }) async {
    final resposta = await _api.post('/auth/cadastro-coordenacao', {
      'nome': nome,
      'email': email,
      'senha': senha,
      'telefone': telefone,
    });
    return _guardarSessao(resposta);
  }

  // Professor recebe o email ja cadastrado pela coordenacao e so cria a senha
  Future<UserModel> criarSenhaProfessor({
    required String email,
    required String senha,
    required String confirmarSenha,
    required String token,
  }) async {
    if (senha != confirmarSenha) {
      throw Exception('As senhas nao coincidem');
    }
    final resposta = await _api.post('/auth/criar-senha-professor', {
      'email': email,
      'senha': senha,
      'token': token,
    });
    return _guardarSessao(resposta);
  }

  Future<bool> enviarCodigoDuasEtapas(String email) async {
    final resposta = await _api.post('/auth/enviar-codigo', {'email': email});
    return resposta['enviado'] ?? false;
  }

  Future<bool> confirmarCodigoDuasEtapas(String email, String codigo) async {
    final resposta = await _api.post('/auth/confirmar-codigo', {
      'email': email,
      'codigo': codigo,
    });
    return resposta['valido'] ?? false;
  }

  Future<void> sair() => _api.limparSessao();
}
