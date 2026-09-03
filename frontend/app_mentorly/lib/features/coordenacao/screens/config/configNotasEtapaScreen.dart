import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';
import 'passoAnoLetivo.dart';

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
    _minimaController.text = etapa?.notaMinima?.toString() ?? '';
    _maximaController.text = etapa?.notaMaxima?.toString() ?? '';
  }

  Future<void> _salvarEContinuar() async {
    final minima = double.tryParse(_minimaController.text.replaceAll(',', '.'));
    final maxima = double.tryParse(_maximaController.text.replaceAll(',', '.'));

    if (minima == null || maxima == null) {
      setState(() {
        _mensagemErro = 'Preencha os dois campos com números válidos';
      });
      return;
    }

    if (minima >= maxima) {
      setState(() {
        _mensagemErro = 'A nota mínima precisa ser menor que a máxima';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _controller.salvarNotasEtapa(_etapaAtual, minima, maxima);

      if (!mounted) return;

      if (_etapaAtual < _totalEtapas) {
        setState(() {
          _etapaAtual++;
          _preencherCamposDaEtapa();
        });
      } else {
        Navigator.pushNamed(context, AppRoutes.configCriterios);
      }
    } catch (e) {
      setState(() {
        _mensagemErro =
            'Não foi possível salvar. Verifique sua conexão com o servidor.';
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Dentro do laco de etapas, voltar recua uma etapa. So na primeira etapa
  // e que o voltar sai desta tela.
  void _voltar() {
    if (_etapaAtual > 1) {
      setState(() {
        _etapaAtual--;
        _mensagemErro = null;
        _preencherCamposDaEtapa();
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
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
        appBar: AppBar(
          title: const Text('Ano letivo · Passo 2 de 3'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _carregando ? null : _voltar,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'Qual a nota mínima e máxima para aprovação do aluno nesta etapa?',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minimaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mínima',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maximaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Máxima',
                        border: OutlineInputBorder(),
                      ),
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
              const Spacer(),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _carregando ? null : _voltar,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(_etapaAtual > 1 ? 'Etapa anterior' : 'Voltar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _carregando || _totalEtapas == 0
                        ? null
                        : _salvarEContinuar,
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
        ),
      ),
    );
  }
}
