import 'package:flutter/material.dart';
import '../../../../core/widgets/barra_mentorly.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';
import 'passoAnoLetivo.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';

// Passo 2 de 3: nota minima e maxima de cada etapa, uma etapa por vez.
//
// Correcoes em relacao a versao anterior:
//  - a tela nao tinha AppBar, entao nao havia como voltar;
//  - o laco de etapas avancava por setState, entao o voltar do navegador
//    jogava o usuario para fora do fluxo inteiro em vez de voltar uma
//    etapa. Agora o voltar respeita o laco: so sai da tela quando esta na
//    primeira etapa;
//  - as notas nunca eram gravadas, porque a etapa ainda nao tinha id. O
//    controller agora cria as etapas no passo 1, entao aqui elas ja tem id.
class ConfigNotasEtapaScreen extends StatefulWidget {
  const ConfigNotasEtapaScreen({super.key});

  @override
  State<ConfigNotasEtapaScreen> createState() => _ConfigNotasEtapaScreenState();
}

class _ConfigNotasEtapaScreenState extends State<ConfigNotasEtapaScreen> {
  final _controller = ConfigAnoLetivoController();
  final _minimaController = TextEditingController();
  final _maximaController = TextEditingController();

  int _etapaAtual = 1;
  bool _carregando = false;
  String? _mensagemErro;
  String? _erroMinimo;
  String? _erroPontos;

  int get _totalEtapas => _controller.etapas.length;

  @override
  void initState() {
    super.initState();
    _preencherCamposDaEtapa();
  }

  // Se a etapa ja tem notas configuradas, os campos abrem preenchidos:
  // reconfigurar e edicao, nao recomeco.
  void _preencherCamposDaEtapa() {
    final etapa = _controller.etapaPorNumero(_etapaAtual);
    final rascunho = _controller.rascunhosNotas[_etapaAtual];
    _minimaController.text =
        rascunho?[0] ?? etapa?.notaMinima?.toString() ?? '';
    _maximaController.text =
        rascunho?[1] ?? etapa?.notaMaxima?.toString() ?? '';
  }

  void _guardarRascunho() {
    _controller.rascunhosNotas[_etapaAtual] = [
      _minimaController.text,
      _maximaController.text
    ];
  }

  double get _pontosAno => _controller.etapas.fold(0.0, (total, etapa) {
        final texto = _controller.rascunhosNotas[etapa.numero]?[1];
        return total +
            (texto == null
                ? etapa.notaMaxima ?? 0
                : double.tryParse(texto.replaceAll(',', '.')) ?? 0);
      });

  void _campoAlterado(String _) {
    setState(_guardarRascunho);
  }

  Future<void> _salvarEContinuar() async {
    if (_carregando) return;
    FocusScope.of(context).unfocus();
    _guardarRascunho();
    final minima = double.tryParse(_minimaController.text.replaceAll(',', '.'));
    final maxima = double.tryParse(_maximaController.text.replaceAll(',', '.'));

    String? validar(double? valor) {
      if (valor == null || !valor.isFinite) return 'Digite um número válido';
      if (valor < 0 || valor > 999.99) return 'Use de 0 a 999,99 pontos';
      if ((valor * 100 - (valor * 100).round()).abs() > .000001) {
        return 'Use até duas casas decimais';
      }
      return null;
    }

    setState(() {
      _erroMinimo = validar(minima);
      _erroPontos = validar(maxima);
      if (_erroMinimo == null && _erroPontos == null && minima! >= maxima!) {
        _erroMinimo = 'O mínimo deve ser menor que os pontos da etapa';
      }
    });
    if (_erroMinimo != null || _erroPontos != null) return;

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _controller.salvarNotasEtapa(_etapaAtual, minima!, maxima!);

      if (!mounted) return;

      if (_etapaAtual < _totalEtapas) {
        setState(() {
          _etapaAtual++;
          _erroMinimo = null;
          _erroPontos = null;
          _preencherCamposDaEtapa();
        });
      } else {
        Navigator.pushNamed(context, AppRoutes.configCriterios);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensagemErro = e is ApiException
            ? e.mensagem
            : e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Dentro do laco de etapas, voltar recua uma etapa. So na primeira etapa
  // e que o voltar sai desta tela.
  void _voltar() {
    _guardarRascunho();
    if (_etapaAtual > 1) {
      setState(() {
        _etapaAtual--;
        _mensagemErro = null;
        _erroMinimo = null;
        _erroPontos = null;
        _preencherCamposDaEtapa();
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _guardarRascunho();
    _minimaController.dispose();
    _maximaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ultimaEtapa = _etapaAtual >= _totalEtapas;

    return PopScope(
      // Intercepta o voltar do sistema/navegador para recuar uma etapa em
      // vez de abandonar o fluxo inteiro.
      canPop: _etapaAtual <= 1,
      onPopInvokedWithResult: (jaSaiu, _) {
        if (!jaSaiu && _etapaAtual > 1) _voltar();
      },
      child: Scaffold(
        appBar: BarraMentorly(
            professor: false,
            aba: 'ano',
            titulo: 'Ano letivo · Passo 2 de 3',
            onVoltar: _voltar),
        body: ConteudoPagina(
            largura: 680,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  const PassoAnoLetivo(passoAtual: 2),
                  const SizedBox(height: 20),
                  Text(
                    _totalEtapas == 0
                        ? 'Nenhuma etapa configurada'
                        : 'Etapa $_etapaAtual de $_totalEtapas',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Defina quantos pontos esta etapa vale e quantos o aluno precisa para aprovação.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      TextField(
                        controller: _minimaController,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        onChanged: _campoAlterado,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Mínimo para aprovação',
                          errorText: _erroMinimo,
                          helperText:
                              'Precisa ser menor que os pontos da etapa.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _maximaController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _salvarEContinuar(),
                        onChanged: _campoAlterado,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Pontos da etapa',
                          errorText: _erroPontos,
                          helperText: 'Pontuação máxima que esta etapa vale.',
                        ),
                      ),
                    ],
                  ),
                  if (_mensagemErro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _mensagemErro!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                      'Total do ano até agora: ${_pontosAno.toStringAsFixed(2)} pontos.'),
                  const Text(
                      'O total depende da escala adotada pela escola; não precisa ser 100.',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _carregando ? null : _voltar,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label:
                            Text(_etapaAtual > 1 ? 'Etapa anterior' : 'Voltar'),
                      ),
                      FilledButton(
                        onPressed: _carregando || _totalEtapas == 0
                            ? null
                            : _salvarEContinuar,
                        child: _carregando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                ultimaEtapa
                                    ? 'Salvar e continuar'
                                    : 'Salvar e ir para a etapa ${_etapaAtual + 1}',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
      ),
    );
  }
}
