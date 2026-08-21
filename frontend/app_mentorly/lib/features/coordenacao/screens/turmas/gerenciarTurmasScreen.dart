import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/apiService.dart';
import '../../models/turmaModel.dart';
import '../../services/turmasService.dart';
import 'adicionarTurmaModal.dart';

// Tela da coordenacao com o CRUD de turmas.
// Fluxo: tela -> TurmasService -> ApiService -> /api/classes
//
// Toque na turma -> abre as atividades dela (AppRoutes.turmaAtividades)
// Lapis -> editar     Lixeira -> excluir (com confirmacao)
class GerenciarTurmasScreen extends StatefulWidget {
  const GerenciarTurmasScreen({super.key});

  @override
  State<GerenciarTurmasScreen> createState() => _GerenciarTurmasScreenState();
}

class _GerenciarTurmasScreenState extends State<GerenciarTurmasScreen> {
  final TurmasService _turmasService = TurmasService();

  bool _carregando = true;
  String? _mensagemErro;
  List<TurmaModel> _turmas = [];

  @override
  void initState() {
    super.initState();
    _buscarTurmas();
  }

  Future<void> _buscarTurmas() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final turmas = await _turmasService.listarTurmas();
      setState(() => _turmas = turmas);
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar turmas: ${e.mensagem}');
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirCriarTurma() async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => const AdicionarTurmaModal(),
    );
    if (salvou == true) _buscarTurmas();
  }

  Future<void> _abrirEditarTurma(TurmaModel turma) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => AdicionarTurmaModal(turma: turma),
    );
    if (salvou == true) _buscarTurmas();
  }

  Future<void> _excluirTurma(TurmaModel turma) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Excluir turma'),
        content: Text('Excluir a turma "${turma.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      await _turmasService.excluirTurma(turma.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turma "${turma.nome}" excluída')),
      );
      _buscarTurmas();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.mensagem}')));
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
      appBar: AppBar(title: const Text('Turmas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCriarTurma,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar turma'),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarTurmas,
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
            child: Text(_mensagemErro!,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    if (_turmas.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhuma turma cadastrada ainda')),
        ],
      );
    }

    return ListView.builder(
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final turma = _turmas[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.class_)),
          title: Text(turma.nome),
          subtitle: Text(
            turma.descricao.isEmpty ? 'Sem descrição' : turma.descricao,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _abrirEditarTurma(turma),
              ),
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _excluirTurma(turma),
              ),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.turmaAtividades,
              arguments: turma,
            );
          },
        );
      },
    );
  }
}
