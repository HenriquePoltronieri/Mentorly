import 'package:flutter/material.dart';
import '../../../core/widgets/customTextfield.dart';
import '../../../core/widgets/customButton.dart';
import '../../../core/utils/validators.dart';
import '../../../app/routes.dart';
import '../../../core/services/authService.dart';
import '../../../core/services/apiService.dart';
import '../../../core/widgets/identidade_visual.dart';

// Professor recebe o email por convite da coordenacao e cria a senha aqui
// pela primeira vez (Confirmar senha garante que ele digitou certo)
// O token vem na URL: /definir-senha?token=xxx
class DefinirSenhaProfessorScreen extends StatefulWidget {
  const DefinirSenhaProfessorScreen({super.key});

  @override
  State<DefinirSenhaProfessorScreen> createState() =>
      _DefinirSenhaProfessorScreenState();
}

class _DefinirSenhaProfessorScreenState
    extends State<DefinirSenhaProfessorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _authService = AuthService();
  bool _carregando = false;
  String? _token;
  String? _erro;
  String? _email;
  bool _consultando = false;
  bool _conviteValido = false;
  bool _iniciou = false;
  bool _podeRepetirConsulta = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciou) return;
    _iniciou = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['token'] != null) {
      _token = args['token'] as String;
      _consultar();
      return;
    }

    // Link do convite: {app}/#/definir-senha?token=...
    // No Flutter Web o que vem depois do '#' e o fragmento, entao o token
    // NAO aparece em Uri.base.queryParameters - precisa ser lido do
    // fragmento. A query normal fica como alternativa.
    final uri = Uri.base;
    _token = uri.queryParameters['token'];
    if (_token != null) {
      _consultar();
      return;
    }

    final fragmento = uri.fragment;
    final posicao = fragmento.indexOf('?');
    if (posicao >= 0) {
      _token = Uri.splitQueryString(fragmento.substring(posicao + 1))['token'];
    }
    _consultar();
  }

  Future<void> _consultar() async {
    if (_token == null || _token!.isEmpty) return;
    setState(() {
      _consultando = true;
      _erro = null;
      _conviteValido = false;
      _podeRepetirConsulta = false;
    });
    try {
      final dados =
          await ApiService().post('/auth/consultar-convite', {'token': _token});
      if (mounted) {
        setState(() {
          _email = dados['email']?.toString();
          _conviteValido = _email != null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e is ApiException
              ? e.mensagem
              : 'Não foi possível conferir o convite. Tente novamente.';
          _email = null;
          _podeRepetirConsulta = e is! ApiException ||
              e.statusCode == 408 ||
              e.statusCode == 429 ||
              e.statusCode >= 500;
        });
      }
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _entrar() async {
    if (_carregando || !_conviteValido) return;
    if (!_formKey.currentState!.validate()) return;
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Token inválido ou ausente. Acesse pelo link do e-mail.')),
      );
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await _authService.criarSenhaProfessor(
        senha: _senhaController.text,
        confirmarSenha: _confirmarSenhaController.text,
        token: _token!,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.listaTurmas);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e is ApiException
              ? e.mensagem
              : 'Não foi possível conectar. Tente novamente.';
          if (e is ApiException && e.statusCode == 403) {
            _conviteValido = false;
            _email = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TelaAcesso(
      perfil: PerfilVisual.professor,
      child: VidroCard(
          formas: true,
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Criar senha',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                if (_consultando) const LinearProgressIndicator(),
                if (_email != null) ...[
                  const Text('E-mail do convite',
                      style: TextStyle(fontSize: 13)),
                  Semantics(
                      label: 'E-mail do convite, somente leitura',
                      child: SelectableText(_email!,
                          style: const TextStyle(fontSize: 14))),
                  const SizedBox(height: 16),
                ],
                if (_token == null || _token!.isEmpty)
                  const Text(
                      'Token inválido ou ausente. Acesse pelo link do e-mail. Peça um novo convite à Coordenação.',
                      style: TextStyle(color: Colors.red)),
                const Text(
                    'Use uma senha com pelo menos 6 caracteres. Confirme a mesma senha abaixo.'),
                SizedBox(height: 12),
                CustomTextfield(
                  label: 'Nova senha',
                  controller: _senhaController,
                  senha: true,
                  autofocus: true,
                  validator: Validators.validarSenha,
                ),
                SizedBox(height: 12),
                CustomTextfield(
                  label: 'Confirmar senha',
                  controller: _confirmarSenhaController,
                  senha: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _entrar(),
                  validator: (valor) => valor != _senhaController.text
                      ? 'As senhas não coincidem'
                      : Validators.validarSenha(valor),
                ),
                SizedBox(height: 24),
                if (_erro != null) ...[
                  Semantics(
                      liveRegion: true,
                      child: Text(_erro!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                  const Text(
                      'Se o convite expirou ou já foi usado, peça um novo à Coordenação.'),
                  const SizedBox(height: 16),
                ],
                CustomButton(
                  texto: 'Criar senha e entrar',
                  onPressed: !_conviteValido || _consultando ? null : _entrar,
                  carregando: _carregando,
                ),
                if (_podeRepetirConsulta && !_conviteValido)
                  TextButton(
                      onPressed: _consultando ? null : _consultar,
                      child: const Text('Tentar novamente')),
                TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.professorLogin),
                    child: const Text('Já tenho senha. Entrar')),
              ],
            ),
          )),
    );
  }
}
