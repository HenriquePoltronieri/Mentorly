import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../models/turmaModel.dart';
import '../../services/turmasService.dart';

// Modal da coordenacao pra criar OU editar uma turma.
// Fluxo: tela -> TurmasService -> ApiService -> /api/classes
//
// A entidade Class do backend tem so name e description, entao o formulario
// pede nome e descricao (antes pedia disciplina/turno, que nao existem na API).
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

  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;

  bool _carregando = false;
  String? _mensagemErro;

  bool get _editando => widget.turma != null;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.turma?.nome ?? '');
    _descricaoController =
        TextEditingController(text: widget.turma?.descricao ?? '');
  }

  Future<void> _salvar() async {
    if (_nomeController.text.trim().isEmpty) {
      setState(() => _mensagemErro = 'Digite o nome da turma');
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
        );
      } else {
        await _turmasService.cadastrarTurma(
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
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
