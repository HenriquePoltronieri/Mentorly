import 'package:flutter/material.dart';
import '../../../core/services/apiService.dart';

class TermosPainel extends StatefulWidget {
  final Map<String, dynamic>? documentos;
  final bool? usoInicial;
  final bool? consentimentoInicial;

  const TermosPainel({super.key, this.documentos, this.usoInicial,
    this.consentimentoInicial});

  @override
  State<TermosPainel> createState() => TermosPainelState();
}

class TermosPainelState extends State<TermosPainel> {
  Map<String, dynamic>? _documentos;
  bool? _uso;
  bool? _consentimento;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _uso = widget.usoInicial;
    _consentimento = widget.consentimentoInicial;
    _documentos = widget.documentos;
    if (_documentos == null) _carregar();
  }

  Future<void> _carregar() async {
    try {
      final resposta = await ApiService().get('/termos/atuais');
      if (mounted) {
        setState(() => _documentos =
            Map<String, dynamic>.from(resposta['documentos'] as Map));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar os termos.');
      }
    }
  }

  Map<String, dynamic>? dados() {
    if (_documentos == null || _uso == null || _consentimento == null) return null;
    final uso = Map<String, dynamic>.from(_documentos!['uso'] as Map);
    final consentimento =
        Map<String, dynamic>.from(_documentos!['consentimento'] as Map);
    return {
      'decisoes': {'uso': _uso, 'consentimento': _consentimento},
      'versoes': {
        'uso': uso['sha256'],
        'consentimento': consentimento['sha256'],
      },
    };
  }

  Future<void> _abrir(String tipo) async {
    final documento = Map<String, dynamic>.from(_documentos![tipo] as Map);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(documento['titulo'].toString()),
        content: SizedBox(
          width: 680,
          height: MediaQuery.sizeOf(context).height * .65,
          child: SingleChildScrollView(
            child: SelectableText(documento['texto'].toString()),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) {
      return Column(children: [
        Text(_erro!), TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
      ]);
    }
    if (_documentos == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Documentos e decisões',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 8),
      TextButton(onPressed: () => _abrir('uso'),
          child: const Text('Ler Termo de Uso completo')),
      const Text('Você aceita o Termo de Uso? O aceite é necessário para usar a conta.'),
      RadioGroup<bool>(groupValue: _uso,
        onChanged: (valor) => setState(() => _uso = valor),
        child: const Column(children: [
          RadioListTile<bool>(title: Text('Aceito o Termo de Uso'), value: true),
          RadioListTile<bool>(title: Text('Não aceito'), value: false),
        ])),
      const Divider(),
      TextButton(onPressed: () => _abrir('consentimento'),
          child: const Text('Ler Termo de Consentimento completo')),
      const Text('Você consente com o tratamento descrito no documento? '
          'A recusa permite o uso básico, mas desativa os recursos de IA.'),
      RadioGroup<bool>(groupValue: _consentimento,
        onChanged: (valor) => setState(() => _consentimento = valor),
        child: const Column(children: [
          RadioListTile<bool>(title: Text('Dou meu consentimento'), value: true),
          RadioListTile<bool>(title: Text('Não dou meu consentimento'), value: false),
        ])),
    ]);
  }
}
