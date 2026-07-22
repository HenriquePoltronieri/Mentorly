import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// modal pra coordenacao criar uma turma nova
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> POST {baseUrl}/api/coordenacao/turmas
// body enviado -> { "nome": "...", "disciplina": "...", "turno": "..." }
// resposta esperada (201) -> { "id": 1, "nome": "...", "disciplina": "...", "turno": "..." }
//
// uso: showDialog(context: context, builder: (_) => const AdicionarTurmaModal())
// retorna 'true' via Navigator.pop se a turma foi criada com sucesso
class AdicionarTurmaModal extends StatefulWidget {
  const AdicionarTurmaModal({super.key});

  @override
  State<AdicionarTurmaModal> createState() => _AdicionarTurmaModalState();
}

class _AdicionarTurmaModalState extends State<AdicionarTurmaModal> {
  final _nomeController = TextEditingController();
  final _disciplinaController = TextEditingController();
  final _turnoController = TextEditingController();

  bool _carregando = false;
  String? _mensagemErro;

  // ATENCAO: 10.0.2.2 so funciona no emulador Android.
  // Testando no Chrome/Web, troca por 'http://localhost:5000'
  static const String baseUrl = 'http://localhost:5000';

  Future<void> _adicionar() async {
    if (_nomeController.text.trim().isEmpty) {
      setState(() => _mensagemErro = 'Digite o nome da turma');
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/coordenacao/turmas'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nome': _nomeController.text.trim(),
              'disciplina': _disciplinaController.text.trim(),
              'turno': _turnoController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        setState(() => _mensagemErro = 'Erro ao criar turma');
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
  void dispose() {
    _nomeController.dispose();
    _disciplinaController.dispose();
    _turnoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Stack(
            children: [
              // detalhes decorativos nos cantos, igual o mockup
              Positioned(
                top: -20,
                right: -20,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Color(0xFFA7F3D0),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFBFDBFE),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Adicionar Turma',
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 24),
                  const Text('Nome da turma:'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      hintText: 'Exemplo "3 ano A"',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Disciplina:'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _disciplinaController,
                    decoration: const InputDecoration(
                      hintText: 'Exemplo "Matemática"',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Turno:'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _turnoController,
                    decoration: const InputDecoration(
                      hintText: 'Exemplo "Manhã"',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (_mensagemErro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _mensagemErro!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _adicionar,
                      child: _carregando
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Adicionar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}