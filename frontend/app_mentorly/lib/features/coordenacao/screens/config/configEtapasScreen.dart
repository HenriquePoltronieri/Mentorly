import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';

// "Ola coordenacao. Antes de comecar, vamos configurar seu ano letivo."
// Passo 1: quantidade de etapas
class ConfigEtapasScreen extends StatefulWidget {
  const ConfigEtapasScreen({super.key});

  @override
  State<ConfigEtapasScreen> createState() => _ConfigEtapasScreenState();
}

class _ConfigEtapasScreenState extends State<ConfigEtapasScreen> {
  final _controller = ConfigAnoLetivoController();
  int _quantidadeSelecionada = 3;
  bool _carregando = false;
  String? _mensagemErro;

  Future<void> _proximo() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _controller.definirQuantidadeEtapas(_quantidadeSelecionada);
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.configNotasEtapa);
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
            const Text('1. Quantidade de Etapas'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 4].map((quantidade) {
                final selecionado = quantidade == _quantidadeSelecionada;
                return ChoiceChip(
                  label: Text('$quantidade Etapa${quantidade > 1 ? 's' : ''}'),
                  selected: selecionado,
                  onSelected: (_) =>
                      setState(() => _quantidadeSelecionada = quantidade),
                );
              }).toList(),
            ),
            TextButton(
              onPressed: () {
                // TODO: permitir digitar uma quantidade personalizada
              },
              child: const Text('Personalizado'),
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