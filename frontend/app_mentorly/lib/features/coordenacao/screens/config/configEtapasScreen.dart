import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';
import 'passoAnoLetivo.dart';

// Passo 1 de 3: quantidade de etapas do ano letivo.
//
// Antes esta tela era um Scaffold sem AppBar, entao nao existia botao de
// voltar em nenhum lugar do fluxo - no navegador o usuario ficava preso.
// Agora todo passo tem AppBar com voltar e mostra em que ponto do fluxo
// esta, e o avanco so acontece pelo botao "Salvar e continuar".
class ConfigEtapasScreen extends StatefulWidget {
  const ConfigEtapasScreen({super.key});

  @override
  State<ConfigEtapasScreen> createState() => _ConfigEtapasScreenState();
}

class _ConfigEtapasScreenState extends State<ConfigEtapasScreen> {
  final _controller = ConfigAnoLetivoController();
  final _personalizadoController = TextEditingController();

  int _quantidadeSelecionada = 3;
  bool _carregando = false;
  bool _carregandoExistente = true;
  String? _mensagemErro;

  @override
  void initState() {
    super.initState();
    _carregarExistente();
  }

  // A configuracao e padrao da escola: se ja existe, o fluxo abre como
  // edicao em vez de comecar do zero toda vez.
  Future<void> _carregarExistente() async {
    try {
      await _controller.carregarConfiguracaoExistente();
      if (!mounted) return;
      if (_controller.etapas.isNotEmpty) {
        setState(() => _quantidadeSelecionada = _controller.etapas.length);
      }
    } catch (_) {
      // Sem configuracao anterior (ou servidor fora): segue com o padrao.
    } finally {
      if (mounted) setState(() => _carregandoExistente = false);
    }
  }

  Future<void> _salvarEContinuar() async {
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
        _mensagemErro =
            'Não foi possível salvar. Verifique sua conexão com o servidor.';
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _escolherQuantidadePersonalizada() async {
    _personalizadoController.text = '$_quantidadeSelecionada';

    final quantidade = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quantidade personalizada'),
        content: TextField(
          controller: _personalizadoController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de etapas',
            helperText: 'De 1 a 12',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              int.tryParse(_personalizadoController.text.trim()),
            ),
            child: const Text('Usar'),
          ),
        ],
      ),
    );

    if (quantidade == null || quantidade < 1 || quantidade > 12) return;
    setState(() => _quantidadeSelecionada = quantidade);
  }

  @override
  void dispose() {
    _personalizadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ano letivo · Passo 1 de 3'),
        // Sai do fluxo e volta ao painel. O AppBar ja da o botao de voltar
        // automatico; este e so o rotulo do passo.
      ),
      body: _carregandoExistente
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PassoAnoLetivo(passoAtual: 1),
                  const SizedBox(height: 20),
                  const Text(
                    'Quantas etapas o ano letivo tem?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Essa configuração vale como padrão para toda a escola.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...[1, 2, 3, 4].map((quantidade) {
                        return ChoiceChip(
                          label: Text(
                            '$quantidade Etapa${quantidade > 1 ? 's' : ''}',
                          ),
                          selected: quantidade == _quantidadeSelecionada,
                          onSelected: (_) => setState(
                            () => _quantidadeSelecionada = quantidade,
                          ),
                        );
                      }),
                      ActionChip(
                        label: Text(
                          _quantidadeSelecionada > 4
                              ? '$_quantidadeSelecionada Etapas'
                              : 'Personalizado',
                        ),
                        avatar: const Icon(Icons.edit, size: 16),
                        onPressed: _escolherQuantidadePersonalizada,
                      ),
                    ],
                  ),
                  if (_controller.jaConfigurado) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sua escola já tem ${_controller.etapas.length} '
                              'etapa(s) configurada(s). Continuar edita o que '
                              'já existe, sem duplicar.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      TextButton(
                        onPressed: _carregando
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _carregando ? null : _salvarEContinuar,
                        child: _carregando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar e continuar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
