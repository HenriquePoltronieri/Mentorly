import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../app/routes.dart';

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
  // troca aqui pela url real do backend quando tiver
  static const String baseUrl = 'http://10.0.2.2:5000';

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
      final response = await http.get(
        Uri.parse('$baseUrl/api/coordenacao/professores'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _professores = jsonDecode(response.body);
        });
      } else {
        setState(() {
          _mensagemErro = 'Erro ao buscar professores';
        });
      }
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
        final professor = _professores[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(professor['nome'] ?? ''),
          subtitle: Text(professor['disciplina'] ?? ''),
          trailing: Text(professor['email'] ?? ''),
        );
      },
    );
  }
}