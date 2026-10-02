import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/apiService.dart';
import '../../controllers/configAnoLetivoController.dart';
import '../../models/anoLetivoModel.dart';
import '../../services/anosLetivosService.dart';

// Anos letivos da escola: listar, criar, marcar como atual, encerrar e
// excluir (so ano sem turma nem etapa).
// Fluxo: tela -> AnosLetivosService -> ApiService -> /api/config/anos-letivos
//
// O ano ATUAL e o contexto padrao do dashboard do Professor e das turmas
// novas. Ano em planejamento aceita turmas e etapas, mas nao vira o contexto
// do dashboard enquanto nao for o atual. Encerrar so troca o status: os
// dados continuam disponiveis.
class AnosLetivosScreen extends StatefulWidget {
  const AnosLetivosScreen({super.key});

  @override
  State<AnosLetivosScreen> createState() => _AnosLetivosScreenState();
}

class _AnosLetivosScreenState extends State<AnosLetivosScreen> {
  final _service = AnosLetivosService();

  List<AnoLetivoModel> _anos = [];
  bool _carregando = true;
  String? _mensagemErro;
  int? _alterandoId; // evita duplo toque enquanto uma operacao esta em curso

  @override
  void initState() {
    super.initState();
    _buscarAnos();
  }

  Future<void> _buscarAnos() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });
    try {
      final anos = await _service.listarAnos();
      if (!mounted) return;
      setState(() => _anos = anos);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = e.mensagem);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  AnoLetivoModel? get _anoAtual {
    for (final ano in _anos) {
      if (ano.ehAtual) return ano;
    }
    return null;
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<bool> _confirmar({
    required String titulo,
    required String texto,
    required String rotuloConfirmar,
  }) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: Text(rotuloConfirmar),
          ),
        ],
      ),
    );
    return confirmou == true;
  }

  // Roda uma operacao da lista com protecao contra duplo toque e mostra o
  // erro que o backend devolver (409, 404...).
  Future<void> _executar(AnoLetivoModel ano, Future<void> Function() acao) async {
    setState(() => _alterandoId = ano.id);
    try {
      await acao();
      await _buscarAnos();
    } on ApiException catch (e) {
      if (!mounted) return;
      _avisar(e.mensagem);
    } catch (_) {
      if (!mounted) return;
      _avisar('Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _alterandoId = null);
    }
  }

  Future<void> _tornarAtual(AnoLetivoModel ano) async {
    var encerrarAtual = false;
    final atual = _anoAtual;
    if (atual != null && atual.id != ano.id) {
      final confirmou = await _confirmar(
        titulo: 'Trocar o ano atual',
        texto: 'O ano letivo ${atual.ano} é o atual e será encerrado. '
            'Tornar ${ano.ano} o ano atual?',
        rotuloConfirmar: 'Trocar',
      );
      if (!confirmou) return;
      encerrarAtual = true;
    }
    await _executar(
      ano,
      () => _service.alterarStatus(
        id: ano.id,
        status: AnoLetivoModel.atual,
        encerrarAtual: encerrarAtual,
      ),
    );
  }

  Future<void> _encerrar(AnoLetivoModel ano) async {
    final confirmou = await _confirmar(
      titulo: 'Encerrar ano letivo',
      texto: 'Encerrar ${ano.ano}? Os dados continuam disponíveis, mas não '
          'será possível criar turmas nem etapas novas nele.',
      rotuloConfirmar: 'Encerrar',
    );
    if (!confirmou) return;
    await _executar(
      ano,
      () => _service.alterarStatus(id: ano.id, status: AnoLetivoModel.encerrado),
    );
  }

  Future<void> _reabrir(AnoLetivoModel ano) async {
    await _executar(
      ano,
      () => _service.alterarStatus(
        id: ano.id,
        status: AnoLetivoModel.planejamento,
      ),
    );
  }

  Future<void> _excluir(AnoLetivoModel ano) async {
    final confirmou = await _confirmar(
      titulo: 'Excluir ano letivo',
      texto: 'Excluir o ano letivo ${ano.ano}? Essa ação não pode ser desfeita.',
      rotuloConfirmar: 'Excluir',
    );
    if (!confirmou) return;
    await _executar(ano, () => _service.excluirAno(ano.id));
  }

  // Configurar etapas e criterios DESTE ano (o fluxo existente de 3 passos).
  void _configurar(AnoLetivoModel ano) {
    ConfigAnoLetivoController().anoLetivo = ano.ano;
    Navigator.pushNamed(context, AppRoutes.configEtapas);
  }

  Future<void> _novoAno() async {
    // Sugestao editavel, nao regra: o proximo ano depois do mais novo da
    // escola (ou o ano do calendario, se a escola ainda nao tem nenhum).
    final sugestao = _anos.isEmpty
        ? DateTime.now().year
        : _anos.map((a) => a.ano).reduce((a, b) => a > b ? a : b) + 1;

    final escolha = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NovoAnoDialog(
        anoSugerido: sugestao,
        oferecerMarcarAtual: _anoAtual == null,
      ),
    );
    if (escolha == null) return;

    setState(() => _carregando = true);
    try {
      await _service.criarAno(
        ano: escolha['ano'] as int,
        status: escolha['atual'] == true ? AnoLetivoModel.atual : null,
      );
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensagem);
    } catch (_) {
      if (mounted) _avisar('Não foi possível conectar ao servidor');
    }
    await _buscarAnos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anos Letivos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _carregando ? null : _novoAno,
        icon: const Icon(Icons.add),
        label: const Text('Novo ano letivo'),
      ),
      body: RefreshIndicator(onRefresh: _buscarAnos, child: _corpo()),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mensagemErro != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Center(
            child: Text(_mensagemErro!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    if (_anos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.calendar_month_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Nenhum ano letivo cadastrado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cadastre o primeiro ano e marque-o como atual para criar turmas '
            'e configurar etapas.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _anos.length + 1,
      itemBuilder: (context, indice) {
        if (indice == 0) return const _Explicacao();
        return _cartaoDoAno(_anos[indice - 1]);
      },
    );
  }

  Widget _cartaoDoAno(AnoLetivoModel ano) {
    final ocupado = _alterandoId == ano.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.calendar_today, size: 20)),
        title: Text('Ano letivo ${ano.ano}'),
        subtitle: Text(
          '${ano.totalTurmas} turma(s) • ${ano.totalEtapas} etapa(s)',
        ),
        onTap: ano.estaEncerrado ? null : () => _configurar(ano),
        trailing: ocupado
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EtiquetaStatus(ano: ano),
                  PopupMenuButton<String>(
                    tooltip: 'Ações do ano ${ano.ano}',
                    onSelected: (acao) {
                      if (acao == 'configurar') _configurar(ano);
                      if (acao == 'atual') _tornarAtual(ano);
                      if (acao == 'encerrar') _encerrar(ano);
                      if (acao == 'reabrir') _reabrir(ano);
                      if (acao == 'excluir') _excluir(ano);
                    },
                    itemBuilder: (context) => [
                      if (!ano.estaEncerrado)
                        const PopupMenuItem(
                          value: 'configurar',
                          child: Text('Configurar etapas e critérios'),
                        ),
                      if (ano.estaEmPlanejamento)
                        const PopupMenuItem(
                          value: 'atual',
                          child: Text('Tornar o ano atual'),
                        ),
                      if (ano.ehAtual)
                        const PopupMenuItem(
                          value: 'encerrar',
                          child: Text('Encerrar ano'),
                        ),
                      if (ano.estaEncerrado)
                        const PopupMenuItem(
                          value: 'reabrir',
                          child: Text('Reabrir em planejamento'),
                        ),
                      if (!ano.temDados)
                        const PopupMenuItem(
                          value: 'excluir',
                          child: Text('Excluir'),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _Explicacao extends StatelessWidget {
  const _Explicacao();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'O ano atual é o contexto do dashboard e o ano das turmas novas. '
        'Anos em planejamento já aceitam turmas e etapas. Anos encerrados '
        'mantêm os dados, mas não recebem turmas nem etapas novas.',
        style: TextStyle(color: Colors.grey[700], fontSize: 13),
      ),
    );
  }
}

