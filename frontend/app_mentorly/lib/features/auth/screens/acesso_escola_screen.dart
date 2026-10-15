import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/services/apiService.dart';
import '../../../core/widgets/estrutura_pagina.dart';

class AcessoEscolaScreen extends StatefulWidget {
  const AcessoEscolaScreen({super.key});
  @override
  State<AcessoEscolaScreen> createState() => _AcessoEscolaScreenState();
}

class _AcessoEscolaScreenState extends State<AcessoEscolaScreen> {
  Map<String, dynamic>? _acesso;
  String? _erro;
  bool _carregando = true;
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final dados = await ApiService().get('/acesso');
      if (mounted) setState(() => _acesso = Map<String, dynamic>.from(dados as Map));
    } catch (e) {
      if (mounted) setState(() => _erro = e is ApiException ? e.mensagem : 'Não foi possível consultar o acesso.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _prazo(dynamic valor) {
    if (valor == null) return 'Sem prazo definido';
    final data = DateTime.tryParse(valor.toString());
    return data == null ? 'Confira com a administração' : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acesso da escola')),
    body: ConteudoPagina(child: _carregando ? const CarregamentoPagina() : ListView(
      padding: const EdgeInsets.all(24), children: [
        Text('Plano e liberação', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (_erro != null) Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_acesso != null) ...[
          Text(_acesso!['plano_nome']?.toString() ?? 'Mentorly Escolar'),
          const SizedBox(height: 12),
          Text('Situação: ${_acesso!['situacao_nome']}'),
          Text('Validade: ${_prazo(_acesso!['valido_ate'])}'),
          const SizedBox(height: 16),
          Text(_acesso!['mensagem'].toString()),
          const SizedBox(height: 12),
          const Text('O acesso vale para a coordenação e seus professores. Para estender o teste ou obter uma cortesia, fale com a equipe do Mentorly. Seus dados são preservados quando o acesso vence.'),
          const SizedBox(height: 20),
          if (_acesso!['liberado'] == true) FilledButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context,
              ApiService().ehProfessor ? AppRoutes.dashboard : AppRoutes.coordenacaoHome, (_) => false),
            child: const Text('Continuar para o Mentorly')),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh), label: const Text('Verificar liberação')),
        TextButton(onPressed: () async {
          await ApiService().limparSessao();
          if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.perfilSelection, (_) => false);
        }, child: const Text('Sair da conta')),
      ])),
  );
}
