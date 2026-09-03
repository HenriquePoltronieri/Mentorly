import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../../../app/routes.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../models/atividadeModel.dart';
import '../../services/atividadesService.dart';
import 'adicionarAtividadeModal.dart';

// Lista as atividades de uma turma especifica, com criar/editar/excluir.
// Fluxo: tela -> AtividadesService -> ApiService -> /api/activities?class_id=<id>
//
// Recebe a turma via Navigator.pushNamed(context, AppRoutes.turmaAtividades, arguments: turma)
class TurmaAtividadesScreen extends StatefulWidget {
  const TurmaAtividadesScreen({super.key});

  @override
  State<TurmaAtividadesScreen> createState() => _TurmaAtividadesScreenState();
}

class _TurmaAtividadesScreenState extends State<TurmaAtividadesScreen> {
  final AtividadesService _atividadesService = AtividadesService();

  bool _carregando = true;
  String? _mensagemErro;
  TurmaModel? _turma;
  bool _jaBuscou = false;
  List<AtividadeModel> _atividades = [];

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
      final atividades =
          await _atividadesService.listarAtividades(turmaId: _turma!.id);
      setState(() => _atividades = atividades);
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar atividades: ${e.mensagem}');
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

    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => AdicionarAtividadeModal(turmas: [_turma!]),
    );

    if (salvou == true) _buscarAtividades();
  }

  Future<void> _abrirLancarNotas(AtividadeModel atividade) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.atividadeNotas,
      arguments: {'atividade': atividade, 'turma': _turma},
    );
  }

  Future<void> _abrirEditarAtividade(AtividadeModel atividade) async {
    if (_turma == null) return;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AdicionarAtividadeModal(turmas: [_turma!], atividade: atividade),
    );

    if (salvou == true) _buscarAtividades();
  }

  Future<void> _excluirAtividade(AtividadeModel atividade) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Excluir atividade'),
        content: Text('Excluir a atividade "${atividade.nome}"?'),
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
      await _atividadesService.excluirAtividade(atividade.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Atividade "${atividade.nome}" excluída')),
      );
      _buscarAtividades();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: ${e.mensagem}')),
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
      appBar: AppBar(
        title: Text(_turma == null ? 'Atividades' : 'Atividades · ${_turma!.nome}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirAdicionarAtividade,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar atividade'),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarAtividades,
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
            child:
                Text(_mensagemErro!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    if (_atividades.isEmpty) {
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
      itemCount: _atividades.length,
      itemBuilder: (context, index) {
        final atividade = _atividades[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.assignment)),
            title: Text(atividade.nome),
            subtitle: Text(_montarSubtitulo(atividade)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _abrirEditarAtividade(atividade),
                ),
                IconButton(
                  tooltip: 'Lançar notas',
                  icon: const Icon(Icons.grading_outlined),
                  onPressed: () => _abrirLancarNotas(atividade),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _excluirAtividade(atividade),
                ),
              ],
            ),
            // Tocar na atividade leva ao lancamento de notas, que era a
            // tela orfa do app - nenhuma rota apontava para ela.
            onTap: () => _abrirLancarNotas(atividade),
          ),
        );
      },
    );
  }

  String _montarSubtitulo(AtividadeModel atividade) {
    final partes = <String>[];
    if (atividade.descricao.isNotEmpty) partes.add(atividade.descricao);
    if (atividade.dataEntrega.isNotEmpty) {
      final data = atividade.dataEntrega.contains('T')
          ? atividade.dataEntrega.split('T').first
          : atividade.dataEntrega;
      partes.add('Entrega: $data');
    }
    return partes.isEmpty ? 'Sem descrição' : partes.join(' • ');
  }
}
