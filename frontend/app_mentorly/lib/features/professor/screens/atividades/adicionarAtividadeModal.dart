import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/successModal.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../models/atividadeModel.dart';
import '../../services/atividadesService.dart';

// Modal pra criar OU editar uma atividade.
// Fluxo: tela -> AtividadesService -> ApiService -> /api/activities
//
// A entidade Activity do backend tem title, description, class_id e due_date,
// entao o formulario pede nome, descricao, turma e data de entrega
// (antes pedia tipo/etapa/valor, que nao existem na API).
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

  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _dataController;

  TurmaModel? _turmaSelecionada;
  bool _carregando = false;
  String? _mensagemErro;

  bool get _editando => widget.atividade != null;

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

    if (widget.turmas.isNotEmpty) {
      _turmaSelecionada = widget.turmas.firstWhere(
        (t) => t.id == widget.atividade?.turmaId,
        orElse: () => widget.turmas.first,
      );
    }
  }

  Future<void> _salvar() async {
    if (_turmaSelecionada == null) {
      setState(() => _mensagemErro = 'Selecione uma turma');
      return;
    }
    if (_nomeController.text.trim().isEmpty) {
      setState(() => _mensagemErro = 'Digite o nome da atividade');
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      if (_editando) {
        await _atividadesService.atualizarAtividade(
          id: widget.atividade!.id,
          turmaId: _turmaSelecionada!.id,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          dataEntrega: _dataController.text.trim(),
        );
      } else {
        await _atividadesService.cadastrarAtividade(
          turmaId: _turmaSelecionada!.id,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          dataEntrega: _dataController.text.trim(),
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
        setState(() => _carregando = false);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _dataController.dispose();
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
                onChanged: (turma) =>
                    setState(() => _turmaSelecionada = turma),
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
                  onPressed: _carregando ? null : _salvar,
                  child: _carregando
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
}
