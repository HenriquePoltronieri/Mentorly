import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/successModal.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../../coordenacao/services/criteriosService.dart';
import '../../../coordenacao/services/etapasService.dart';
import '../../models/atividadeModel.dart';
import '../../services/atividadesService.dart';

// Modal pra criar OU editar uma atividade.
// Fluxo: tela -> AtividadesService -> ApiService -> /api/activities
//
// A atividade nao existe solta: ela pertence a uma ETAPA e a um CRITERIO
// que a Coordenacao configurou para a escola, e vale um numero de pontos.
// Por isso os dois dropdowns sao carregados da API - nada aqui e fixo no
// codigo. Sem etapa configurada nao da para criar atividade nenhuma.
//
// A validacao daqui e so conforto: quem decide de verdade e o backend, que
// recusa etapa ou criterio de outra escola com 404 e valor <= 0 com 400.
class AdicionarAtividadeModal extends StatefulWidget {
  final List<TurmaModel> turmas;
  final AtividadeModel? atividade;

  const AdicionarAtividadeModal({
    super.key,
    required this.turmas,
    this.atividade,
  });

  @override
  State<AdicionarAtividadeModal> createState() =>
      _AdicionarAtividadeModalState();
}

class _AdicionarAtividadeModalState extends State<AdicionarAtividadeModal> {
  final _atividadesService = AtividadesService();
  final _etapasService = EtapasService();
  final _criteriosService = CriteriosService();

  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _dataController;
  late final TextEditingController _valorController;

  TurmaModel? _turmaSelecionada;

  List<Map<String, dynamic>> _etapas = [];
  List<Map<String, dynamic>> _criterios = [];
  int? _etapaId;
  int? _criterioId;

  bool _carregandoEtapas = true;
  bool _carregandoCriterios = false;
  String? _erroEtapas;
  String? _erroCriterios;

  bool _salvando = false;
  String? _mensagemErro;

  bool get _editando => widget.atividade != null;

