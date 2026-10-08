import 'package:flutter/material.dart';
import '../../../../core/services/apiService.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../controllers/atividadesController.dart';
import '../../models/atividadeModel.dart';
import '../../models/notaModel.dart';
import '../../widgets/professorTopBar.dart';
import '../../services/professorAlunosService.dart';
import 'corrigirRespostaIaDialog.dart';
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

  // Nota (com id) de cada aluno, pra saber qual excluir - ver
  // _prepararControladores. Enquanto um alunoId estiver neste set, o
  // botao de excluir dele fica desabilitado (evita duplo toque).
  final Map<String, NotaModel> _notaPorAluno = {};
  final Set<String> _excluindoNotaDe = {};

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
      final alunos = await _alunosService.listarAlunos(int.parse(_turma!.id));
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
    _notaPorAluno.clear();
    for (final aluno in _alunos) {
      final alunoId = aluno['id'].toString();
      final notasDoAluno =
          _controller.notas.where((n) => n.alunoId.toString() == alunoId);
      final nota = notasDoAluno.isNotEmpty ? notasDoAluno.first : null;

      if (nota != null) _notaPorAluno[alunoId] = nota;

      _controladoresNota[alunoId] = TextEditingController(
        text: nota?.valor != null ? nota!.valor.toString() : '',
      );
    }
  }

  // Exclusao de uma nota ja lancada (Marco 5). So aparece na tela quando
  // o aluno ja tem nota (nota.id != null); confirma antes de excluir,
  // igual ao padrao ja usado para excluir aluno.
  Future<void> _excluirNota(Map<String, dynamic> aluno) async {
    final alunoId = aluno['id'].toString();
    final nota = _notaPorAluno[alunoId];
    if (nota?.id == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Excluir nota'),
        content: Text(
          'Tem certeza que deseja excluir a nota de "${aluno['nome']}" '
          'nesta atividade? Essa ação não pode ser desfeita.',
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

    setState(() => _excluindoNotaDe.add(alunoId));
    try {
      await _controller.excluirNota(nota!.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nota de "${aluno['nome']}" excluída')),
      );
      await _buscarDados();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensagem)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor')),
      );
    } finally {
      if (mounted) setState(() => _excluindoNotaDe.remove(alunoId));
    }
  }

  // Marco 9C: a IA so SUGERE. O dialogo devolve o numero e este metodo apenas
  // o coloca no campo de nota do aluno. Nada e salvo aqui: o Professor ainda
  // pode mudar o valor e so grava ao clicar em "Salvar notas" (mesmo fluxo de
  // sempre, POST /api/atividades/<id>/notas).
  Future<void> _corrigirComIa(Map<String, dynamic> aluno) async {
    final atividade = _atividade;
    if (atividade == null || atividade.notaMaxima == null) return;

    final nota = await showDialog<double>(
      context: context,
      builder: (_) => CorrigirRespostaIaDialog(
        atividadeId: atividade.id,
        valorMaximoAtividade: atividade.notaMaxima!,
        alunoNome: aluno['nome']?.toString() ?? '',
      ),
    );
    if (nota == null || !mounted) return;

    _controladoresNota[aluno['id'].toString()]?.text = _formatarValor(nota);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nota sugerida preenchida para "${aluno['nome']}". '
          'Ainda não foi salva: revise e clique em "Salvar notas".',
        ),
      ),
    );
  }

  Future<void> _salvarTodas() async {
    if (_atividade == null) return;

    setState(() => _salvando = true);

    try {
      // Monta a turma inteira e manda em UMA requisicao. Campo em branco
      // significa "ainda nao lancada" e simplesmente nao vai.
      final lancamentos = <Map<String, dynamic>>[];
      for (final aluno in _alunos) {
        final alunoId = aluno['id'].toString();
        final texto = _controladoresNota[alunoId]?.text.trim() ?? '';
        if (texto.isEmpty) continue;

        final valor = double.tryParse(texto.replaceAll(',', '.'));
        if (valor == null) continue;

        lancamentos.add({'aluno_id': aluno['id'], 'valor': valor});
      }

      final salvas = await _controller.salvarNotas(
        atividadeId: _atividade!.id,
        lancamentos: lancamentos,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$salvas nota(s) salva(s) com sucesso')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensagem)),
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
                          _descricaoDaAtividade(),
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
        final temNotaLancada = _notaPorAluno[alunoId] != null;
        final excluindo = _excluindoNotaDe.contains(alunoId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(aluno['nome'] ?? ''),
            subtitle: Text('Matrícula: ${aluno['matricula'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Corrigir resposta com IA',
                  icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                  onPressed: excluindo || _atividade?.notaMaxima == null
                      ? null
                      : () => _corrigirComIa(aluno),
                ),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _controladoresNota[alunoId],
                    enabled: !excluindo,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: _atividade?.notaMaxima == null
                          ? 'nota'
                          : '0-${_formatarValor(_atividade!.notaMaxima!)}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                // So aparece quando o aluno ja tem uma nota lancada -
                // campo em branco continua sendo so "ainda nao lancada".
                if (temNotaLancada) ...[
                  const SizedBox(width: 4),
                  excluindo
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Excluir nota',
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          onPressed: () => _excluirNota(aluno),
                        ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // "1º Bimestre • Prova • Vale 20 pontos". Atividade legada (sem esses
  // campos) diz isso em vez de "Vale 0 pontos" - o backend recusa lancar
  // nota nela enquanto o professor nao definir quanto ela vale.
  String _descricaoDaAtividade() {
    final atividade = _atividade;
    if (atividade == null) return '';

    if (atividade.notaMaxima == null) {
      return 'Sem valor definido — edite a atividade antes de lançar notas';
    }

    final partes = <String>[];
    if (atividade.etapaNome.isNotEmpty) partes.add(atividade.etapaNome);
    if (atividade.criterioNome.isNotEmpty) partes.add(atividade.criterioNome);
    partes.add('Vale ${_formatarValor(atividade.notaMaxima!)} pontos');
    return partes.join(' • ');
  }

  // 20.0 vira "20"; 13.5 continua "13.5".
  static String _formatarValor(double valor) => valor == valor.roundToDouble()
      ? valor.toInt().toString()
      : valor.toString();
}
