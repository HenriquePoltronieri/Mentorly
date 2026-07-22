import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../app/routes.dart';

// tela de verificacao em duas etapas, aberta logo apos o cadastro
// recebe o email via Navigator.pushNamed(..., arguments: {'email': '...'})
//
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> POST {baseUrl}/api/coordenacao/verificar-codigo
// body enviado -> { "email": "...", "codigo": "123456" }
// resposta esperada em caso de sucesso (200) ->
// { "token": "...", "nome": "..." }
// resposta esperada em caso de erro (400/401) ->
// { "erro": "código inválido ou expirado" }
//
// endpoint pra reenviar o codigo -> POST {baseUrl}/api/coordenacao/reenviar-codigo
// body enviado -> { "email": "..." }
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _codigoController = TextEditingController();

  bool _carregando = false;
  bool _reenviando = false;
  String? _mensagemErro;
  String? _email;
  bool _jaPegouArgumentos = false;

  // ATENCAO: 10.0.2.2 so funciona no emulador Android.
  // Testando no Chrome/Web, troca por 'http://localhost:5000'
  static const String baseUrl = 'http://localhost:5000';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaPegouArgumentos) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _email = args?['email'];
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
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/coordenacao/verificar-codigo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _email,
              'codigo': _codigoController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.coordenacaoHome,
          (rota) => false, // limpa o historico, nao deixa voltar pro cadastro
        );
      } else {
        final dados = jsonDecode(response.body);
        setState(() {
          _mensagemErro = dados['erro'] ?? 'Código inválido';
        });
      }
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
      await http
          .post(
            Uri.parse('$baseUrl/api/coordenacao/reenviar-codigo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': _email}),
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código reenviado')),
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