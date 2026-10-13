import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/apiService.dart';
import '../../../core/services/authService.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/customTextfield.dart';
import '../../../core/widgets/customButton.dart';
import '../../../core/widgets/identidade_visual.dart';

class TelaLogin extends StatefulWidget {
  final bool professor;
  final bool cadastroInicial;
  const TelaLogin(
      {super.key, required this.professor, this.cadastroInicial = false});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();
  final _telefone = TextEditingController();
  late bool _cadastro;
  bool _carregando = false;
  String? _erro;
  @override
  void initState() {
    super.initState();
    _cadastro = widget.cadastroInicial;
  }

  void _alternar() {
    if (_carregando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cadastro = !_cadastro;
      _erro = null;
      _senha.clear();
      _confirmar.clear();
    });
    _form.currentState?.reset();
  }

  Future<void> _enviar() async {
    if (_carregando || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final auth = AuthService();
      if (_cadastro) {
        await auth.cadastrarCoordenacao(
            nome: _nome.text.trim(),
            email: _email.text.trim(),
            senha: _senha.text,
            telefone: _telefone.text.trim());
      } else if (widget.professor) {
        await auth.loginProfessor(
            email: _email.text.trim(), senha: _senha.text);
      } else {
        await auth.loginCoordenacao(_email.text.trim(), _senha.text);
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context,
          widget.professor ? AppRoutes.listaTurmas : AppRoutes.coordenacaoHome);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível conectar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_nome, _email, _senha, _confirmar, _telefone]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _formulario() => Padding(
      padding: const EdgeInsets.all(28),
      child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_cadastro ? 'Criar conta' : 'Entrar',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                    _cadastro
                        ? 'Cadastre sua escola no Mentorly.'
                        : widget.professor
                            ? 'Acesse sua conta de professor.'
                            : 'Acesse sua conta de Coordenação.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                if (_cadastro) ...[
                  CustomTextfield(
                      label: 'Nome',
                      controller: _nome,
                      autofocus: true,
                      validator: Validators.validarCampoObrigatorio),
                  const SizedBox(height: 16),
                ],
                CustomTextfield(
                    label: 'Email',
                    controller: _email,
                    autofocus: !_cadastro,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validarEmail),
                const SizedBox(height: 16),
                CustomTextfield(
                    label: 'Senha',
                    controller: _senha,
                    senha: true,
                    textInputAction:
                        _cadastro ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: _cadastro ? null : (_) => _enviar(),
                    validator: _cadastro
                        ? Validators.validarSenha
                        : (v) =>
                            v == null || v.isEmpty ? 'Digite a senha' : null),
                if (_cadastro) ...[
                  const SizedBox(height: 16),
                  CustomTextfield(
                      label: 'Confirmar senha',
                      controller: _confirmar,
                      senha: true,
                      validator: (v) => v != _senha.text
                          ? 'As senhas não coincidem'
                          : Validators.validarSenha(v)),
                  const SizedBox(height: 16),
                  CustomTextfield(
                      label: 'Telefone',
                      controller: _telefone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _enviar(),
                      validator: Validators.validarCampoObrigatorio),
                ],
                const SizedBox(height: 24),
                if (_erro != null) ...[
                  Semantics(
                      liveRegion: true,
                      child: Text(_erro!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 16),
                ],
                CustomButton(
                    texto: _cadastro ? 'Criar conta' : 'Entrar',
                    onPressed: _enviar,
                    carregando: _carregando),
                if (widget.professor) ...[
                  const SizedBox(height: 24),
                  const Text(
                      'Primeiro acesso? Abra o link do convite enviado pela Coordenação para criar sua senha.',
                      style: TextStyle(fontSize: 13)),
                ],
              ])));

  Widget _boasVindas({bool compacto = false}) => Padding(
      padding: EdgeInsets.all(compacto ? 24 : 40),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compacto) ...[
              Text(_cadastro ? 'Olá' : 'Bem vindo de volta',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(_cadastro ? 'Crie sua conta' : 'Entre com sua conta',
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
            ],
            FilledButton(
                onPressed: _carregando ? null : _alternar,
                style: FilledButton.styleFrom(
                    backgroundColor: AppCores.azul,
                    foregroundColor: AppCores.texto),
                child: Text(_cadastro ? 'Já tenho conta' : 'Criar conta')),
          ]));

  @override
  Widget build(BuildContext context) => TelaAcesso(
      perfil:
          widget.professor ? PerfilVisual.professor : PerfilVisual.coordenacao,
      largura: widget.professor ? 480 : 960,
      child: VidroCard(
          formas: true,
          child: LayoutBuilder(builder: (context, tamanho) {
            if (widget.professor) return _formulario();
            if (tamanho.maxWidth < 600) {
              return Column(mainAxisSize: MainAxisSize.min, children: [
                _formulario(),
                const Divider(height: 1, indent: 28, endIndent: 28),
                AnimatedSwitcher(
                    duration: AppVisual.transicao,
                    child: KeyedSubtree(
                        key: ValueKey(_cadastro),
                        child: _boasVindas(compacto: true))),
              ]);
            }
            final larguraPainel = tamanho.maxWidth / 2;
            return AnimatedSize(
                duration: AppVisual.transicao,
                curve: Curves.easeOut,
                child: Stack(children: [
                  Positioned.fill(
                      child: Center(
                          child: Container(
                              width: 1,
                              color: Colors.white.withValues(alpha: .5)))),
                  AnimatedAlign(
                      duration: AppVisual.transicao,
                      curve: Curves.easeInOut,
                      alignment: _cadastro
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child:
                          SizedBox(width: larguraPainel, child: _formulario())),
                  Positioned.fill(
                      child: AnimatedAlign(
                          duration: AppVisual.transicao,
                          curve: Curves.easeInOut,
                          alignment: _cadastro
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: SizedBox(
                              width: larguraPainel,
                              child: AnimatedSwitcher(
                                  duration: AppVisual.transicao,
                                  child: KeyedSubtree(
                                      key: ValueKey(_cadastro),
                                      child: _boasVindas()))))),
                ]));
          })));
}
