import 'dart:ui';
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
      final permitidos = todos
          .where((a) => !a.estaEncerrado || a.ano == anoDaTurma)
          .toList();

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
        setState(() => _mensagemErro = 'Não foi possível carregar os anos letivos');
      }
    } finally {
      if (mounted) setState(() => _carregandoAnos = false);
    }
  }

  Future<void> _salvar() async {
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
      isDense: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Stack(
            children: [
              // detalhes decorativos nos cantos, igual o mockup
              Positioned(
                top: -20,
                right: -20,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Color(0xFFA7F3D0),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFBFDBFE),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _editando ? 'Editar Turma' : 'Adicionar Turma',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 24),
                  const Text('Nome da turma:'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      hintText: 'Exemplo "3 ano A"',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Descrição:'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descricaoController,
                    decoration: const InputDecoration(
                      hintText: 'Exemplo "Matemática - turno da manhã"',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ano letivo:'),
                  const SizedBox(height: 6),
                  _campoAnoLetivo(),
                  if (_mensagemErro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _mensagemErro!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}
