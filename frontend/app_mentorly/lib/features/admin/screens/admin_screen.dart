import 'package:flutter/material.dart';
import '../../../app/routes.dart';
import '../../../core/services/apiService.dart';
import '../../../core/widgets/estrutura_pagina.dart';
import '../services/admin_service.dart';

String dataAdmin(dynamic valor) {
  final data = DateTime.tryParse(valor?.toString() ?? '');
  return data == null
      ? 'Sem prazo'
      : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
}

class AdminScreen extends StatefulWidget {
  final AdminService? servico;
  const AdminScreen({super.key, this.servico});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminService _servico;
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _busca = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _ocupado = true;
  bool _dialogoAberto = false;
  String? _erro;
  Map<String, dynamic>? _painel;
  @override
  void initState() {
    super.initState();
    _servico = widget.servico ?? AdminService();
    _executar(() async {
      await _servico.consultarSessao();
      if (_servico.usuario != null) _painel = await _servico.listar('');
    });
  }

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await acao();
    } catch (e) {
      if (mounted)
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível concluir. Tente novamente.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrar() async {
    if (_ocupado || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await _executar(() async {
      await _servico.entrar(_email.text.trim(), _senha.text);
      _senha.clear();
      _painel = await _servico.listar('');
    });
  }

  Future<void> _buscar() async {
    if (_ocupado) return;
    FocusScope.of(context).unfocus();
    await _executar(
        () async => _painel = await _servico.listar(_busca.text.trim()));
  }

  Future<void> _editar(Map escola, {bool reativar = false}) async {
    if (_ocupado || _dialogoAberto) return;
    _dialogoAberto = true;
    final salvo = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditarAcesso(
            escola: escola,
            painel: _painel!,
            servico: _servico,
            reativar: reativar));
    if (!mounted) return;
    _dialogoAberto = false;
    await _executar(() async {
      _painel = await _servico.listar(_busca.text.trim());
    });
    if (salvo == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reativar
              ? 'Conta reativada para a escola e seus professores.'
              : 'Acesso atualizado para a escola e seus professores.')));
    }
  }

  Future<void> _excluir(Map escola) async {
    if (_ocupado || _dialogoAberto) return;
    _dialogoAberto = true;
    final excluida = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ExcluirEscola(escola: escola, servico: _servico));
    if (!mounted) return;
    _dialogoAberto = false;
    if (excluida == true) {
      await _executar(() async {
        _painel = await _servico.listar(_busca.text.trim());
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Conta de coordenacao excluida definitivamente.')));
      }
    }
  }

  @override
  void dispose() {
    for (final campo in [_email, _senha, _busca]) {
      campo.dispose();
    }
    _servico.dispose();
    super.dispose();
  }

  Widget _login() => Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Entrar na administração',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
            'Use sua conta de administrador do Mentorly. Escolas e professores entram pelo aplicativo.'),
        const SizedBox(height: 20),
        TextFormField(
            controller: _email,
            enabled: !_ocupado,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Informe seu e-mail.' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _senha,
            enabled: !_ocupado,
            obscureText: true,
            maxLength: 128,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Senha'),
            onFieldSubmitted: (_) => _entrar(),
            validator: (v) =>
                v == null || v.isEmpty ? 'Digite sua senha.' : null),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _ocupado ? null : _entrar, child: const Text('Entrar')),
      ]));

  List<Widget> _escolas() {
    final escolas = (_painel?['escolas'] as List?) ?? [];
    final historico = (_painel?['historico'] as List?) ?? [];
    return [
      Text('Acesso das escolas',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
          'Olá, ${_servico.usuario?['nome']}. Libere testes, assinaturas e cortesias.'),
      const SizedBox(height: 16),
      const Text(
          'Cada escola recebe 14 dias de teste ao se cadastrar. Assinatura paga é uma liberação manual após conferir o recebimento.'),
      const SizedBox(height: 20),
      TextField(
          controller: _busca,
          enabled: !_ocupado,
          maxLength: 150,
          onSubmitted: (_) => _buscar(),
          decoration: InputDecoration(
              labelText: 'Buscar escola ou e-mail',
              suffixIcon: IconButton(
                  onPressed: _ocupado ? null : _buscar,
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search)))),
      if (escolas.isEmpty)
        const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
                'Nenhuma escola encontrada. Cadastre a escola no aplicativo e atualize esta lista.')),
      ...escolas.map((e) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(e['nome'].toString(),
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(e['email'].toString()),
                    const SizedBox(height: 12),
                    Text(
                        '${e['acesso']['situacao_nome']} · ${e['acesso']['liberado'] == true ? 'Acesso liberado' : 'Acesso bloqueado'}'),
                    Text('Plano: ${e['plano_nome'] ?? 'Mentorly Escolar'}'),
                    Text('Validade: ${dataAdmin(e['valido_ate'])}'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: _ocupado ? null : () => _editar(e as Map),
                        child: const Text('Gerenciar acesso')),
                    if (e['situacao'] == 'suspensa') ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                          onPressed: _ocupado
                              ? null
                              : () => _editar(e as Map, reativar: true),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reativar conta')),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: _ocupado ? null : () => _excluir(e as Map),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir conta')),
                  ])))),
      const SizedBox(height: 24),
      Text('Últimas alterações', style: Theme.of(context).textTheme.titleLarge),
      if (historico.isEmpty) const Text('Nenhuma alteração manual registrada.'),
      ...historico.map((h) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${h['escola']} · ${_painel!['situacoes'][h['situacao']]}'),
            Text('${h['administrador']} · ${dataAdmin(h['criado_em'])}'),
            Text(h['motivo'].toString()),
            const Divider(),
          ]))),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const Text('Administração do Mentorly'), actions: [
          if (_servico.usuario != null)
            IconButton(
                tooltip: 'Sair da administração',
                onPressed: _ocupado
                    ? null
                    : () => _executar(() async {
                          await _servico.sair();
                          _painel = null;
                        }),
                icon: const Icon(Icons.logout)),
        ]),
        body: ConteudoPagina(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          if (_ocupado) const LinearProgressIndicator(),
          if (_erro != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                    liveRegion: true,
                    child: Text(_erro!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)))),
          if (_servico.usuario == null) _login() else ..._escolas(),
          const SizedBox(height: 20),
          TextButton(
              onPressed: _ocupado
                  ? null
                  : () => Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.perfilSelection, (_) => false),
              child: const Text('Abrir aplicativo')),
        ])),
      );
}

