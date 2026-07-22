import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';

// Pergunta nota minima e maxima de cada etapa, uma etapa por vez
class ConfigNotasEtapaScreen extends StatefulWidget {
  const ConfigNotasEtapaScreen({super.key});

  @override
  State<ConfigNotasEtapaScreen> createState() =>
      _ConfigNotasEtapaScreenState();
}

class _ConfigNotasEtapaScreenState extends State<ConfigNotasEtapaScreen> {
  final _controller = ConfigAnoLetivoController();
  final _minimaController = TextEditingController();
  final _maximaController = TextEditingController();
  int _etapaAtual = 1;
  bool _carregando = false;
  String? _mensagemErro;

  Future<void> _proximo() async {
    final minima = double.tryParse(_minimaController.text);
    final maxima = double.tryParse(_maximaController.text);

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

      final totalEtapas = _controller.etapas.length;

      if (_etapaAtual < totalEtapas) {
        setState(() {
          _etapaAtual++;
          _minimaController.clear();
          _maximaController.clear();
        });
      } else if (mounted) {
        Navigator.pushNamed(context, AppRoutes.configCriterios);
      }
    } catch (e) {
      setState(() {
        _mensagemErro = 'Não foi possível salvar. Verifique sua conexão com o servidor.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _minimaController.dispose();
    _maximaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ola coordenacao.', style: TextStyle(fontSize: 20)),
            const Text('Antes de comecar, vamos configurar seu ano letivo.'),
            const SizedBox(height: 24),
            Text('$_etapaAtual. Etapa'),
            const Text(
              'Qual a nota minima e maxima para aprovacao do aluno nesta etapa?',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minimaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minima'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maximaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Maxima'),
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
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _carregando ? null : _proximo,
                child: _carregando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Proximo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}