import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../controllers/atividadesController.dart';
import '../../models/atividadeModel.dart';
import '../../widgets/professorTopBar.dart';
import 'adicionarAtividadeModal.dart';

// tela que lista as atividades de uma turma especifica, com botao
// pra criar uma nova atividade (abre AdicionarAtividadeModal)
// recebe a turma via Navigator.pushNamed(context, AppRoutes.turmaAtividades, arguments: turma)
class TurmaAtividadesScreen extends StatefulWidget {
  const TurmaAtividadesScreen({super.key});

  @override
  State<TurmaAtividadesScreen> createState() => _TurmaAtividadesScreenState();
}

class _TurmaAtividadesScreenState extends State<TurmaAtividadesScreen> {
  final _controller = AtividadesController();

  bool _carregando = true;
  String? _mensagemErro;
  TurmaModel? _turma;
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _turma = ModalRoute.of(context)!.settings.arguments as TurmaModel?;
      _jaBuscou = true;
      _buscarAtividades();
    }
  }

  Future<void> _buscarAtividades() async {
    if (_turma == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Turma não informada';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _controller.carregarAtividades(_turma!.id);
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirAdicionarAtividade() async {
    if (_turma == null) return;

    final adicionou = await showDialog<bool>(
      context: context,
      builder: (_) => AdicionarAtividadeModal(turmas: [_turma!]),
    );

    if (adicionou == true) _buscarAtividades();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'atividades'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirAdicionarAtividade,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar atividade'),
      ),
      body: Column(
        children: [
          if (_turma != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    _turma!.nome,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _buscarAtividades,
              child: _construirCorpo(),
            ),
          ),
        ],
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
            child: Text(_mensagemErro!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    final atividades = _controller.atividades;

    if (atividades.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhuma atividade criada ainda')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: atividades.length,
      itemBuilder: (context, index) {
        final atividade = atividades[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                atividade.tipo == 'Prova' ? Icons.edit_note : Icons.assignment,
              ),
            ),
            title: Text(atividade.nome),
            subtitle: Text('${atividade.tipo} • Etapa ${atividade.etapa} • vale ${atividade.valor} pts'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.atividadeNotas,
                arguments: {'atividade': atividade, 'turma': _turma},
              );
            },
          ),
        );
      },
    );
  }
}