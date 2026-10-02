import 'package:flutter/material.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/apiService.dart';
import '../../models/turmaModel.dart';
import '../../services/turmasService.dart';

// Ponto de entrada do desempenho academico (Marco 3) na visao da
// Coordenacao: escolher a turma antes de ver o boletim dela.
class BoletimTurmasScreen extends StatefulWidget {
  const BoletimTurmasScreen({super.key});

  @override
  State<BoletimTurmasScreen> createState() => _BoletimTurmasScreenState();
}

class _BoletimTurmasScreenState extends State<BoletimTurmasScreen> {
  final TurmasService _turmasService = TurmasService();

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
      final turmas = await _turmasService.listarTurmas();
      setState(() => _turmas = turmas);
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar turmas: ${e.mensagem}');
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Desempenho Acadêmico')),
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
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Nenhuma turma cadastrada ainda')),
        ],
      );
    }

    return ListView.builder(
      itemCount: _turmas.length,
      itemBuilder: (context, index) {
        final turma = _turmas[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.grading_outlined)),
          title: Text(turma.nome),
          subtitle: Text(
            turma.descricao.isEmpty ? 'Sem descrição' : turma.descricao,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.boletimTurmaCoordenacao,
              arguments: turma,
            );
          },
        );
      },
    );
  }
}
