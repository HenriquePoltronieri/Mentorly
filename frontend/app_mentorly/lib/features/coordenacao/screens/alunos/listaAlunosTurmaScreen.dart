import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../models/turmaModel.dart';
import '../../../../core/widgets/adicionarAlunosModal.dart';
import '../../services/alunosService.dart';

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
    } else if (argumentos is Map) {
      _turmaId = argumentos['id'] is int
          ? argumentos['id'] as int
          : int.tryParse('${argumentos['id']}');
      _turmaNome = (argumentos['nome'] ?? argumentos['name'] ?? '').toString();
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
            child: Text(_mensagemErro!, style: const TextStyle(color: Colors.red)),
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
          const Center(child: Text('Nenhum aluno cadastrado nessa turma ainda')),
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
        );
      },
    );
  }
}