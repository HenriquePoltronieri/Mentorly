import '../../../../core/widgets/barra_mentorly.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/mensagensConvite.dart';
import '../../../../app/routes.dart';
import '../../models/professorModel.dart';
import '../../services/professoresService.dart';
import '../../../../core/widgets/convite_dialog.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';

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
  String _busca = '';
  List<dynamic> _professores = [];
  final Set<int> _enviando = {};

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
      if (!mounted) return;
      setState(() {
        _professores = professores;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensagemErro = e is ApiException
            ? e.mensagem
            : 'Não foi possível conectar ao servidor';
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
    final resultado =
        await Navigator.pushNamed(context, AppRoutes.cadastroProfessor);
    // se voltou true, quer dizer que cadastrou um professor novo, entao recarrega a lista
    if (resultado == true) {
      _buscarProfessores();
    }
  }

  Future<void> _editarProfessor(Map<String, dynamic> professor) async {
    final nome =
        TextEditingController(text: professor['nome']?.toString() ?? '');
    final email =
        TextEditingController(text: professor['email']?.toString() ?? '');
    final disciplina =
        TextEditingController(text: professor['disciplina']?.toString() ?? '');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar professor'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 16),
          TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail')),
          const SizedBox(height: 16),
          TextField(
              controller: disciplina,
              decoration: const InputDecoration(labelText: 'Disciplina')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (confirmar != true) {
      nome.dispose();
      email.dispose();
      disciplina.dispose();
      return;
    }
    try {
      final resposta = await _professoresService.editarProfessor(
        professorId: professor['id'] as int,
        nome: nome.text.trim(),
        email: email.text.trim(),
        disciplina: disciplina.text.trim(),
      );
      // Trocar o e-mail de quem ainda nao abriu o convite gera um convite novo.
      final aviso = MensagensConvite.edicao(resposta);
      if (resposta['conviteLink'] != null && mounted) {
        await mostrarConvite(context, resposta);
      } else if (aviso != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(aviso)));
      }
      await _buscarProfessores();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível editar: $e')));
      }
    } finally {
      nome.dispose();
      email.dispose();
      disciplina.dispose();
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(reativar ? 'Reativar' : 'Desativar')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível alterar o status: $e')));
      }
    }
  }

  Future<void> _reenviarConvite(Map<String, dynamic> professor,
      {bool soLink = false}) async {
    final id = professor['id'] as int;
    if (_enviando.contains(id)) return;
    if (soLink) {
      final confirmar = await showDialog<bool>(
          context: context,
          builder: (contexto) => AlertDialog(
                title: const Text('Gerar novo link do convite?'),
                content: const Text(
                    'O link anterior deixará de funcionar. Compartilhe o novo link com o professor.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(contexto, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(contexto, true),
                      child: const Text('Gerar link'))
                ],
              ));
      if (confirmar != true || !mounted) return;
    }
    setState(() => _enviando.add(id));
    try {
      final resposta = soLink
          ? await _professoresService.gerarLinkConvite(id)
          : await _professoresService.reenviarConvite(id);
      if (!mounted) return;
      await mostrarConvite(context, resposta);
      if (!mounted) return;
      await _buscarProfessores();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível reenviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando.remove(id));
    }
  }

  Future<void> _verTurmas(Map<String, dynamic> professor) async {
    final turmas = List<dynamic>.from(professor['turmas'] as List? ?? const []);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Turmas de ${professor['nome']}'),
        content: Text(turmas.isEmpty
            ? 'Nenhuma turma vinculada.'
            : turmas.map((t) => t['nome']).join('\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BarraMentorly(
          professor: false, aba: 'professores', titulo: 'Professores'),
      body: RefreshIndicator(
        onRefresh: _buscarProfessores,
        child: ConteudoPagina(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                        onPressed: _abrirCadastro,
                        icon: const Icon(Icons.add),
                        label: const Text('+ Novo professor')),
                    const SizedBox(height: 12),
                    TextField(
                        decoration: const InputDecoration(
                            labelText: 'Buscar por nome',
                            prefixIcon: Icon(Icons.search)),
                        onChanged: (v) =>
                            setState(() => _busca = v.trim().toLowerCase())),
                  ])),
          Expanded(child: _construirCorpo()),
        ])),
      ),
    );
  }

  Widget _construirCorpo() {
    if (_carregando) {
      return const CarregamentoPagina();
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
          Center(
              child: TextButton(
                  onPressed: _buscarProfessores,
                  child: const Text('Tentar novamente'))),
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
          Center(
              child: FilledButton(
                  onPressed: _abrirCadastro,
                  child: const Text('Cadastrar professor'))),
        ],
      );
    }

    final filtrados = _professores
        .where((p) => p['nome'].toString().toLowerCase().contains(_busca))
        .toList();
    if (filtrados.isEmpty) {
      return const Center(child: Text('Nenhum professor encontrado.'));
    }
    return ListView.builder(
      itemCount: filtrados.length,
      itemBuilder: (context, index) {
        final professor = Map<String, dynamic>.from(filtrados[index] as Map);
        final modelo = ProfessorModel.fromJson(professor);
        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(modelo.nome),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${modelo.email}\n${modelo.disciplina ?? 'Sem disciplina'} · ${modelo.totalTurmas} turma(s)'),
            const SizedBox(height: 8),
            Text(modelo.rotuloStatus,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (modelo.status == ProfessorModel.convitePendente)
              TextButton(
                  onPressed: _enviando.contains(modelo.id)
                      ? null
                      : () => _reenviarConvite(professor),
                  child: Text(_enviando.contains(modelo.id)
                      ? 'Enviando convite…'
                      : 'Reenviar convite')),
          ]),
          trailing: PopupMenuButton<String>(
            onSelected: (acao) {
              if (acao == 'editar') _editarProfessor(professor);
              if (acao == 'turmas') {
                Navigator.pushNamed(context, AppRoutes.listaTurmasProfessor);
              }
              if (acao == 'ver_turmas') _verTurmas(professor);
              if (acao == 'convite') _reenviarConvite(professor);
              if (acao == 'link') _reenviarConvite(professor, soLink: true);
              if (acao == 'status') _confirmarStatus(professor);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              const PopupMenuItem(
                  value: 'ver_turmas', child: Text('Ver turmas')),
              const PopupMenuItem(
                  value: 'turmas', child: Text('Gerenciar turmas')),
              if (modelo.status == ProfessorModel.convitePendente)
                const PopupMenuItem(
                    value: 'convite', child: Text('Reenviar convite')),
              if (modelo.status == ProfessorModel.convitePendente)
                const PopupMenuItem(
                    value: 'link', child: Text('Copiar link do convite')),
              PopupMenuItem(
                  value: 'status',
                  child: Text(modelo.habilitado ? 'Desativar' : 'Reativar')),
            ],
          ),
          onTap: () => _verTurmas(professor),
        );
      },
    );
  }
}
