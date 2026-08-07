import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../app/routes.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../widgets/professorTopBar.dart';

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
  // ATENCAO: 10.0.2.2 so funciona no emulador Android.
  // Testando no Chrome/Web, troca por 'http://localhost:5000'
  static const String baseUrl = 'http://localhost:5000';

  bool _carregando = true;
  String? _mensagemErro;
  List<TurmaModel> _turmas = [];

  @override
  void initState() {
    super.initState();
    _buscarTurmas();
  }

  Future<void> _buscarTurmas() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/professor/turmas'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final lista = jsonDecode(response.body) as List;
        setState(() {
          _turmas = lista.map((item) => TurmaModel.fromJson(item)).toList();
        });
      } else {
        setState(() => _mensagemErro = 'Erro ao buscar turmas');
      }
    } catch (e) {
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
        onRefresh: _buscarTurmas,
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final turma = _turmas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
            title: Text(turma.nome),
            subtitle: Text('${turma.disciplina} • ${turma.turno}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.turmaAtividades, arguments: turma);
            },
          ),
        );
      },
    );
  }
}