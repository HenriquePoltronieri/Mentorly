import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../controllers/atividadesController.dart';
import '../../models/atividadeModel.dart';
import '../../widgets/professorTopBar.dart';
import '../../services/professorAlunosService.dart';
import 'lancarNotasModal.dart';

// tela onde o professor lanca as notas dos alunos numa atividade especifica
// recebe via Navigator.pushNamed(context, AppRoutes.atividadeNotas,
//   arguments: {'atividade': atividade, 'turma': turma})
//
// IMPORTANTE PRO BACKEND:
// usa GET {baseUrl}/api/professor/turmas/{turmaId}/alunos (mesmo endpoint
// da turmaAlunosScreen) pra saber quem sao os alunos dessa turma
class AtividadeNotasScreen extends StatefulWidget {
  const AtividadeNotasScreen({super.key});

  @override
  State<AtividadeNotasScreen> createState() => _AtividadeNotasScreenState();
}

class _AtividadeNotasScreenState extends State<AtividadeNotasScreen> {
  final ProfessorAlunosService _alunosService = ProfessorAlunosService();
  final AtividadesController _controller = AtividadesController();
  final Map<String, TextEditingController> _controladoresNota = {};

  bool _carregando = true;
  bool _salvando = false;
  String? _mensagemErro;
  AtividadeModel? _atividade;
  TurmaModel? _turma;
  List<dynamic> _alunos = [];
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _atividade = args?['atividade'] as AtividadeModel?;
      _turma = args?['turma'] as TurmaModel?;
      _jaBuscou = true;
      _buscarDados();
    }
  }

  Future<void> _buscarDados() async {
    if (_atividade == null || _turma == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Atividade ou turma não informada';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final alunos = await _alunosService.listarAlunos(_turma!.id as int);
      await _controller.carregarNotas(_atividade!.id);

      setState(() {
        _alunos = alunos;
      });
      _prepararControladores();
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

  void _prepararControladores() {
    for (final aluno in _alunos) {
      final alunoId = aluno['id'].toString();
      final nota = _controller.notas.where((n) => n.alunoId.toString() == alunoId);
      final valorExistente = nota.isNotEmpty ? nota.first.valorObtido : null;

      _controladoresNota[alunoId] = TextEditingController(
        text: valorExistente != null ? valorExistente.toString() : '',
      );
    }
  }

  Future<void> _salvarTodas() async {
    if (_atividade == null) return;

    setState(() => _salvando = true);

    try {
      for (final aluno in _alunos) {
        final alunoId = aluno['id'].toString();
        final texto = _controladoresNota[alunoId]?.text.trim() ?? '';
        if (texto.isEmpty) continue;

        final valor = double.tryParse(texto);
        if (valor == null) continue;

        await _controller.lancarNota(
          atividadeId: _atividade!.id,
          alunoId: alunoId,
          valorObtido: valor,
          valorTotal: _atividade!.valor,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notas salvas com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar notas')),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _abrirImportarPlanilha() async {
    if (_atividade == null) return;

    final lancou = await showDialog<bool>(
      context: context,
      builder: (_) => LancarNotasModal(atividadeId: _atividade!.id),
    );

    if (lancou == true) _buscarDados();
  }

  @override
  void dispose() {
    for (final controller in _controladoresNota.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'atividades'),
      body: Column(
        children: [
          if (_atividade != null)
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _atividade!.nome,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Vale ${_atividade!.valor} pontos',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _abrirImportarPlanilha,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Importar planilha'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _buscarDados,
              child: _construirCorpo(),
            ),
          ),
        ],
      ),
      floatingActionButton: _alunos.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _salvando ? null : _salvarTodas,
              icon: _salvando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Salvar notas'),
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
      padding: const EdgeInsets.all(16),
      itemCount: _alunos.length,
      itemBuilder: (context, index) {
        final aluno = _alunos[index];
        final alunoId = aluno['id'].toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(aluno['nome'] ?? ''),
            subtitle: Text('Matrícula: ${aluno['matricula'] ?? ''}'),
            trailing: SizedBox(
              width: 80,
              child: TextField(
                controller: _controladoresNota[alunoId],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0-${_atividade?.valor.toStringAsFixed(0) ?? '10'}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}