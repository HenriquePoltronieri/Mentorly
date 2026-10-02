import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../models/turmaModel.dart';
import '../../../../core/widgets/adicionarAlunosModal.dart';
import '../../../../core/widgets/editarAlunoModal.dart';
import '../../services/alunosService.dart';
import 'historicoAlunoModal.dart';
import 'transferirAlunoModal.dart';

// Alunos de uma turma, na visao da Coordenacao.
// Chegou aqui pelo toque na turma em gerenciarTurmasScreen, que passa um
// TurmaModel em arguments.
//
// Esta e a acao que a Coordenacao tem sobre uma turma: adicionar e ver
// alunos. Criar atividade e lancar nota sao do Professor.
//
// Endpoint: GET {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos
class ListaAlunosTurmaScreen extends StatefulWidget {
  const ListaAlunosTurmaScreen({super.key});

  @override
  State<ListaAlunosTurmaScreen> createState() => _ListaAlunosTurmaScreenState();
}

class _ListaAlunosTurmaScreenState extends State<ListaAlunosTurmaScreen> {
  final AlunosService _alunosService = AlunosService();

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _alunos = [];
  int? _turmaId;
  String _turmaNome = '';
  int? _turmaAno;
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_jaBuscou) return;
    _jaBuscou = true;

    // gerenciarTurmasScreen manda um TurmaModel; outras telas mandam o Map
    // cru da API. Aceita os dois para nao depender de quem navegou até aqui.
    final argumentos = ModalRoute.of(context)!.settings.arguments;
    if (argumentos is TurmaModel) {
      _turmaId = int.tryParse(argumentos.id);
      _turmaNome = argumentos.nome;
      _turmaAno = argumentos.anoLetivo;
    } else if (argumentos is Map) {
      _turmaId = argumentos['id'] is int
          ? argumentos['id'] as int
          : int.tryParse('${argumentos['id']}');
      _turmaNome = (argumentos['nome'] ?? argumentos['name'] ?? '').toString();
      _turmaAno = argumentos['anoLetivo'] is int
          ? argumentos['anoLetivo'] as int
          : int.tryParse(
              '${argumentos['anoLetivo'] ?? argumentos['ano_letivo'] ?? ''}');
    }

    _buscarAlunos();
  }

  Future<void> _buscarAlunos() async {
    if (_turmaId == null) {
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
      final alunos = await _alunosService.listarAlunos(_turmaId!);
      setState(() => _alunos = alunos);
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar alunos: ${e.mensagem}');
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirAdicionarAlunos() async {
    if (_turmaId == null) return;

    final adicionou = await showDialog<bool>(
      context: context,
      builder: (_) => AdicionarAlunosModal(
        turmaId: _turmaId!,
        papel: PapelAluno.coordenacao,
      ),
    );

    if (adicionou == true) _buscarAlunos();
  }

  Future<void> _editarAluno(Map<String, dynamic> aluno) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) =>
          EditarAlunoModal(aluno: aluno, papel: PapelAluno.coordenacao),
    );
    if (salvou == true) _buscarAlunos();
  }

  Future<void> _excluirAluno(Map<String, dynamic> aluno) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Excluir aluno'),
        content: Text(
          'Tem certeza que deseja excluir "${aluno['nome']}"? '
          'Essa ação não pode ser desfeita.',
        ),
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
      await _alunosService.excluirAluno(aluno['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aluno "${aluno['nome']}" excluído')),
      );
      _buscarAlunos();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: ${e.mensagem}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor')),
      );
    }
  }

  Future<void> _transferirAluno(Map<String, dynamic> aluno) async {
    if (_turmaId == null) return;
    final transferiu = await showDialog<bool>(
      context: context,
      builder: (_) => TransferirAlunoModal(
        aluno: aluno,
        turmaAtualId: _turmaId!,
        turmaAtual: _turmaNome,
        anoAtual: _turmaAno,
      ),
    );
    if (transferiu == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aluno transferido com histórico preservado')),
      );
      _buscarAlunos();
    }
  }

  Future<void> _verHistorico(Map<String, dynamic> aluno) async {
    await showDialog<void>(
      context: context,
      builder: (_) => HistoricoAlunoModal(
        alunoId: aluno['id'] as int,
        alunoNome: (aluno['nome'] ?? '').toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_turmaNome.isEmpty ? 'Alunos' : 'Alunos - $_turmaNome'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirAdicionarAlunos,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Adicionar alunos'),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarAlunos,
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

    if (_alunos.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(
              child: Text('Nenhum aluno cadastrado nessa turma ainda')),
        ],
      );
    }

    return ListView.builder(
      itemCount: _alunos.length,
      itemBuilder: (context, index) {
        final aluno = _alunos[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(aluno['nome'] ?? ''),
          subtitle: Text(
            (aluno['matricula'] ?? '').toString().isEmpty
                ? 'Sem matrícula'
                : 'Matrícula: ${aluno['matricula']}',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (acao) {
              if (acao == 'editar') _editarAluno(aluno);
              if (acao == 'excluir') _excluirAluno(aluno);
              if (acao == 'transferir') _transferirAluno(aluno);
              if (acao == 'historico') _verHistorico(aluno);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(
                  value: 'transferir', child: Text('Transferir aluno')),
              PopupMenuItem(
                  value: 'historico', child: Text('Histórico de turmas')),
              PopupMenuItem(value: 'excluir', child: Text('Excluir')),
            ],
          ),
        );
      },
    );
  }
}
