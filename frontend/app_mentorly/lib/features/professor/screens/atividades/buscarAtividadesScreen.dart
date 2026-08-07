import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../widgets/professorTopBar.dart';

// Tela de busca de atividades com filtro por termo e ordenação.
// Dados vêm da procedure sp_buscar_atividades (WHERE LIKE + ORDER BY + LEFT JOIN)
// endpoint -> GET {baseUrl}/api/activities/buscar?termo=...&ordenar_por=...&direcao=...
class BuscarAtividadesScreen extends StatefulWidget {
  const BuscarAtividadesScreen({super.key});

  @override
  State<BuscarAtividadesScreen> createState() => _BuscarAtividadesScreenState();
}

class _BuscarAtividadesScreenState extends State<BuscarAtividadesScreen> {
  static const String baseUrl = 'http://10.0.2.2:5000';

  final _termoController = TextEditingController();
  String _ordenarPor = 'due_date';
  String _direcao = 'ASC';

  bool _carregando = false;
  bool _jaBuscou = false;
  String? _mensagemErro;
  List<dynamic> _atividades = [];

  @override
  void dispose() {
    _termoController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final params = <String, String>{
        'ordenar_por': _ordenarPor,
        'direcao': _direcao,
      };
      if (_termoController.text.trim().isNotEmpty) {
        params['termo'] = _termoController.text.trim();
      }

      final uri = Uri.parse('$baseUrl/api/activities/buscar').replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _atividades = jsonDecode(response.body);
          _jaBuscou = true;
        });
      } else {
        setState(() => _mensagemErro = 'Erro ao buscar atividades');
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _termoController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por título',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _buscar,
                    ),
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Ordenar por: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _ordenarPor,
                      items: const [
                        DropdownMenuItem(value: 'due_date', child: Text('Data')),
                        DropdownMenuItem(value: 'title', child: Text('Título')),
                        DropdownMenuItem(value: 'class', child: Text('Turma')),
                      ],
                      onChanged: (v) => setState(() => _ordenarPor = v!),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _direcao,
                      items: const [
                        DropdownMenuItem(value: 'ASC', child: Text('Crescente')),
                        DropdownMenuItem(value: 'DESC', child: Text('Decrescente')),
                      ],
                      onChanged: (v) => setState(() => _direcao = v!),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _buscar,
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _construirResultados(),
          ),
        ],
      ),
    );
  }

  Widget _construirResultados() {
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

    if (!_jaBuscou) {
      return const Center(
        child: Text('Digite um termo e clique em Buscar'),
      );
    }

    if (_atividades.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhuma atividade encontrada')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _atividades.length,
      itemBuilder: (context, index) {
        final atividade = _atividades[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.assignment)),
            title: Text(atividade['title'] ?? ''),
            subtitle: Text(
              'Turma: ${atividade['class_name'] ?? ''}',
            ),
            trailing: Text(
              atividade['due_date'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        );
      },
    );
  }
}