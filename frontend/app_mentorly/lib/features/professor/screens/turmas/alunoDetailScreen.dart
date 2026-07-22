import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/estatisticaAlunoModel.dart';
import '../../widgets/professorTopBar.dart';
import '../../widgets/alunoGraficoWidget.dart';

// tela de detalhe/estatisticas de um aluno especifico
// recebe o aluno via Navigator.pushNamed(context, AppRoutes.alunoDetail, arguments: aluno)
// onde "aluno" é o Map que veio da turmaAlunosScreen (tem id, nome, matricula)
//
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> GET {baseUrl}/api/professor/alunos/{alunoId}/estatisticas
// resposta esperada (200) ->
// {
//   "alunoId": "1",
//   "notas": [8.5, 6.0, 9.2],
//   "media": 7.9,
//   "percentualConclusao": 75,
//   "emRisco": false
// }
class AlunoDetailScreen extends StatefulWidget {
  const AlunoDetailScreen({super.key});

  @override
  State<AlunoDetailScreen> createState() => _AlunoDetailScreenState();
}

class _AlunoDetailScreenState extends State<AlunoDetailScreen> {
  // ATENCAO: 10.0.2.2 so funciona no emulador Android.
  // Testando no Chrome/Web, troca por 'http://localhost:5000'
  static const String baseUrl = 'http://localhost:5000';

  bool _carregando = true;
  String? _mensagemErro;
  EstatisticaAlunoModel? _estatistica;
  Map<String, dynamic>? _aluno;
  bool _jaBuscou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _aluno = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _jaBuscou = true;
      _buscarEstatisticas();
    }
  }

  Future<void> _buscarEstatisticas() async {
    if (_aluno == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Aluno não informado';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/professor/alunos/${_aluno!['id']}/estatisticas'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _estatistica = EstatisticaAlunoModel.fromJson(jsonDecode(response.body));
        });
      } else {
        setState(() => _mensagemErro = 'Erro ao buscar estatísticas');
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
      appBar: const ProfessorTopBar(abaAtiva: 'turmas'),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  _aluno?['nome'] ?? 'Aluno',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _buscarEstatisticas,
              child: _construirCorpo(),
            ),
          ),
        ],
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

    final estatistica = _estatistica;
    if (estatistica == null) {
      return const Center(child: Text('Nenhuma estatística disponível'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Matrícula: ${_aluno?['matricula'] ?? ''}'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _CardEstatistica(
                titulo: 'Média',
                valor: estatistica.media.toStringAsFixed(1),
                cor: estatistica.emRisco ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CardEstatistica(
                titulo: 'Conclusão',
                valor: '${estatistica.percentualConclusao.toStringAsFixed(0)}%',
                cor: Colors.blue,
              ),
            ),
          ],
        ),
        if (estatistica.emRisco)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('Este aluno está com média abaixo do mínimo')),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Evolução das notas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        AlunoGraficoWidget(notas: estatistica.notas),
      ],
    );
  }
}

class _CardEstatistica extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;

  const _CardEstatistica({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor),
          ),
        ],
      ),
    );
  }
}