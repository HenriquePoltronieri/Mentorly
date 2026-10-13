import '../../../../core/widgets/barra_mentorly.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../../core/widgets/confirmarExclusaoDialog.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/apiService.dart';
import '../../models/turmaModel.dart';
import '../../services/turmasService.dart';
import 'adicionarTurmaModal.dart';

// Tela da coordenacao com o CRUD de turmas.
// Fluxo: tela -> TurmasService -> ApiService -> /api/classes
//
// Toque na turma -> abre os alunos dela (AppRoutes.listaAlunosTurma)
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
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final turmas = await _turmasService.listarTurmas();
      if (!mounted) return;
      setState(() => _turmas = turmas);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Erro ao buscar turmas: ${e.mensagem}');
    } catch (e) {
      if (!mounted) return;
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
    final confirmou = await confirmarExclusao(
      context,
      titulo: 'Excluir turma?',
      nome: turma.nome,
      aviso: AvisosDeExclusao.turma,
    );

    if (!confirmou) return;

    try {
      await _turmasService.excluirTurma(turma.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turma "${turma.nome}" excluída')),
      );
      _buscarTurmas();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: ${e.mensagem}')));
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
      appBar: const BarraMentorly(
          professor: false, aba: 'turmas', titulo: 'Turmas'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCriarTurma,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar turma'),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ApiService().invalidarCache();
          return _buscarTurmas();
        },
        child: ConteudoPagina(child: _construirCorpo()),
      ),
    );
  }

  Widget _construirCorpo() {
    if (_carregando) {
      return const CarregamentoPagina();
    }

    if (_mensagemErro != null) {
      return EstadoPagina(
          titulo: 'Falha ao carregar',
          mensagem: _mensagemErro!,
          acao: 'Tentar novamente',
          onPressed: _buscarTurmas);
    }

    if (_turmas.isEmpty) {
      return EstadoPagina(
          titulo: 'Nenhuma turma cadastrada ainda',
          mensagem: 'Comece pelo cadastro.',
          acao: 'Adicionar turma',
          onPressed: _abrirCriarTurma);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      separatorBuilder: (_, indice) => const Divider(height: 1),
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final turma = _turmas[index];
        return ListTile(
          leading: const Icon(Icons.class_outlined),
          title: Text(turma.nome),
          subtitle: Text(
            [
              turma.descricao.isEmpty ? 'Sem descrição' : turma.descricao,
              turma.rotuloAno,
            ].where((texto) => texto.isNotEmpty).join(' • '),
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
          // A Coordenacao gerencia ALUNOS da turma. Criar atividade e
          // lancar nota sao acoes do Professor, entao esta tela nao leva
          // mais para turmaAtividades (que tem o botao "Adicionar
          // atividade"). O backend tambem recusa: POST /api/activities
          // exige token de professor.
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.listaAlunosTurma,
              arguments: turma,
            );
          },
        );
      },
    );
  }
}
