import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../services/professorTurmasService.dart';

// tela que lista os professores; ao clicar num professor, abre um
// dialogo pra escolher (multi-selecao) quais turmas ficam vinculadas a ele
//
// IMPORTANTE PRO BACKEND:
// endpoint 1 -> GET {baseUrl}/api/coordenacao/professores
// resposta esperada (200) -> [ { "id": 1, "nome": "...", "disciplina": "...", "turmas": [...] }, ... ]
//
// endpoint 2 -> GET {baseUrl}/api/classes
// resposta esperada (200) -> lista assim:
// [ { "id": 1, "name": "9º Ano A", "description": "..." }, ... ]
//
// endpoint 3 -> POST {baseUrl}/api/coordenacao/professores/{professorId}/turmas
// body enviado -> { "turma_ids": [1, 2, 3] }
// (manda a lista COMPLETA de turmas que devem ficar vinculadas a esse professor,
// substituindo o vinculo anterior - nao e um "adicionar", e um "definir")
// resposta esperada (200) -> { "professor_id": 1, "turma_ids": [1, 2, 3] }
class ListaTurmasProfessorScreen extends StatefulWidget {
  const ListaTurmasProfessorScreen({super.key});

  @override
  State<ListaTurmasProfessorScreen> createState() => _ListaTurmasProfessorScreenState();
}

class _ListaTurmasProfessorScreenState extends State<ListaTurmasProfessorScreen> {
  final ProfessorTurmasService _professorTurmasService = ProfessorTurmasService();

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _professores = [];
  List<dynamic> _turmas = [];

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final professores = await _professorTurmasService.listarProfessores();
      final turmas = await _professorTurmasService.listarTurmas();

      setState(() {
        _professores = professores;
        _turmas = turmas;
      });
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar dados: ${e.mensagem}');
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  // quantas turmas esse professor ja tem vinculadas
  List<dynamic> _turmasDoProfessor(int professorId) {
    final prof = _professores.firstWhere(
      (p) => p['id'] == professorId,
      orElse: () => null,
    );
    if (prof == null || prof['turmas'] == null) return [];
    return List<dynamic>.from(prof['turmas']);
  }

  Future<void> _abrirSelecaoTurmas(dynamic professor) async {
    if (_turmas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma turma cadastrada ainda')),
      );
      return;
    }

    // ids das turmas que ja pertencem a esse professor, pra vir pre-marcado
    final selecionadas = _turmasDoProfessor(professor['id'])
        .map<int>((t) => t['id'] as int)
        .toSet();

    final resultado = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Turmas de ${professor['nome']}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _turmas.map((turma) {
                    final turmaId = turma['id'] as int;
                    final vinculadaComOutro = _isTurmaVinculadaComOutro(turmaId, professor['id']);

                    return CheckboxListTile(
                      title: Text(turma['nome'] ?? ''),
                      subtitle: vinculadaComOutro
                          ? const Text(
                              'Já vinculada a outro professor',
                              style: TextStyle(color: Colors.orange, fontSize: 12),
                            )
                          : null,
                      value: selecionadas.contains(turmaId),
                      onChanged: (marcado) {
                        setDialogState(() {
                          if (marcado == true) {
                            selecionadas.add(turmaId);
                          } else {
                            selecionadas.remove(turmaId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, selecionadas),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == null) return; // cancelou
    await _salvarVinculo(professor['id'], resultado.toList());
  }

  bool _isTurmaVinculadaComOutro(int turmaId, int professorIdAtual) {
    for (final prof in _professores) {
      if (prof['id'] == professorIdAtual) continue;
      final turmas = prof['turmas'] as List<dynamic>? ?? [];
      if (turmas.any((t) => t['id'] == turmaId)) return true;
    }
    return false;
  }

  Future<void> _salvarVinculo(int professorId, List<int> turmaIds) async {
    try {
      await _professorTurmasService.vincularTurmas(
        professorId: professorId,
        turmaIds: turmaIds,
      );
      _buscarDados(); // recarrega pra atualizar os vinculos na tela
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar vínculo: ${e.mensagem}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turmas por Professor')),
      body: RefreshIndicator(
        onRefresh: _buscarDados,
        child: _construirCorpo(),
      ),
    );
  }

  Widget _construirCorpo() {
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
            child: Text(
              _mensagemErro!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    }

    if (_professores.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhum professor cadastrado ainda')),
        ],
      );
    }

    return ListView.builder(
      itemCount: _professores.length,
      itemBuilder: (context, index) {
        final professor = _professores[index];
        final turmasDoProfessor = _turmasDoProfessor(professor['id']);

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(professor['nome'] ?? ''),
          subtitle: Text(
            turmasDoProfessor.isEmpty
                ? 'Nenhuma turma vinculada'
                : '${turmasDoProfessor.length} turma(s): ${turmasDoProfessor.map((t) => t['nome']).join(', ')}',
          ),
          trailing: TextButton(
            onPressed: () => _abrirSelecaoTurmas(professor),
            child: const Text('Gerenciar'),
          ),
        );
      },
    );
  }
}