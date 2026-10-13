import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../models/anoLetivoModel.dart';
import '../../models/turmaModel.dart';
import '../../services/anosLetivosService.dart';
import '../../services/turmasService.dart';

// Modal da coordenacao pra criar OU editar uma turma.
// Fluxo: tela -> TurmasService -> ApiService -> /api/classes
//
// O formulario pede nome, descricao e o ANO LETIVO da turma: um dos anos que a
// escola cadastrou em Anos Letivos (por padrao, o ano atual). Anos encerrados
// nao recebem turma nova.
//
// uso (criar):  showDialog(context: context, builder: (_) => const AdicionarTurmaModal())
// uso (editar): showDialog(context: context, builder: (_) => AdicionarTurmaModal(turma: turma))
// retorna 'true' via Navigator.pop quando a turma foi salva com sucesso
class AdicionarTurmaModal extends StatefulWidget {
  final TurmaModel? turma;

  const AdicionarTurmaModal({super.key, this.turma});

  @override
  State<AdicionarTurmaModal> createState() => _AdicionarTurmaModalState();
}

class _AdicionarTurmaModalState extends State<AdicionarTurmaModal> {
  final _turmasService = TurmasService();
  final _anosService = AnosLetivosService();

  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;

  List<AnoLetivoModel> _anos = [];
  int? _anoSelecionado;
  bool _carregandoAnos = true;

  bool _carregando = false;
  String? _mensagemErro;

  bool get _editando => widget.turma != null;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.turma?.nome ?? '');
    _descricaoController =
        TextEditingController(text: widget.turma?.descricao ?? '');
    _carregarAnos();
  }

  // Anos que a turma pode ter: os nao encerrados e, ao editar, tambem o ano
  // que ela ja tem. Ao criar, vem marcado o ano atual da escola.
  Future<void> _carregarAnos() async {
    try {
      final todos = await _anosService.listarAnos();
      final anoDaTurma = widget.turma?.anoLetivo;
      final permitidos =
          todos.where((a) => !a.estaEncerrado || a.ano == anoDaTurma).toList();

      int? escolhido = anoDaTurma;
      if (escolhido == null) {
        for (final ano in permitidos) {
          if (ano.ehAtual) escolhido = ano.ano;
        }
      }

      if (!mounted) return;
      setState(() {
        _anos = permitidos;
        _anoSelecionado = escolhido;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _mensagemErro = e.mensagem);
    } catch (_) {
      if (mounted) {
        setState(
            () => _mensagemErro = 'Não foi possível carregar os anos letivos');
      }
    } finally {
      if (mounted) setState(() => _carregandoAnos = false);
    }
  }

  Future<void> _salvar() async {
    if (_carregando || _carregandoAnos) return;
    if (_nomeController.text.trim().isEmpty) {
      setState(() => _mensagemErro = 'Digite o nome da turma');
      return;
    }
    if (_anoSelecionado == null) {
      setState(() => _mensagemErro =
          'Escolha o ano letivo. Se a escola ainda não tem um, cadastre em Anos Letivos.');
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      if (_editando) {
        await _turmasService.atualizarTurma(
          id: widget.turma!.id,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          anoLetivo: _anoSelecionado,
        );
      } else {
        await _turmasService.cadastrarTurma(
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          anoLetivo: _anoSelecionado,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = e.mensagem);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Widget _campoAnoLetivo() {
    if (_carregandoAnos) {
      return const LinearProgressIndicator();
    }
    if (_anos.isEmpty) {
      return const Text(
        'A escola ainda não tem ano letivo. Cadastre um em Anos Letivos.',
        style: TextStyle(color: Colors.orange, fontSize: 13),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _anoSelecionado,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Ano letivo',
      ),
      items: _anos
          .map(
            (ano) => DropdownMenuItem(
              value: ano.ano,
              child: Text('${ano.ano} • ${ano.rotuloStatus}'),
            ),
          )
          .toList(),
      onChanged: (valor) => setState(() => _anoSelecionado = valor),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_editando ? 'Editar Turma' : 'Adicionar Turma'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    controller: _nomeController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Nome da turma',
                        hintText: 'Exemplo: 3 ano A')),
                const SizedBox(height: 16),
                TextField(
                    controller: _descricaoController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _salvar(),
                    decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)')),
                const SizedBox(height: 16),
                _campoAnoLetivo(),
                if (_mensagemErro != null) ...[
                  const SizedBox(height: 16),
                  Text(_mensagemErro!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  TextButton(
                      onPressed: _carregarAnos,
                      child: const Text('Tentar novamente')),
                ],
              ],
            ))),
        actions: [
          TextButton(
              onPressed: _carregando ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _carregando || _carregandoAnos ? null : _salvar,
              child: Text(_carregando
                  ? 'Salvando…'
                  : _editando
                      ? 'Salvar'
                      : 'Adicionar')),
        ],
      );
}
