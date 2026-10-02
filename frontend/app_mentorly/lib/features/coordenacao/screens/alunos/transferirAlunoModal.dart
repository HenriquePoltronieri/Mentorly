import 'package:flutter/material.dart';
import '../../models/turmaModel.dart';
import '../../services/alunosService.dart';
import '../../services/turmasService.dart';
import '../../../../core/services/apiService.dart';

class TransferirAlunoModal extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final int turmaAtualId;
  final String turmaAtual;
  final int? anoAtual;

  const TransferirAlunoModal({
    super.key,
    required this.aluno,
    required this.turmaAtualId,
    required this.turmaAtual,
    required this.anoAtual,
  });

  @override
  State<TransferirAlunoModal> createState() => _TransferirAlunoModalState();
}

class _TransferirAlunoModalState extends State<TransferirAlunoModal> {
  final _alunos = AlunosService();
  final _turmas = TurmasService();
  final _motivo = TextEditingController();
  List<TurmaModel> _destinos = [];
  TurmaModel? _destino;
  String? _erro;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _buscarDestinos();
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _buscarDestinos() async {
    try {
      final turmas = await _turmas.listarTurmas();
      if (mounted) {
        setState(() => _destinos = turmas
            .where((turma) => turma.id != widget.turmaAtualId.toString())
            .toList());
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _erro = e.mensagem);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível buscar as turmas');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _transferir() async {
    if (_destino == null) {
      setState(() => _erro = 'Selecione a turma de destino');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await _alunos.transferirAluno(
        alunoId: widget.aluno['id'] as int,
        turmaDestinoId: int.parse(_destino!.id),
        motivo: _motivo.text,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _erro = e.mensagem);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível concluir a transferência');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transferir aluno'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aluno: ${widget.aluno['nome'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Turma atual: ${widget.turmaAtual}'),
              Text('Ano atual: ${widget.anoAtual ?? '-'}'),
              const SizedBox(height: 16),
              if (_carregando)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<TurmaModel>(
                  initialValue: _destino,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Turma de destino'),
                  items: _destinos
                      .map((turma) => DropdownMenuItem(
                            value: turma,
                            child: Text('${turma.nome} — ${turma.rotuloAno}'),
                          ))
                      .toList(),
                  onChanged: _salvando
                      ? null
                      : (turma) => setState(() => _destino = turma),
                ),
              if (_destino != null) ...[
                const SizedBox(height: 8),
                Text('Ano da turma destino: ${_destino!.anoLetivo ?? '-'}'),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _motivo,
                enabled: !_salvando,
                maxLength: 255,
                decoration:
                    const InputDecoration(labelText: 'Motivo (opcional)'),
              ),
              const Text(
                'O aluno será transferido para a nova turma.\n'
                'O histórico acadêmico anterior será preservado.',
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _carregando || _salvando ? null : _transferir,
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar transferência'),
        ),
      ],
    );
  }
}
