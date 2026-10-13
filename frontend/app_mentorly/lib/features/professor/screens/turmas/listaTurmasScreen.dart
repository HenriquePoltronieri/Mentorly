import 'package:flutter/material.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../../core/services/apiService.dart';
import '../../../../app/routes.dart';
import '../../widgets/professorTopBar.dart';
import '../../services/professorTurmasService.dart';

// tela que lista as turmas vinculadas a esse professor (vinculo feito
// pela coordenacao na tela "Vincular Professores")
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> GET {baseUrl}/api/professor/turmas
// (o backend identifica qual professor pelo token de autenticacao)
// resposta esperada (200) ->
// [ { "id": 1, "nome": "9º Ano A", "disciplina": "...", "turno": "...", "totalAlunos": 8 }, ... ]
class ListaTurmasScreen extends StatefulWidget {
  const ListaTurmasScreen({super.key});

  @override
  State<ListaTurmasScreen> createState() => _ListaTurmasScreenState();
}

class _ListaTurmasScreenState extends State<ListaTurmasScreen> {
  final ProfessorTurmasService _turmasService = ProfessorTurmasService();

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _turmas = [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProfessorTopBar(abaAtiva: 'turmas'),
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
          Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(
            child: Text('Nenhuma turma vinculada a você ainda'),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Fale com a coordenação para ser vinculado a uma turma',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
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
          leading: const Icon(Icons.class_outlined),
          title: Text(turma['nome'] ?? ''),
          subtitle: Text(
            '${turma['disciplina'] ?? ''} • ${turma['turno'] ?? ''} • ${turma['totalAlunos'] ?? 0} aluno(s)'
            '${turma['anoLetivo'] != null ? ' • Ano letivo ${turma['anoLetivo']}' : ''}',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.turmaAlunos,
                arguments: turma);
          },
        );
      },
    );
  }
}
