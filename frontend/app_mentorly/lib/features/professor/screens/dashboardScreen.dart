import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/services/apiService.dart';
import '../widgets/professorTopBar.dart';
import '../services/professorDashboardService.dart';

// dashboard do professor - so numeros/resumo, sem acao nenhuma aqui
// IMPORTANTE PRO BACKEND:
// endpoint esperado -> GET {baseUrl}/api/professor/dashboard
// resposta esperada (200) ->
// {
//   "nome": "...",
//   "email": "...",
//   "totalTurmas": 1,
//   "totalAlunos": 8,
//   "alunosEmRisco": [
//     { "nome": "...", "turma": "...", "media": 4.2 }, ...
//   ]
// }
// "alunos em risco" = alunos com media abaixo da nota minima configurada
// pela coordenacao (ver configEtapasScreen/configNotasEtapaScreen)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ProfessorDashboardService _dashboardService = ProfessorDashboardService();

  bool _carregando = true;
  String? _mensagemErro;
  Map<String, dynamic>? _dados;

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final dados = await _dashboardService.buscarDashboard();
      setState(() {
        _dados = dados;
      });
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar dados do dashboard: ${e.mensagem}');
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
      appBar: ProfessorTopBar(
        abaAtiva: 'dashboard',
        emailProfessor: _dados?['email'],
      ),
      body: RefreshIndicator(
        onRefresh: _buscarDados,
        child: Stack(
          children: [
            _construirFundoDecorativo(),
            _construirCorpo(),
          ],
        ),
      ),
    );
  }

  // um "borrao" colorido no fundo, so decorativo, igual o mockup
  Widget _construirFundoDecorativo() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Stack(
            children: [
              Positioned(
                left: 100,
                top: 150,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x552DD4BF),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                top: 80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x553B82F6),
                  ),
                ),
              ),
            ],
          ),
        ),
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

    final nome = _dados?['nome'] ?? '';
    final totalTurmas = _dados?['totalTurmas'] ?? 0;
    final totalAlunos = _dados?['totalAlunos'] ?? 0;
    final alunosEmRisco = _dados?['alunosEmRisco'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Olá Professor(a) $nome.',
          style: const TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CardNumero(
                titulo: 'Quantidade de turmas total',
                numero: totalTurmas.toString(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _CardNumero(
                titulo: 'Quantidade de alunos total',
                numero: totalAlunos.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alunos em risco',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Text(
                'Todas as turmas e todas as salas',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              if (alunosEmRisco.isEmpty)
                const Text('Nenhum aluno em risco no momento 🎉')
              else
                ...alunosEmRisco.map((aluno) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${aluno['nome']} — ${aluno['turma']}'),
                        ),
                        Text(
                          'média ${aluno['media']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardNumero extends StatelessWidget {
  final String titulo;
  final String numero;

  const _CardNumero({required this.titulo, required this.numero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const Spacer(),
          Center(
            child: Text(
              numero,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}