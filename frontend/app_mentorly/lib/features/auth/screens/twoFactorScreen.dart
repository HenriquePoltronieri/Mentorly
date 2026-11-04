import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/services/authService.dart';
import '../../../core/services/apiService.dart';

// Confirma que a Coordenação controla o endereço informado. A conta só é
// criada quando o backend aceita o mesmo código que foi enviado por e-mail.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _codigoController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _carregando = false;
  bool _reenviando = false;
  String? _mensagemErro;
  String? _email;
  Map<String, dynamic>? _argumentos;
  bool _jaPegouArgumentos = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaPegouArgumentos) {
      _argumentos =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _email = _argumentos?['email']?.toString();
      _jaPegouArgumentos = true;
    }
  }

  Future<void> _verificarCodigo() async {
    if (_codigoController.text.trim().length != 6) {
      setState(() {
        _mensagemErro = 'Digite o código de 6 dígitos';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      if (_email == null) {
        throw ApiException(400, 'E-mail do cadastro não encontrado.');
      }
      if (_argumentos?['cadastroCoordenacao'] == true) {
        await _authService.cadastrarCoordenacao(
          nome: _argumentos!['nome'].toString(),
          email: _email!,
          senha: _argumentos!['senha'].toString(),
          telefone: _argumentos!['telefone'].toString(),
          codigoVerificacao: _codigoController.text.trim(),
        );
        final acesso = await ApiService().get('/acesso');
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
            context,
            acesso['liberado'] == true
                ? AppRoutes.coordenacaoHome
                : AppRoutes.acesso,
            (_) => false);
      } else {
        final valido = await _authService.confirmarCodigoDuasEtapas(
            _email!, _codigoController.text.trim());
        if (!valido) {
          setState(() => _mensagemErro = 'Código inválido ou expirado');
        }
      }
    } on ApiException catch (e) {
      setState(() {
        _mensagemErro = e.mensagem;
      });
    } catch (e) {
      setState(() {
        _mensagemErro = 'Não foi possível conectar ao servidor';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _reenviarCodigo() async {
    setState(() {
      _reenviando = true;
    });

    try {
      if (_email == null) throw ApiException(400, 'E-mail não encontrado.');
      final enviado = await _authService.enviarCodigoDuasEtapas(_email!);
      if (!enviado) {
        throw ApiException(503, 'Não foi possível enviar o código.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código reenviado')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reenviar: ${e.mensagem}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível reenviar o código')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reenviando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificação')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _email != null
                  ? 'Enviamos um código de 6 dígitos para $_email'
                  : 'Digite o código de verificação enviado para seu email',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _codigoController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            if (_mensagemErro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  _mensagemErro!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregando ? null : _verificarCodigo,
              child: _carregando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _reenviando ? null : _reenviarCodigo,
              child: Text(_reenviando ? 'Reenviando...' : 'Reenviar código'),
            ),
          ],
        ),
      ),
    );
  }
}