class _EtiquetaStatus extends StatelessWidget {
  final AnoLetivoModel ano;

  const _EtiquetaStatus({required this.ano});

  @override
  Widget build(BuildContext context) {
    final Color cor;
    if (ano.ehAtual) {
      cor = Colors.green;
    } else if (ano.estaEncerrado) {
      cor = Colors.grey;
    } else {
      cor = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ano.rotuloStatus,
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Dialogo de cadastro: ano (numero) e, se a escola ainda nao tem ano atual,
// a opcao de ja marcar este como atual.
class _NovoAnoDialog extends StatefulWidget {
  final int anoSugerido;
  final bool oferecerMarcarAtual;

  const _NovoAnoDialog({
    required this.anoSugerido,
    required this.oferecerMarcarAtual,
  });

  @override
  State<_NovoAnoDialog> createState() => _NovoAnoDialogState();
}

class _NovoAnoDialogState extends State<_NovoAnoDialog> {
  late final TextEditingController _anoController;
  late bool _marcarAtual;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _anoController = TextEditingController(text: '${widget.anoSugerido}');
    _marcarAtual = widget.oferecerMarcarAtual;
  }

  void _salvar() {
    final ano = int.tryParse(_anoController.text.trim());
    if (ano == null || ano < 2000 || ano > 2100) {
      setState(() => _erro = 'Informe um ano entre 2000 e 2100');
      return;
    }
    Navigator.pop(context, {'ano': ano, 'atual': _marcarAtual});
  }

  @override
  void dispose() {
    _anoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo ano letivo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _anoController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Ano',
              hintText: 'Exemplo 2027',
              errorText: _erro,
            ),
            onSubmitted: (_) => _salvar(),
          ),
          if (widget.oferecerMarcarAtual)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _marcarAtual,
              onChanged: (valor) => setState(() => _marcarAtual = valor ?? false),
              title: const Text('Marcar como ano atual'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _salvar, child: const Text('Cadastrar')),
      ],
    );
  }
}
