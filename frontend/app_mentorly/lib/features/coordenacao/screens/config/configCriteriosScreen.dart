import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';

// "Como as notas dos seus alunos sao calculadas?"
class ConfigCriteriosScreen extends StatefulWidget {
  const ConfigCriteriosScreen({super.key});

  @override
  State<ConfigCriteriosScreen> createState() => _ConfigCriteriosScreenState();
}

class _ConfigCriteriosScreenState extends State<ConfigCriteriosScreen> {
  final _controller = ConfigAnoLetivoController();
  final List<String> _criteriosPadrao = [
    'Provas',
    'Trabalhos',
    'Comportamento',
  ];
  final List<String> _criteriosSelecionados = [];
  final List<String> _criteriosPersonalizados = [];

  bool _carregando = false;
  String? _mensagemErro;

  Future<void> _adicionarCriterioPersonalizado() async {
    final nomeController = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Novo critério'),
          content: TextField(
            controller: nomeController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ex: Participação'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, nomeController.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    if (nome == null || nome.isEmpty) return;

    setState(() {
      _criteriosPersonalizados.add(nome);
      _criteriosSelecionados.add(nome);
    });
  }

  Future<void> _proximo() async {
    if (_criteriosSelecionados.isEmpty) {
      setState(() {
        _mensagemErro = 'Selecione ao menos um critério';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      for (final nome in _criteriosSelecionados) {
        await _controller.adicionarCriterio(nome);
      }
      await _controller.finalizarConfiguracao();

      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.cadastroProfessor);
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
    final todosOsCriterios = [..._criteriosPadrao, ..._criteriosPersonalizados];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ola coordenacao.', style: TextStyle(fontSize: 20)),
            const Text('Antes de comecar, vamos configurar seu ano letivo.'),
            const SizedBox(height: 24),
            const Text('Como as notas dos seus alunos sao calculadas?'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ...todosOsCriterios.map((criterio) {
                  final selecionado = _criteriosSelecionados.contains(criterio);
                  return ChoiceChip(
                    label: Text(criterio),
                    selected: selecionado,
                    onSelected: (marcado) {
                      setState(() {
                        if (marcado) {
                          _criteriosSelecionados.add(criterio);
                        } else {
                          _criteriosSelecionados.remove(criterio);
                        }
                      });
                    },
                  );
                }),
                ActionChip(
                  label: const Text('Adicionar'),
                  onPressed: _adicionarCriterioPersonalizado,
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