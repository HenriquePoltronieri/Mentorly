import 'package:flutter/material.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../../core/services/apiService.dart';
import '../../../../app/routes.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../widgets/professorTopBar.dart';
import '../../services/professorTurmasService.dart';

// tela que lista as turmas do professor pra ele escolher em qual
// quer ver/criar atividades (mesmo conceito da lista de turmas,
// so que essa leva pra turmaAtividadesScreen em vez de turmaAlunosScreen)
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> GET {baseUrl}/api/professor/turmas
// (mesmo endpoint da listaTurmasScreen)
class ListaAtividadesScreen extends StatefulWidget {
  const ListaAtividadesScreen({super.key});

  @override
  State<ListaAtividadesScreen> createState() => _ListaAtividadesScreenState();
}

class _ListaAtividadesScreenState extends State<ListaAtividadesScreen> {
  final ProfessorTurmasService _turmasService = ProfessorTurmasService();

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
      final lista = await _turmasService.listarTurmas();
      if (!mounted) return;
      setState(() {
        _turmas = lista.map((item) => TurmaModel.fromJson(item)).toList();
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'atividades'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.buscarAtividades);
        },
        icon: const Icon(Icons.search),
        label: const Text('Buscar atividades'),
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
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhuma turma vinculada a você ainda')),
        ],
      );
    }

    return ListView.separated(
      separatorBuilder: (_, indice) => const Divider(height: 1),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final turma = _turmas[index];
        return ListTile(
          leading: const Icon(Icons.assignment_outlined),
          title: Text(turma.nome),
          subtitle: Text('${turma.disciplina} • ${turma.turno}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.turmaAtividades,
                arguments: turma);
          },
        );
      },
    );
  }
}
