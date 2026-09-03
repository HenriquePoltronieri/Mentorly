import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';
import '../../services/professoresService.dart';
import 'passoAnoLetivo.dart';

// Passo 3 de 3: "Como as notas dos seus alunos sao calculadas?"
//
// Correcoes em relacao a versao anterior:
//  - a tela nao tinha AppBar (nenhum botao de voltar);
//  - ao terminar, ela empurrava a tela de cadastro de professor a forca,
//    sem alternativa, mesmo que a escola ja tivesse professores. Agora o
//    fim do fluxo e "Concluir configuracao", e cadastrar professor e uma
//    opcao - que some quando a escola ja tem professores cadastrados;
//  - os criterios nao eram gravados, porque as etapas ainda nao tinham id.
class ConfigCriteriosScreen extends StatefulWidget {
  const ConfigCriteriosScreen({super.key});

  @override
  State<ConfigCriteriosScreen> createState() => _ConfigCriteriosScreenState();
}

class _ConfigCriteriosScreenState extends State<ConfigCriteriosScreen> {
  final _controller = ConfigAnoLetivoController();
  final _professoresService = ProfessoresService();

  final List<String> _criteriosPadrao = [
    'Provas',
    'Trabalhos',
    'Comportamento',
  ];
  final List<String> _criteriosPersonalizados = [];
  final List<String> _criteriosSelecionados = [];

  bool _carregando = false;
  bool _salvo = false;
  String? _mensagemErro;
  int _totalProfessores = 0;

  @override
  void initState() {
    super.initState();
    _carregarEstadoAtual();
  }

  Future<void> _carregarEstadoAtual() async {
    // Criterios ja configurados aparecem marcados: reconfigurar e edicao.
    final jaConfigurados = _controller.nomesDosCriterios;
    setState(() {
      _criteriosSelecionados.addAll(jaConfigurados);
      _criteriosPersonalizados.addAll(
        jaConfigurados.where((c) => !_criteriosPadrao.contains(c)),
      );
    });

    // Saber se a escola ja tem professor decide se faz sentido sugerir o
    // cadastro de um novo no fim do fluxo.
    try {
      final professores = await _professoresService.listarProfessores();
      if (mounted) setState(() => _totalProfessores = professores.length);
    } catch (_) {
      // Sem conexao: o fluxo continua, so nao mostra a contagem.
    }
  }

  Future<void> _adicionarCriterioPersonalizado() async {
    final nomeController = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );

    if (nome == null || nome.isEmpty) return;
    if (_criteriosPersonalizados.contains(nome) ||
        _criteriosPadrao.contains(nome)) {
      return;
    }

    setState(() {
      _criteriosPersonalizados.add(nome);
      _criteriosSelecionados.add(nome);
    });
  }

  Future<bool> _salvar() async {
    if (_criteriosSelecionados.isEmpty) {
      setState(() => _mensagemErro = 'Selecione ao menos um critério');
      return false;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final jaConfigurados = _controller.nomesDosCriterios;

      for (final nome in _criteriosSelecionados) {
        await _controller.adicionarCriterio(nome);
      }
      // Criterio desmarcado sai da configuracao da escola.
      for (final nome in jaConfigurados) {
        if (!_criteriosSelecionados.contains(nome)) {
          await _controller.removerCriterio(nome);
        }
      }

      setState(() => _salvo = true);
      return true;
    } catch (e) {
      setState(() {
        _mensagemErro =
            'Não foi possível salvar. Verifique sua conexão com o servidor.';
      });
      return false;
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _concluir() async {
    if (!await _salvar()) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuração do ano letivo salva')),
    );
    // Volta ao painel, sem forcar nenhuma outra tela.
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.coordenacaoHome,
      (rota) => false,
    );
  }

  Future<void> _salvarECadastrarProfessor() async {
    if (!await _salvar()) return;
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.cadastroProfessor);
  }

  @override
  Widget build(BuildContext context) {
    final todosOsCriterios = [
      ..._criteriosPadrao,
      ..._criteriosPersonalizados.where((c) => !_criteriosPadrao.contains(c)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ano letivo · Passo 3 de 3')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PassoAnoLetivo(passoAtual: 3),
            const SizedBox(height: 20),
            const Text(
              'Como as notas dos seus alunos são calculadas?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Os critérios escolhidos valem para todas as etapas do ano.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...todosOsCriterios.map((criterio) {
                  return FilterChip(
                    label: Text(criterio),
                    selected: _criteriosSelecionados.contains(criterio),
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
                  avatar: const Icon(Icons.add, size: 16),
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
            // O cadastro de professor deixa de ser obrigatorio. Se a escola
            // ja tem professores, o fluxo nem sugere cadastrar outro.
            if (_totalProfessores > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sua escola já tem $_totalProfessores professor(es) '
                        'cadastrado(s). Você pode concluir agora.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _carregando ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Voltar'),
                ),
                const Spacer(),
                if (_totalProfessores == 0)
                  TextButton(
                    onPressed: _carregando ? null : _salvarECadastrarProfessor,
                    child: const Text('Salvar e cadastrar professor'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _carregando ? null : _concluir,
                  child: _carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_salvo ? 'Concluído' : 'Concluir configuração'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
