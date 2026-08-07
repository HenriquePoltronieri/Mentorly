import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Relatório de turmas com contagem de atividades.
// Dados vêm da procedure sp_relatorio_turmas_atividades (LEFT JOIN + GROUP BY + ORDER BY)
// endpoint -> GET {baseUrl}/api/classes/relatorio/atividades
class RelatorioTurmasScreen extends StatefulWidget {
  const RelatorioTurmasScreen({super.key});

  @override
  State<RelatorioTurmasScreen> createState() => _RelatorioTurmasScreenState();
}

class _RelatorioTurmasScreenState extends State<RelatorioTurmasScreen> {
  static const String baseUrl = 'http://10.0.2.2:5000';

  bool _carregando = true;
  String? _mensagemErro;
  List<dynamic> _turmas = [];

  @override
  void initState() {
    super.initState();
    _buscarRelatorio();
  }

  Future<void> _buscarRelatorio() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/classes/relatorio/atividades'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _turmas = jsonDecode(response.body);
        });
      } else {
        setState(() => _mensagemErro = 'Erro ao buscar relatório');
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
      appBar: AppBar(title: const Text('Relatório de Turmas')),
      body: RefreshIndicator(
        onRefresh: _buscarRelatorio,
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
          Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhuma turma cadastrada')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final turma = _turmas[index];
        final totalAtividades = turma['total_atividades'] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.class_)),
            title: Text(turma['name'] ?? ''),
            subtitle: Text(turma['description'] ?? 'Sem descrição'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$totalAtividades atividades',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}