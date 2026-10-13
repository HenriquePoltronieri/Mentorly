import '../../../../app/theme.dart';
import '../../../../core/widgets/barra_mentorly.dart';
import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../controllers/configAnoLetivoController.dart';
import '../../services/professoresService.dart';
import 'passoAnoLetivo.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';

// Passo 3 de 3: "Como as notas dos seus alunos sao calculadas?"
//
// Correcoes em relacao a versao anterior:
//  - a tela nao tinha AppBar (nenhum botao de voltar);
//  - ao terminar, ela empurrava a tela de cadastro de professor a forca,
//    sem alternativa, mesmo que a escola ja tivesse professores. Agora o
//    fim do fluxo e "Concluir configuracao", e cadastrar professor e uma
//    opcao - que some quando a escola ja tem professores cadastrados;
//  - os criterios nao eram gravados, porque as etapas ainda nao tinham id;
//  - a tela deixava escolher NOME do criterio, mas nunca perguntava o
//    PESO - todo criterio nascia com peso 0, e o calculo por etapa
//    (Marco 2) nao tem como funcionar sem isso. Agora cada criterio
//    selecionado ganha um campo de peso, com a soma sempre visivel: o
//    calculo so roda quando os pesos ativos de uma etapa somam 100%.
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
  final Map<String, TextEditingController> _pesoControllers = {};

  bool _carregando = false;
  bool _salvo = false;
  String? _mensagemErro;
  int _totalProfessores = 0;

  @override
  void initState() {
    super.initState();
    _carregarEstadoAtual();
  }

  @override
  void dispose() {
    for (final controller in _pesoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _pesoController(String nome) {
    return _pesoControllers.putIfAbsent(nome, () {
      final existente = _controller.criterios
          .where((c) => c.nome == nome)
          .map((c) => c.peso)
          .firstOrNull;
      final texto =
          (existente != null && existente > 0) ? _formatarPeso(existente) : '';
      return TextEditingController(text: texto);
    });
  }

  String _formatarPeso(double valor) => !valor.isFinite
      ? '—'
      : valor == valor.roundToDouble()
          ? valor.toInt().toString()
          : valor.toString();

  double _pesoDigitado(String nome) {
    final texto = _pesoControllers[nome]?.text.trim() ?? '';
    return double.tryParse(texto.replaceAll(',', '.')) ?? 0;
  }

  double get _somaPesos => _criteriosSelecionados
      .map(_pesoDigitado)
      .fold(0.0, (soma, peso) => soma + peso);

  bool get _pesosValidos =>
      _criteriosSelecionados.isNotEmpty &&
      (_somaPesos - 100).abs() < .000001 &&
      _criteriosSelecionados.every((n) {
        final peso = _pesoDigitado(n);
        return peso.isFinite &&
            peso >= 0 &&
            peso <= 100 &&
            (peso * 100 - (peso * 100).round()).abs() < .000001;
      });

  void _guardarRascunho() {
    _controller.criteriosSelecionados = List.of(_criteriosSelecionados);
    _controller.rascunhosPesos.addAll({
      for (final e in _pesoControllers.entries) e.key: e.value.text,
    });
  }

  void _redistribuirPesos() {
    final total = _criteriosSelecionados.length;
    if (total == 0) return;
    final centesimos = 10000 ~/ total;
    for (var i = 0; i < total; i++) {
      final peso =
          (i == total - 1 ? 10000 - centesimos * (total - 1) : centesimos) /
              100;
      _pesoController(_criteriosSelecionados[i]).text = _formatarPeso(peso);
    }
    _guardarRascunho();
  }

  Future<void> _carregarEstadoAtual() async {
    // Criterios ja configurados aparecem marcados: reconfigurar e edicao.
    final jaConfigurados =
        _controller.criteriosSelecionados ?? _controller.nomesDosCriterios;
    setState(() {
      _criteriosSelecionados.addAll(jaConfigurados);
      _criteriosPersonalizados.addAll(
        jaConfigurados.where((c) => !_criteriosPadrao.contains(c)),
      );
      // Prepara o campo de peso de cada um ja com o valor salvo.
      for (final nome in jaConfigurados) {
        _pesoController(nome).text =
            _controller.rascunhosPesos[nome] ?? _pesoController(nome).text;
      }
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

    nomeController.dispose();
    if (nome == null || nome.isEmpty || !mounted) return;
    if (_criteriosPersonalizados.contains(nome) ||
        _criteriosPadrao.contains(nome)) {
      return;
    }

    setState(() {
      _criteriosPersonalizados.add(nome);
      _criteriosSelecionados.add(nome);
      _pesoController(nome);
      _redistribuirPesos();
    });
  }

  Future<bool> _salvar() async {
    if (_criteriosSelecionados.isEmpty) {
      setState(() => _mensagemErro = 'Selecione ao menos um critério');
      return false;
    }
    if (!_pesosValidos) {
      setState(() {
        _mensagemErro = 'A soma dos pesos precisa ser 100%'
            ' (está em ${_formatarPeso(_somaPesos)}%)';
      });
      return false;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _controller.salvarConfiguracao({
        for (final nome in _criteriosSelecionados) nome: _pesoDigitado(nome),
      });

      if (mounted) setState(() => _salvo = true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _mensagemErro =
            e is ApiException ? e.mensagem : 'Não foi possível salvar: $e';
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
      appBar: const BarraMentorly(
          professor: false, aba: 'ano', titulo: 'Ano letivo · Passo 3 de 3'),
      body: ConteudoPagina(
          largura: 680,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
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
                              _pesoController(criterio);
                            } else {
                              _criteriosSelecionados.remove(criterio);
                            }
                            _redistribuirPesos();
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
                if (_criteriosSelecionados.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Peso de cada critério',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A soma dos pesos precisa fechar em 100%.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ..._criteriosSelecionados.map((nome) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text(nome)),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                key: ValueKey('peso_$nome'),
                                controller: _pesoController(nome),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  labelText: 'Peso',
                                  border: AppVisual.bordaPeso,
                                  enabledBorder: AppVisual.bordaPeso,
                                  suffixText: '%',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                ),
                                onChanged: (_) => setState(_guardarRascunho),
                              ),
                            ),
                          ],
                        ),
                      )),
                  Row(
                    children: [
                      Icon(
                        _pesosValidos
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 18,
                        color:
                            _pesosValidos ? Colors.green : Colors.orange[800],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        'Soma: ${_formatarPeso(_somaPesos)}%'
                        '${_pesosValidos ? '' : ' — precisa ser 100%'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _pesosValidos
                              ? Colors.green[800]
                              : Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      )),
                    ],
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
                const SizedBox(height: 24),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed:
                          _carregando ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Voltar'),
                    ),
                    if (_totalProfessores == 0)
                      TextButton(
                        onPressed: _carregando || !_pesosValidos
                            ? null
                            : _salvarECadastrarProfessor,
                        child: const Text('Salvar e cadastrar professor'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _carregando ||
                              !_pesosValidos ||
                              _criteriosSelecionados.any((n) =>
                                  _pesoDigitado(n) < 0 ||
                                  _pesoDigitado(n) > 100)
                          ? null
                          : _concluir,
                      child: _carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _salvo ? 'Concluído' : 'Concluir configuração'),
                    ),
                  ],
                ),
              ],
            ),
          )),
    );
  }
}

extension _PrimeiroOuNulo<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
