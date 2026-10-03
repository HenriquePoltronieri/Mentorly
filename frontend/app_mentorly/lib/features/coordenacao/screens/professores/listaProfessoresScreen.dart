import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../models/professorModel.dart';
import '../../services/professoresService.dart';

// tela que lista os professores cadastrados pela coordenacao
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> GET {baseUrl}/api/coordenacao/professores
// resposta esperada (200) -> uma lista de objetos assim:
// [ { "id": 1, "nome": "...", "email": "...", "disciplina": "..." }, ... ]
class ListaProfessoresScreen extends StatefulWidget {
  const ListaProfessoresScreen({super.key});

  @override
  State<ListaProfessoresScreen> createState() => _ListaProfessoresScreenState();
}

class _ListaProfessoresScreenState extends State<ListaProfessoresScreen> {
  final ProfessoresService _professoresService = ProfessoresService();

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _professores = [];

  @override
  void initState() {
    super.initState();
    _buscarProfessores();
  }

  Future<void> _buscarProfessores() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final professores = await _professoresService.listarProfessores();
      setState(() {
        _professores = professores;
      });
    } catch (e) {
      setState(() {
        _mensagemErro = 'Não foi possível conectar ao servidor';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _abrirCadastro() async {
    final resultado = await Navigator.pushNamed(context, AppRoutes.cadastroProfessor);
    // se voltou true, quer dizer que cadastrou um professor novo, entao recarrega a lista
    if (resultado == true) {
      _buscarProfessores();
    }
  }

  Future<void> _editarProfessor(Map<String, dynamic> professor) async {
    final nome = TextEditingController(text: professor['nome']?.toString() ?? '');
    final email = TextEditingController(text: professor['email']?.toString() ?? '');
    final disciplina = TextEditingController(text: professor['disciplina']?.toString() ?? '');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar professor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'E-mail')),
          TextField(controller: disciplina, decoration: const InputDecoration(labelText: 'Disciplina')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _professoresService.editarProfessor(
        professorId: professor['id'] as int,
        nome: nome.text.trim(), email: email.text.trim(), disciplina: disciplina.text.trim(),
      );
      await _buscarProfessores();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível editar: $e')));
    } finally {
      nome.dispose(); email.dispose(); disciplina.dispose();
    }
  }

  Future<void> _confirmarStatus(Map<String, dynamic> professor) async {
    final modelo = ProfessorModel.fromJson(professor);
    final reativar = !modelo.habilitado;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reativar ? 'Reativar professor?' : 'Desativar professor?'),
        content: Text(reativar
            ? 'Ele voltará a acessar o sistema com os vínculos já existentes.'
            : 'Ele não poderá acessar o sistema. Atividades, notas e vínculos existentes serão preservados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(reativar ? 'Reativar' : 'Desativar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      if (reativar) {
        await _professoresService.reativarProfessor(modelo.id);
      } else {
        await _professoresService.desativarProfessor(modelo.id);
      }
      await _buscarProfessores();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível alterar o status: $e')));
    }
  }

  Future<void> _reenviarConvite(Map<String, dynamic> professor) async {
    try {
      final resposta = await _professoresService.reenviarConvite(professor['id'] as int);
      if (!mounted) return;
      final token = resposta['conviteToken'] as String?;
      final mensagem = token == null
          ? 'Convite reenviado por e-mail.'
          : 'Convite renovado. Ambiente de desenvolvimento: token $token';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
      await _buscarProfessores();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível reenviar: $e')));
    }
  }

  Future<void> _verTurmas(Map<String, dynamic> professor) async {
    final turmas = List<dynamic>.from(professor['turmas'] as List? ?? const []);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Turmas de ${professor['nome']}'),
        content: Text(turmas.isEmpty ? 'Nenhuma turma vinculada.' : turmas.map((t) => t['nome']).join('\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Professores')),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirCadastro,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarProfessores,
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
        final professor = Map<String, dynamic>.from(_professores[index] as Map);
        final modelo = ProfessorModel.fromJson(professor);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(modelo.nome),
          subtitle: Text('${modelo.email}\n${modelo.disciplina ?? 'Sem disciplina'} · ${modelo.totalTurmas} turma(s)'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (acao) {
              if (acao == 'editar') _editarProfessor(professor);
              if (acao == 'turmas') Navigator.pushNamed(context, AppRoutes.listaTurmasProfessor);
              if (acao == 'ver_turmas') _verTurmas(professor);
              if (acao == 'convite') _reenviarConvite(professor);
              if (acao == 'status') _confirmarStatus(professor);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              const PopupMenuItem(value: 'ver_turmas', child: Text('Ver turmas')),
              const PopupMenuItem(value: 'turmas', child: Text('Gerenciar turmas')),
              if (modelo.status == ProfessorModel.convitePendente)
                const PopupMenuItem(value: 'convite', child: Text('Reenviar convite')),
              PopupMenuItem(value: 'status', child: Text(modelo.habilitado ? 'Desativar' : 'Reativar')),
            ],
          ),
          onTap: () => _verTurmas(professor),
        );
      },
    );
  }
}
