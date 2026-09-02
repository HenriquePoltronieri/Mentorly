import '../../../core/services/authService.dart';
import '../models/userModel.dart';

// Controla o estado de login/cadastro, chamado pelas telas de auth
class AuthController {
  final AuthService _authService = AuthService();

  UserModel? usuarioLogado;
  String? erro;

  Future<bool> login(String email, String senha) async {
    try {
      usuarioLogado = await _authService.loginCoordenacao(email, senha);
      return true;
    } catch (e) {
      erro = e.toString();
      return false;
    }
  }

  Future<bool> loginProfessor({
    required String email,
    required String senha,
  }) async {
    try {
      usuarioLogado = await _authService.loginProfessor(email: email, senha: senha);
      return true;
    } catch (e) {
      erro = e.toString();
      return false;
    }
  }

  Future<bool> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String telefone,
  }) async {
    try {
      usuarioLogado = await _authService.cadastrarCoordenacao(
        nome: nome,
        email: email,
        senha: senha,
        telefone: telefone,
      );
      return true;
    } catch (e) {
      erro = e.toString();
      return false;
    }
  }

  Future<bool> criarSenhaProfessor({
    required String email,
    required String senha,
    required String confirmarSenha,
    required String token,
  }) async {
    try {
      usuarioLogado = await _authService.criarSenhaProfessor(
        email: email,
        senha: senha,
        confirmarSenha: confirmarSenha,
        token: token,
      );
      return true;
    } catch (e) {
      erro = e.toString();
      return false;
    }
  }

  Future<bool> confirmarCodigo(String email, String codigo) {
    return _authService.confirmarCodigoDuasEtapas(email, codigo);
  }
}