class _EditarAcesso extends StatefulWidget {
  final Map escola;
  final Map painel;
  final AdminService servico;
  final bool reativar;
  const _EditarAcesso(
      {required this.escola,
      required this.painel,
      required this.servico,
      this.reativar = false});
  @override
  State<_EditarAcesso> createState() => _EditarAcessoState();
}

class _EditarAcessoState extends State<_EditarAcesso> {
  final _motivo = TextEditingController();
  final _form = GlobalKey<FormState>();
  late String _plano;
  late String _situacao;
  DateTime? _prazo;
  bool _salvando = false;
  String? _erro;
  @override
  void initState() {
    super.initState();
    _plano = widget.escola['plano_codigo']?.toString() ?? 'escolar';
    _situacao = widget.escola['situacao']?.toString() ?? 'pendente';
    _prazo = DateTime.tryParse(widget.escola['valido_ate']?.toString() ?? '');
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    if ((_situacao == 'teste' || _situacao == 'paga') && _prazo == null) {
      setState(() => _erro = 'Escolha a validade do teste ou assinatura.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.servico.salvar(widget.escola['id'] as int, {
        'versao': widget.escola['versao'],
        'plano_codigo': _plano,
        'situacao': _situacao,
        'valido_ate': _prazo?.toIso8601String().split('T').first,
        'motivo': _motivo.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_salvando,
      child: AlertDialog(
        title: Text(
            '${widget.reativar ? 'Reativar conta' : 'Acesso'}: ${widget.escola['nome']}'),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                              initialValue: _plano,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Plano'),
                              items: (widget.painel['planos'] as List)
                                  .map((p) => DropdownMenuItem(
                                      value: p['codigo'].toString(),
                                      child: Text(p['nome'].toString())))
                                  .toList(),
                              onChanged: _salvando
                                  ? null
                                  : (v) => setState(() => _plano = v!)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              initialValue: _situacao,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Situação'),
                              items: (widget.painel['situacoes'] as Map)
                                  .entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key.toString(),
                                      child: Text(e.value.toString())))
                                  .toList(),
                              onChanged: _salvando
                                  ? null
                                  : (v) => setState(() => _situacao = v!)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: _salvando
                                  ? null
                                  : () async {
                                      final data = await showDatePicker(
                                          context: context,
                                          initialDate: _prazo ?? DateTime.now(),
                                          firstDate: DateTime(1000),
                                          lastDate: DateTime(9999, 12, 31));
                                      if (mounted && data != null)
                                        setState(() => _prazo = data);
                                    },
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                  'Válido até: ${dataAdmin(_prazo?.toIso8601String())}')),
                          TextButton(
                              onPressed: _salvando
                                  ? null
                                  : () => setState(() => _prazo = null),
                              child: const Text('Remover prazo')),
                          const Text(
                              'A validade inclui o dia inteiro no horário de Brasília. Cortesia pode ficar sem prazo.'),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _motivo,
                              enabled: !_salvando,
                              maxLength: 500,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Motivo da alteração'),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Informe o motivo.'
                                  : null),
                          if (_erro != null)
                            Text(_erro!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                        ])))),
        actions: [
          TextButton(
              onPressed: _salvando ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando…' : 'Salvar acesso'))
        ],
      ));
}

class _ExcluirEscola extends StatefulWidget {
  final Map escola;
  final AdminService servico;
  const _ExcluirEscola({required this.escola, required this.servico});

  @override
  State<_ExcluirEscola> createState() => _ExcluirEscolaState();
}

class _ExcluirEscolaState extends State<_ExcluirEscola> {
  final _email = TextEditingController();
  bool _excluindo = false;
  String? _erro;

  Future<void> _confirmar() async {
    if (_excluindo) return;
    setState(() {
      _excluindo = true;
      _erro = null;
    });
    try {
      await widget.servico.excluir(widget.escola['id'] as int, _email.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Nao foi possivel excluir a conta. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_excluindo,
      child: AlertDialog(
          title: const Text('Excluir conta de coordenacao?'),
          content: SizedBox(
              width: 460,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    'A conta de ${widget.escola['nome']} e todos os dados de turmas, alunos, professores, atividades e notas serao apagados definitivamente.'),
                const SizedBox(height: 16),
                Text(
                    'Para confirmar, digite ${widget.escola['email']}.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                TextField(
                    controller: _email,
                    enabled: !_excluindo,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 150,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                        labelText: 'E-mail da escola para confirmar'),
                    onSubmitted: (_) => _confirmar()),
                if (_erro != null)
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_erro!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ])),
          actions: [
            TextButton(
                onPressed:
                    _excluindo ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton.tonalIcon(
                onPressed: _excluindo ? null : _confirmar,
                icon: const Icon(Icons.delete_forever),
                label: Text(_excluindo ? 'Excluindo...' : 'Excluir definitivamente')),
          ]));
}
