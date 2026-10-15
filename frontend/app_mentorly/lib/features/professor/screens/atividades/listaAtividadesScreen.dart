import 'package:flutter/material.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../../core/services/apiService.dart';
import '../../../../app/routes.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../widgets/professor_scaffold.dart';
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
  String _busca = '';

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
    return ProfessorScaffold(
      aba: 'atividades',
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
        child: ConteudoPagina(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Atividades por turma',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text(
                            'Crie, reaproveite atividades e lance as notas da turma.'),
                        const SizedBox(height: 20),
                        TextField(
                            decoration: const InputDecoration(
                                labelText: 'Buscar turma',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (v) => setState(() => _busca = v)),
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

    final filtradas = _turmas
        .where((t) => '${t.nome} ${t.disciplina}'
            .toLowerCase()
            .contains(_busca.toLowerCase()))
        .toList();
    if (filtradas.isEmpty) {
      return const EstadoPagina(
          titulo: 'Nenhuma turma encontrada',
          mensagem: 'Tente outro nome ou disciplina.');
    }
    return ListView.separated(
      separatorBuilder: (_, indice) => const Divider(height: 1),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: filtradas.length,
      itemBuilder: (context, index) {
        final turma = filtradas[index];
        return ListTile(
          leading: const Icon(Icons.assignment_outlined),
          title: Text(turma.nome),
          subtitle: Text([turma.disciplina, turma.turno]
              .where((v) => v.trim().isNotEmpty)
              .join(' · ')),
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
