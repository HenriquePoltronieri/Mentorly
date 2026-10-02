import 'package:flutter/material.dart';
import '../../models/historicoTurmaAlunoModel.dart';
import '../../services/alunosService.dart';

class HistoricoAlunoModal extends StatefulWidget {
  final int alunoId;
  final String alunoNome;

  const HistoricoAlunoModal(
      {super.key, required this.alunoId, required this.alunoNome});

  @override
  State<HistoricoAlunoModal> createState() => _HistoricoAlunoModalState();
}

class _HistoricoAlunoModalState extends State<HistoricoAlunoModal> {
  final _service = AlunosService();
  List<HistoricoTurmaAlunoModel> _itens = [];
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final itens = await _service.historicoAluno(widget.alunoId);
      if (mounted) {
        setState(() => _itens = itens);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar o histórico');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Histórico de turmas — ${widget.alunoNome}'),
      content: SizedBox(
        width: 420,
        child: _erro != null
            ? Text(_erro!, style: const TextStyle(color: Colors.red))
            : _itens.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _itens.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final item = _itens[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${item.anoLetivo} — ${item.turma}'),
                        subtitle: Text(item.atual
                            ? 'desde ${item.dataInicio}'
                            : '${item.dataInicio} até ${item.dataFim}'),
                        trailing: item.atual
                            ? const Chip(label: Text('Atual'))
                            : null,
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'))
      ],
    );
  }
}
