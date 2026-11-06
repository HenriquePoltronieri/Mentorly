import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/services/apiService.dart';
import '../../../core/services/authService.dart';
import '../widgets/termos_painel.dart';

class TermosScreen extends StatefulWidget {
  const TermosScreen({super.key});

  @override
  State<TermosScreen> createState() => _TermosScreenState();
}

class _TermosScreenState extends State<TermosScreen> {
  final _painel = GlobalKey<TermosPainelState>();
  Map<String, dynamic>? _documentos;
  Map<String, dynamic>? _situacao;
  List<dynamic> _historico = [];
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final api = ApiService();
      final respostas = await Future.wait([
        api.get('/termos/atuais'),
        api.get('/termos/status'),
        api.get('/termos/historico'),
      ]);
      if (!mounted) return;
      setState(() {
        _documentos = Map<String, dynamic>.from(respostas[0]['documentos'] as Map);
        _situacao = Map<String, dynamic>.from(respostas[1] as Map);
        _historico = List<dynamic>.from(respostas[2]['eventos'] as List);
        _erro = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem : 'Não foi possível carregar os documentos.');
      }
    }
  }

  bool? _valor(String tipo) {
    final decisoes = _situacao?['decisoes'] as Map?;
    final valor = decisoes?[tipo];
    if (valor == 'aceito') return true;
    if (valor == 'recusado' || valor == 'revogado') return false;
    return null;
  }

  Future<void> _salvar() async {
    final dados = _painel.currentState?.dados();
    if (dados == null) {
      setState(() => _erro = 'Escolha uma resposta para cada documento.');
      return;
    }
    setState(() { _salvando = true; _erro = null; });
    try {
      final api = ApiService();
      final estado = await api.post('/termos/decisoes', dados);
      await api.atualizarTermosPendentes(estado['pendente'] == true);
      if (!mounted) return;
      if (estado['pendente'] == true) {
        setState(() => _erro = 'A decisão foi registrada. Para usar a conta, aceite o Termo de Uso.');
        await _carregar();
        return;
      }
      final acesso = await api.get('/acesso');
      if (!mounted) return;
      final destino = acesso['liberado'] != true
          ? AppRoutes.acesso
          : api.ehProfessor ? AppRoutes.dashboard : AppRoutes.coordenacaoHome;
      Navigator.pushNamedAndRemoveUntil(context, destino, (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem : 'Não foi possível registrar a decisão.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _sair() async {
    await AuthService().sair();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.perfilSelection, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Termos e consentimento'), actions: [
      TextButton(onPressed: _sair, child: const Text('Sair')),
    ]),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: _situacao == null || _documentos == null
          ? _erro != null
              ? Center(child: TextButton(onPressed: _carregar, child: Text(_erro!)))
              : const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text(_situacao!['pendente'] == true
                  ? 'Leia os documentos antes de continuar'
                  : 'Suas decisões atuais',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text('Cada escolha é registrada separadamente. Você pode revisar '
                  'ou revogar o consentimento nesta página.'),
              const SizedBox(height: 20),
              TermosPainel(key: _painel, documentos: _documentos,
                  usoInicial: _valor('uso'),
                  consentimentoInicial: _valor('consentimento')),
              const SizedBox(height: 20),
              if (_erro != null) Text(_erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(onPressed: _salvando ? null : _salvar,
                  child: Text(_salvando ? 'Salvando...' : 'Registrar decisões')),
              const SizedBox(height: 20),
              ExpansionTile(title: const Text('Histórico de decisões'), children: [
                for (final item in _historico)
                  ListTile(
                    title: Text(item['documento'] == 'uso'
                        ? 'Termo de Uso: ${item['decisao']}'
                        : 'Consentimento: ${item['decisao']}'),
                    subtitle: Text('Versão ${item['versao']} · ${item['registradoEm']}'),
                  ),
              ]),
            ]),
    )),
  );
}
