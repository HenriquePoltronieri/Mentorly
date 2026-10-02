import 'package:flutter/material.dart';
import '../services/apiService.dart';
import 'adicionarAlunosModal.dart' show PapelAluno;

// Modal de editar um aluno ja cadastrado (Marco 4).
//
// Os dois papeis usam este mesmo widget, igual ao AdicionarAlunosModal:
//   Coordenacao -> PUT /api/coordenacao/alunos/{alunoId}
//   Professor   -> PUT /api/professor/alunos/{alunoId}
// Quem valida se o usuario pode editar este aluno e o backend (escola do
// aluno, e vinculo com a turma quando for Professor); aqui so escolhemos
// o caminho certo pelo papel.
//
// Retorna true via Navigator.pop quando a edicao foi salva, pra tela recarregar.
class EditarAlunoModal extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final PapelAluno papel;

  const EditarAlunoModal({
    super.key,
    required this.aluno,
    this.papel = PapelAluno.coordenacao,
  });

  @override
  State<EditarAlunoModal> createState() => _EditarAlunoModalState();
}

class _EditarAlunoModalState extends State<EditarAlunoModal> {
  final ApiService _api = ApiService();

  late final TextEditingController _nomeController;
  late final TextEditingController _matriculaController;
  late final TextEditingController _emailController;

  bool _salvando = false;
  String? _mensagemErro;

  String get _endpoint => widget.papel == PapelAluno.coordenacao
      ? '/coordenacao/alunos/${widget.aluno['id']}'
      : '/professor/alunos/${widget.aluno['id']}';

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.aluno['nome'] ?? '');
    _matriculaController =
        TextEditingController(text: widget.aluno['matricula'] ?? '');
    _emailController = TextEditingController(text: widget.aluno['email'] ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _mensagemErro = null;
    });

    try {
      await _api.put(_endpoint, {
        'nome': _nomeController.text.trim(),
        'matricula': _matriculaController.text.trim(),
        'email': _emailController.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _mensagemErro = e.mensagem);
    } catch (_) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar aluno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                helperText: 'Informe nome e sobrenome',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matriculaController,
              decoration: const InputDecoration(labelText: 'Matrícula (opcional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email (opcional)'),
            ),
            if (_mensagemErro != null) ...[
              const SizedBox(height: 12),
              Text(
                _mensagemErro!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