  // Etapas sao configuradas por ano letivo, e a atividade so aceita etapa do
  // MESMO ano da turma. Toda turma tem ano (o backend exige), entao nao ha
  // mais ano "assumido" pelo calendario do aparelho.
  int? get _anoLetivo => _turmaSelecionada?.anoLetivo;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.atividade?.nome ?? '');
    _descricaoController =
        TextEditingController(text: widget.atividade?.descricao ?? '');
    // due_date chega como ISO completo; a tela mostra so a parte da data
    final data = widget.atividade?.dataEntrega ?? '';
    _dataController = TextEditingController(
      text: data.contains('T') ? data.split('T').first : data,
    );
    _valorController = TextEditingController(
      text: _formatar(widget.atividade?.notaMaxima),
    );

    if (widget.turmas.isNotEmpty) {
      _turmaSelecionada = widget.turmas.firstWhere(
        (t) => t.id == widget.atividade?.turmaId,
        orElse: () => widget.turmas.first,
      );
    }

    _carregarEtapas();
  }

  // 20.0 vira "20"; 13.5 continua "13.5". Evita "Vale 20.0 pontos".
  String _formatar(double? valor) {
    if (valor == null) return '';
    return valor == valor.roundToDouble()
        ? valor.toInt().toString()
        : valor.toString();
  }

  Future<void> _carregarEtapas() async {
    setState(() {
      _carregandoEtapas = true;
      _erroEtapas = null;
    });

    try {
      final lista = await _etapasService.listarEtapas(anoLetivo: _anoLetivo);
      if (!mounted) return;

      final etapas = lista.cast<Map<String, dynamic>>();
      // Ao editar, reabre na etapa que a atividade ja tem - desde que ela
      // ainda exista na configuracao da escola.
      final etapaAtual = widget.atividade?.etapaId;
      final selecionada =
          etapas.any((e) => e['id'] == etapaAtual) ? etapaAtual : null;

      setState(() {
        _etapas = etapas;
        _etapaId = selecionada;
        _carregandoEtapas = false;
      });

      if (selecionada != null) _carregarCriterios(selecionada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroEtapas = e.mensagem;
        _carregandoEtapas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroEtapas = 'Não foi possível conectar ao servidor';
        _carregandoEtapas = false;
      });
    }
  }

  Future<void> _carregarCriterios(int etapaId) async {
    setState(() {
      _carregandoCriterios = true;
      _erroCriterios = null;
      _criterios = [];
      _criterioId = null;
    });

    try {
      final lista = await _criteriosService.listarCriterios(etapaId);
      if (!mounted) return;

      final criterios = lista.cast<Map<String, dynamic>>();
      final criterioAtual = widget.atividade?.criterioId;
      final selecionado =
          criterios.any((c) => c['id'] == criterioAtual) ? criterioAtual : null;

      setState(() {
        _criterios = criterios;
        _criterioId = selecionado;
        _carregandoCriterios = false;
      });

      if (selecionado != null) _sugerirValor(selecionado);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroCriterios = e.mensagem;
        _carregandoCriterios = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erroCriterios = 'Não foi possível conectar ao servidor';
        _carregandoCriterios = false;
      });
    }
  }

  // A Coordenacao define um valor de referencia por criterio. Ele entra como
  // sugestao quando o campo esta vazio - o professor continua livre para
  // colocar outro numero (uma prova de 20 num criterio de 10 e valida).
  void _sugerirValor(int criterioId) {
    if (_valorController.text.trim().isNotEmpty) return;

    final criterio = _criterios.firstWhere(
      (c) => c['id'] == criterioId,
      orElse: () => <String, dynamic>{},
    );
    final sugestao = criterio['nota_maxima'];
    if (sugestao is num && sugestao > 0) {
      _valorController.text = _formatar(sugestao.toDouble());
    }
  }

  // Sem etapa configurada nao ha atividade possivel: a Coordenacao precisa
  // configurar o ano letivo antes.
  bool get _podeSalvar =>
      !_salvando &&
      !_carregandoEtapas &&
      _erroEtapas == null &&
      _etapas.isNotEmpty;

  Future<void> _salvar() async {
    final erro = _validar();
    if (erro != null) {
      setState(() => _mensagemErro = erro);
      return;
    }

    setState(() {
      _salvando = true;
      _mensagemErro = null;
    });

    final valor =
        double.parse(_valorController.text.trim().replaceAll(',', '.'));

    try {
      if (_editando) {
        await _atividadesService.atualizarAtividade(
          id: widget.atividade!.id,
          turmaId: _turmaSelecionada!.id,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          dataEntrega: _dataController.text.trim(),
          etapaId: _etapaId!,
          criterioId: _criterioId!,
          notaMaxima: valor,
        );
      } else {
        await _atividadesService.cadastrarAtividade(
          turmaId: _turmaSelecionada!.id,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          dataEntrega: _dataController.text.trim(),
          etapaId: _etapaId!,
          criterioId: _criterioId!,
          notaMaxima: valor,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      await mostrarSucesso(
        context,
        _editando
            ? 'Atividade atualizada com sucesso'
            : 'Atividade adicionada com sucesso a "${_turmaSelecionada!.nome}"',
      );
    } on ApiException catch (e) {
      setState(() => _mensagemErro = e.mensagem);
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  String? _validar() {
    if (_turmaSelecionada == null) return 'Selecione uma turma';
    if (_nomeController.text.trim().isEmpty) {
      return 'Digite o nome da atividade';
    }
    if (_etapaId == null) return 'Escolha a etapa da atividade';
    if (_criterioId == null) return 'Escolha o critério da atividade';

    final texto = _valorController.text.trim().replaceAll(',', '.');
    if (texto.isEmpty) return 'Informe quanto a atividade vale';
    final valor = double.tryParse(texto);
    if (valor == null) return 'O valor da atividade precisa ser um número';
    if (valor <= 0) return 'O valor da atividade precisa ser maior que zero';

    return null;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _dataController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editando ? 'Editar Atividade:' : 'Adicionar Atividade:',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da atividade',
                  hintText: 'Exemplo "Prova 1 - Frações"',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Opcional',
                ),
              ),
              const SizedBox(height: 16),
              _construirEtapa(),
              const SizedBox(height: 12),
              _construirCriterio(),
              const SizedBox(height: 12),
              TextField(
                controller: _valorController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor máximo da atividade',
                  hintText: 'Quantos pontos ela vale. Exemplo "20"',
                  suffixText: 'pontos',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: 'Data de entrega',
                  hintText: 'AAAA-MM-DD (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TurmaModel>(
                initialValue: _turmaSelecionada,
                decoration: const InputDecoration(labelText: 'Pra qual turma?'),
                items: widget.turmas
                    .map((turma) => DropdownMenuItem(
                          value: turma,
                          child: Text(turma.nome),
                        ))
                    .toList(),
                onChanged: (turma) {
                  setState(() => _turmaSelecionada = turma);
                  // Trocar de turma pode trocar o ano letivo, e com ele o
                  // conjunto de etapas validas.
                  _carregarEtapas();
                },
              ),
              if (_mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _mensagemErro!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _podeSalvar ? _salvar : null,
                  child: _salvando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editando ? 'Salvar' : 'Adicionar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirEtapa() {
    if (_carregandoEtapas) {
      return const _LinhaEstado(
        icone: Icons.hourglass_empty,
        texto: 'Carregando etapas...',
      );
    }

    if (_erroEtapas != null) {
      return _LinhaEstado(
        icone: Icons.error_outline,
        texto: 'Erro ao carregar etapas: $_erroEtapas',
        cor: Colors.red,
        aoTentarDeNovo: _carregarEtapas,
      );
    }

    if (_etapas.isEmpty) {
      return _LinhaEstado(
        icone: Icons.info_outline,
        texto: 'A Coordenação ainda não configurou as etapas do ano letivo '
            '${_anoLetivo ?? 'da turma'}. Sem elas não é possível criar '
            'atividades.',
        cor: Colors.orange[800],
        aoTentarDeNovo: _carregarEtapas,
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _etapaId,
      decoration: const InputDecoration(labelText: 'Etapa'),
      items: _etapas
          .map((etapa) => DropdownMenuItem(
                value: etapa['id'] as int,
                child: Text(etapa['nome']?.toString() ?? 'Etapa'),
              ))
          .toList(),
      onChanged: (etapaId) {
        if (etapaId == null) return;
        setState(() => _etapaId = etapaId);
        _carregarCriterios(etapaId);
      },
    );
  }

  Widget _construirCriterio() {
    if (_etapaId == null) {
      return const _LinhaEstado(
        icone: Icons.arrow_upward,
        texto: 'Escolha a etapa para ver os critérios.',
      );
    }

    if (_carregandoCriterios) {
      return const _LinhaEstado(
        icone: Icons.hourglass_empty,
        texto: 'Carregando critérios...',
      );
    }

    if (_erroCriterios != null) {
      return _LinhaEstado(
        icone: Icons.error_outline,
        texto: 'Erro ao carregar critérios: $_erroCriterios',
        cor: Colors.red,
        aoTentarDeNovo: () => _carregarCriterios(_etapaId!),
      );
    }

    if (_criterios.isEmpty) {
      return _LinhaEstado(
        icone: Icons.info_outline,
        texto: 'Nenhum critério configurado para esta etapa. '
            'A Coordenação precisa cadastrá-los.',
        cor: Colors.orange[800],
        aoTentarDeNovo: () => _carregarCriterios(_etapaId!),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _criterioId,
      decoration: const InputDecoration(labelText: 'Critério'),
      items: _criterios
          .map((criterio) => DropdownMenuItem(
                value: criterio['id'] as int,
                child: Text(criterio['nome']?.toString() ?? 'Critério'),
              ))
          .toList(),
      onChanged: (criterioId) {
        if (criterioId == null) return;
        setState(() => _criterioId = criterioId);
        _sugerirValor(criterioId);
      },
    );
  }
}

// Linha usada no lugar do dropdown enquanto ele nao pode ser mostrado:
// carregando, erro, ou lista vazia.
class _LinhaEstado extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color? cor;
  final VoidCallback? aoTentarDeNovo;

  const _LinhaEstado({
    required this.icone,
    required this.texto,
    this.cor,
    this.aoTentarDeNovo,
  });

  @override
  Widget build(BuildContext context) {
    final corFinal = cor ?? Colors.grey[700];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 18, color: corFinal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 13, color: corFinal),
          ),
        ),
        if (aoTentarDeNovo != null)
          TextButton(
            onPressed: aoTentarDeNovo,
            child: const Text('Tentar de novo'),
          ),
      ],
    );
  }
}
