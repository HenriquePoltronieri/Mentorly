import 'package:flutter/material.dart';
import '../../../../core/widgets/confirmarExclusaoDialog.dart';
import '../../../../core/services/apiService.dart';
import '../../../../app/routes.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../models/atividadeModel.dart';
import '../../services/atividadesService.dart';
import 'adicionarAtividadeModal.dart';

// Lista as atividades de uma turma especifica, com criar/editar/excluir.
// Fluxo: tela -> AtividadesService -> ApiService -> /api/activities?class_id=<id>
//
// Recebe a turma via Navigator.pushNamed(context, AppRoutes.turmaAtividades, arguments: turma)
class TurmaAtividadesScreen extends StatefulWidget {
  const TurmaAtividadesScreen({super.key});

  @override
  State<TurmaAtividadesScreen> createState() => _TurmaAtividadesScreenState();
}

class _TurmaAtividadesScreenState extends State<TurmaAtividadesScreen> {
  final AtividadesService _atividadesService = AtividadesService();

  bool _carregando = true;
  String? _mensagemErro;
  TurmaModel? _turma;
  bool _jaBuscou = false;
  List<AtividadeModel> _atividades = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_jaBuscou) {
      _turma = ModalRoute.of(context)!.settings.arguments as TurmaModel?;
      _jaBuscou = true;
      _buscarAtividades();
    }
  }

  Future<void> _buscarAtividades() async {
    if (_turma == null) {
      setState(() {
        _carregando = false;
        _mensagemErro = 'Turma não informada';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final atividades =
          await _atividadesService.listarAtividades(turmaId: _turma!.id);
      setState(() => _atividades = atividades);
    } on ApiException catch (e) {
      setState(() => _mensagemErro = 'Erro ao buscar atividades: ${e.mensagem}');
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirAdicionarAtividade() async {
    if (_turma == null) return;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => AdicionarAtividadeModal(turmas: [_turma!]),
    );

    if (salvou == true) _buscarAtividades();
  }

  Future<void> _abrirLancarNotas(AtividadeModel atividade) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.atividadeNotas,
      arguments: {'atividade': atividade, 'turma': _turma},
    );
  }

  Future<void> _abrirEditarAtividade(AtividadeModel atividade) async {
    if (_turma == null) return;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AdicionarAtividadeModal(turmas: [_turma!], atividade: atividade),
    );

    if (salvou == true) _buscarAtividades();
  }

  Future<void> _excluirAtividade(AtividadeModel atividade) async {
    final confirmou = await confirmarExclusao(
      context,
      titulo: 'Excluir atividade?',
      nome: atividade.nome,
      aviso: AvisosDeExclusao.atividade,
    );

    if (!confirmou) return;

    try {
      await _atividadesService.excluirAtividade(atividade.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Atividade "${atividade.nome}" excluída')),
      );
      _buscarAtividades();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: ${e.mensagem}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_turma == null ? 'Atividades' : 'Atividades · ${_turma!.nome}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirAdicionarAtividade,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar atividade'),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarAtividades,
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
            child:
                Text(_mensagemErro!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    }

    if (_atividades.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhuma atividade criada ainda')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _atividades.length,
      itemBuilder: (context, index) {
        final atividade = _atividades[index];
        final estreita = MediaQuery.sizeOf(context).width < _larguraEstreita;
        final acoes = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _abrirEditarAtividade(atividade),
            ),
            IconButton(
              tooltip: 'Lançar notas',
              icon: const Icon(Icons.grading_outlined),
              onPressed: () => _abrirLancarNotas(atividade),
            ),
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _excluirAtividade(atividade),
            ),
          ],
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.assignment)),
            title: Text(atividade.nome),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_montarSubtitulo(atividade).isNotEmpty)
                  Text(
                    _montarSubtitulo(atividade),
                    key: ValueKey('atividade-resumo-${atividade.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                // So a lista mostra uma previa: a descricao completa continua
                // no model e no formulario de edicao. Atividade gerada pela IA
                // (9B) pode ter varias questoes, gabarito e rubrica no texto.
                if (atividade.descricao.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _previaDaDescricao(atividade.descricao),
                      key: ValueKey('atividade-previa-${atividade.id}'),
                      maxLines: _linhasDaPrevia,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (!atividade.configuracaoCompleta)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Sem etapa, critério ou valor definido — edite a '
                      'atividade para poder lançar notas.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                // Em tela estreita os tres botoes ao lado do texto deixavam o
                // titulo numa coluna de ~100 px (card enorme): vao para baixo.
                if (estreita)
                  Align(alignment: Alignment.centerRight, child: acoes),
              ],
            ),
            isThreeLine: !atividade.configuracaoCompleta,
            trailing: estreita ? null : acoes,
            // Tocar na atividade leva ao lancamento de notas, que era a
            // tela orfa do app - nenhuma rota apontava para ela.
            onTap: () => _abrirLancarNotas(atividade),
          ),
        );
      },
    );
  }

  // Linhas da previa da descricao na lista.
  static const int _linhasDaPrevia = 2;

  // Abaixo desta largura os botoes saem do lado do texto (ver itemBuilder).
  static const double _larguraEstreita = 480;

  // "1º Bimestre • Prova • Vale 20 pontos • Entrega: 2026-09-15"
  //
  // So o essencial: a descricao tem a propria linha (previa limitada) logo
  // abaixo, para nao empurrar a data de entrega para fora da tela.
  //
  // Atividade legada (criada antes de etapa/criterio/valor virarem
  // obrigatorios) simplesmente omite o que nao tem, em vez de mostrar
  // "Vale 0 pontos" - que era o valor default de um campo que a API nunca
  // mandou.
  String _montarSubtitulo(AtividadeModel atividade) {
    final partes = <String>[];
    if (atividade.etapaNome.isNotEmpty) partes.add(atividade.etapaNome);
    if (atividade.criterioNome.isNotEmpty) partes.add(atividade.criterioNome);
    if (atividade.notaMaxima != null) {
      partes.add('Vale ${_formatarValor(atividade.notaMaxima!)} pontos');
    }
    if (atividade.dataEntrega.isNotEmpty) {
      final data = atividade.dataEntrega.contains('T')
          ? atividade.dataEntrega.split('T').first
          : atividade.dataEntrega;
      partes.add('Entrega: $data');
    }
    if (partes.isEmpty) {
      return atividade.descricao.trim().isEmpty ? 'Sem descrição' : '';
    }
    return partes.join(' • ');
  }

  // Previa para a lista: quebras de linha viram espaco e o texto e cortado em
  // um tamanho que cabe nas linhas da previa (o ellipsis cuida do resto).
  // Nada disso altera a descricao guardada.
  static String _previaDaDescricao(String descricao) {
    final compacta = descricao.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compacta.length <= 240 ? compacta : compacta.substring(0, 240);
  }

  // 20.0 vira "20"; 13.5 continua "13.5".
  static String _formatarValor(double valor) => valor == valor.roundToDouble()
      ? valor.toInt().toString()
      : valor.toString();
}
