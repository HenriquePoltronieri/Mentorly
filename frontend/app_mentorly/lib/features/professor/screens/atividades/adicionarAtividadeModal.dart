import 'package:flutter/material.dart';
import '../../../../core/widgets/successModal.dart';
import '../../controllers/atividadesController.dart';
import '../../../coordenacao/models/turmaModel.dart';

// Modal "Adicionar Atividade:" - tipo, etapa, nome, turma e valor
class AdicionarAtividadeModal extends StatefulWidget {
  final List<TurmaModel> turmas;

  const AdicionarAtividadeModal({super.key, required this.turmas});

  @override
  State<AdicionarAtividadeModal> createState() =>
      _AdicionarAtividadeModalState();
}

class _AdicionarAtividadeModalState extends State<AdicionarAtividadeModal> {
  final _controller = AtividadesController();
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();

  String _tipoSelecionado = 'Prova';
  int _etapaSelecionada = 1;
  TurmaModel? _turmaSelecionada;

  Future<void> _adicionar() async {
    if (_turmaSelecionada == null) return;

    await _controller.adicionarAtividade(
      turmaId: _turmaSelecionada!.id,
      nome: _nomeController.text,
      tipo: _tipoSelecionado,
      etapa: _etapaSelecionada,
      valor: double.tryParse(_valorController.text) ?? 0,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
    await mostrarSucesso(
      context,
      'Atividade Adicionada com sucesso a "${_turmaSelecionada!.nome}"',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adicionar Atividade:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 12),
            Text('TIPO'),
            Wrap(
              spacing: 8,
              children: ['Prova', 'Trabalho'].map((tipo) {
                return ChoiceChip(
                  label: Text(tipo),
                  selected: _tipoSelecionado == tipo,
                  onSelected: (_) => setState(() => _tipoSelecionado = tipo),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            Text('De qual etapa?'),
            Wrap(
              spacing: 8,
              children: [1, 2, 3].map((etapa) {
                return ChoiceChip(
                  label: Text('$etapa'),
                  selected: _etapaSelecionada == etapa,
                  onSelected: (_) => setState(() => _etapaSelecionada = etapa),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _nomeController,
              decoration: InputDecoration(
                labelText: 'Nome da atividade',
                hintText: 'Prova 10 pontos 3 ano',
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<TurmaModel>(
              decoration: InputDecoration(labelText: 'Pra qual turma?'),
              items: widget.turmas
                  .map((turma) => DropdownMenuItem(
                        value: turma,
                        child: Text(turma.nome),
                      ))
                  .toList(),
              onChanged: (turma) => setState(() => _turmaSelecionada = turma),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _valorController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Qual valor da Atividade?',
                suffixText: 'pontos',
              ),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _adicionar,
                child: Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
