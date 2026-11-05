import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/apiService.dart';
import '../../../../core/widgets/estrutura_pagina.dart';
import '../../../coordenacao/models/turmaModel.dart';
import '../../../coordenacao/services/etapasService.dart';
import '../../../coordenacao/services/criteriosService.dart';
import '../../models/atividadeModel.dart';
import '../../models/sugestaoAtividadeModel.dart';
import '../../services/atividadesService.dart';
import '../../services/atividade_anexos_service.dart';
import '../../widgets/atividade_anexos.dart';
import 'gerarAtividadeIaDialog.dart';

class AdicionarAtividadeModal extends StatefulWidget {
  final List<TurmaModel> turmas;
  final AtividadeModel? atividade;
  final AtividadeModel? modelo;
  const AdicionarAtividadeModal(
      {super.key, required this.turmas, this.atividade, this.modelo});
  @override
  State<AdicionarAtividadeModal> createState() =>
      _AdicionarAtividadeModalState();
}

class _AdicionarAtividadeModalState extends State<AdicionarAtividadeModal> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo, _descricao, _valor, _data;
  TurmaModel? _turma;
  List<Map<String, dynamic>> _etapas = [];
  List<Map<String, dynamic>> _criterios = [];
  List<AtividadeModel> _atividadesDaTurma = [];
  int? _etapa;
  int? _criterio;
  bool _carregando = false, _salvando = false;
  String? _erro;
  int _versaoCarga = 0;
  final List<PlatformFile> _novosAnexos = [];
  @override
  void initState() {
    super.initState();
    final base = widget.atividade ?? widget.modelo;
    _titulo = TextEditingController(text: base?.nome ?? '');
    _descricao = TextEditingController(text: base?.descricao ?? '');
    _valor = TextEditingController(text: base?.notaMaxima?.toString() ?? '');
    _data = TextEditingController(
        text: (widget.atividade?.dataEntrega ?? '')
            .split('T')
            .first
            .split(' ')
            .first);
    if (widget.turmas.isNotEmpty) {
      _turma = widget.turmas.firstWhere(
          (t) => t.id == widget.atividade?.turmaId,
          orElse: () => widget.turmas.first);
    }
    _carregar();
  }

  Future<void> _carregar() async {
    final versao = ++_versaoCarga;
    setState(() {
      _carregando = true;
      _etapa = null;
      _criterio = null;
      _erro = null;
      _etapas = [];
      _criterios = [];
    });
    try {
      final lista =
          await EtapasService().listarEtapas(anoLetivo: _turma?.anoLetivo);
      if (!mounted || versao != _versaoCarga) return;
      _etapas = lista
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['fechada'] != true && e['ativa'] != false)
          .toList();
      // Nova atividade sempre começa pela primeira etapa aberta. Assim o
      // professor só avança quando escolher, em vez de o formulário reaproveitar
      // silenciosamente a etapa mais recente.
      _etapas.sort((a, b) =>
          ((a['ordem'] ?? 0) as num).compareTo((b['ordem'] ?? 0) as num));
      final base = widget.atividade ?? widget.modelo;
      _etapa = _etapas.any((e) => e['id'] == base?.etapaId)
          ? base!.etapaId
          : _etapas.isNotEmpty
              ? _etapas.first['id'] as int
              : null;
      if (_etapa != null) {
        final respostas = await Future.wait([
          CriteriosService().listarCriterios(_etapa!),
          if (_turma != null)
            AtividadesService()
                .listarAtividades(turmaId: _turma!.id, atualizar: true)
          else
            Future.value(<AtividadeModel>[]),
        ]);
        if (!mounted || versao != _versaoCarga) return;
        _criterios = respostas[0]
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => ((e['peso'] as num?) ?? 0) > 0)
            .toList();
        _atividadesDaTurma = respostas[1] as List<AtividadeModel>;
        _criterio = _criterios.any((c) => c['id'] == base?.criterioId)
            ? base!.criterioId
            : _criterios.isNotEmpty
                ? _criterios.first['id'] as int
                : null;
      }
      _padrao();
    } catch (e) {
      if (mounted && versao == _versaoCarga) {
        _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar as etapas.';
      }
    } finally {
      if (mounted && versao == _versaoCarga) {
        setState(() => _carregando = false);
      }
    }
  }

  void _padrao() {
    if (_valor.text.isEmpty && _criterio != null) {
      final restante = _restante;
      if (restante != null && restante > 0) {
        _valor.text = _formatar(restante);
      }
    }
  }

  double? get _limite {
    final encontrados = _criterios.where((c) => c['id'] == _criterio);
    return encontrados.isEmpty
        ? null
        : (encontrados.first['nota_maxima'] as num?)?.toDouble();
  }

  double get _distribuido => _atividadesDaTurma
      .where((a) =>
          a.etapaId == _etapa &&
          a.criterioId == _criterio &&
          a.id != widget.atividade?.id)
      .fold(0, (soma, a) => soma + (a.notaMaxima ?? 0));

  double? get _restante => _limite == null ? null : _limite! - _distribuido;

  String _formatar(double valor) => valor == valor.roundToDouble()
      ? valor.toInt().toString()
      : valor.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  Future<void> _trocarEtapa(int? etapa) async {
    setState(() {
      _etapa = etapa;
      _criterio = null;
      _criterios = [];
      if (widget.atividade == null && widget.modelo == null) _valor.clear();
    });
    if (etapa == null) return;
    try {
      final lista = await CriteriosService().listarCriterios(etapa);
      if (!mounted || _etapa != etapa) return;
      setState(() {
        _criterios = lista
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => ((e['peso'] as num?) ?? 0) > 0)
            .toList();
        _criterio = _criterios.isEmpty ? null : _criterios.first['id'] as int;
        _padrao();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar os tipos de pontuação.');
      }
    }
  }

  Future<void> _gerar() async {
    if (_turma == null) return;
    final sugestao = await showDialog<SugestaoAtividadeModel>(
        context: context,
        builder: (_) => GerarAtividadeIaDialog(
            turmaId: _turma!.id, etapaId: _etapa, criterioId: _criterio));
    if (sugestao != null && mounted) {
      _titulo.text = sugestao.titulo;
      _descricao.text = sugestao.descricaoFormatada();
    }
  }

  Future<void> _selecionarAnexos() async {
    final escolha = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'docx',
        'xlsx',
        'pptx',
        'txt',
        'csv'
      ],
      withData: true,
    );
    if (escolha == null || !mounted) return;
    final disponiveis = _novosAnexos.length < 10 ? 10 - _novosAnexos.length : 0;
    final validos = escolha.files
        .where((arquivo) =>
            arquivo.bytes != null && arquivo.size <= 8 * 1024 * 1024)
        .take(disponiveis)
        .toList();
    setState(() => _novosAnexos.addAll(validos));
    if (validos.length != escolha.files.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Alguns arquivos não foram adicionados. Use arquivos válidos de até 8 MB e no máximo 10 anexos.')));
    }
  }

  Future<int> _enviarAnexos(String atividadeId) async {
    var falhas = 0;
    final service = AtividadeAnexosService();
    for (final arquivo in _novosAnexos) {
      try {
        await service.enviar(atividadeId,
            bytes: arquivo.bytes!, nome: arquivo.name);
      } catch (_) {
        falhas++;
      }
    }
    return falhas;
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final servico = AtividadesService();
      final valor = double.parse(_valor.text.replaceAll(',', '.'));
      final atividade = widget.atividade == null
          ? await servico.cadastrarAtividade(
              turmaId: _turma!.id,
              nome: _titulo.text.trim(),
              etapaId: _etapa!,
              criterioId: _criterio,
              notaMaxima: valor,
              descricao: _descricao.text.trim(),
              dataEntrega: _data.text)
          : await servico.atualizarAtividade(
              id: widget.atividade!.id,
              turmaId: _turma!.id,
              nome: _titulo.text.trim(),
              etapaId: _etapa!,
              criterioId: _criterio,
              notaMaxima: valor,
              descricao: _descricao.text.trim(),
              dataEntrega: _data.text);
      if (!mounted) return;
      final tinhaAnexosNovos = _novosAnexos.isNotEmpty;
      final falhas = await _enviarAnexos(atividade.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(falhas == 0
              ? tinhaAnexosNovos
                  ? 'Atividade e arquivos salvos com sucesso!'
                  : 'Atividade salva com sucesso!'
              : 'Atividade salva, mas $falhas arquivo(s) não foram enviados.')));
      final lancar = widget.atividade == null &&
          await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                          title: const Text('Lançar notas agora?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Depois')),
                            FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Lançar notas'))
                          ])) ==
              true;
      if (!mounted) return;
      if (lancar) {
        await Navigator.pushNamed(context, AppRoutes.atividadeNotas,
            arguments: {'atividade': atividade, 'turma': _turma});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível salvar. Seus dados foram mantidos.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _valor.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.atividade == null
              ? widget.modelo == null
                  ? 'Nova atividade'
                  : 'Reaproveitar atividade'
              : 'Editar atividade')),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: _salvando || _carregando ? null : _salvar,
                  child: Text(_salvando ? 'Salvando…' : 'Salvar atividade')))),
      body: ConteudoPagina(
          largura: 720,
          child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (widget.modelo != null) ...[
                  const Text(
                      'Revise a turma, a etapa, o valor e a nova data de entrega. As notas da atividade original não serão copiadas.'),
                  const SizedBox(height: 20),
                ],
                DropdownButtonFormField<TurmaModel>(
                    initialValue: _turma,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Turma'),
                    items: widget.turmas
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t.nome)))
                        .toList(),
                    validator: (v) => v == null ? 'Escolha a turma.' : null,
                    onChanged: _salvando
                        ? null
                        : (v) {
                            setState(() {
                              _turma = v;
                              if (widget.atividade == null &&
                                  widget.modelo == null) {
                                _valor.clear();
                              }
                            });
                            _carregar();
                          }),
                const SizedBox(height: 16),
                TextFormField(
                    key: const ValueKey('atividade_titulo'),
                    controller: _titulo,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Informe o título.' : null),
                const SizedBox(height: 16),
                if (_carregando)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<int>(
                      key: ValueKey(_etapa),
                      initialValue: _etapa,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Etapa'),
                      items: _etapas
                          .map((e) => DropdownMenuItem(
                              value: e['id'] as int,
                              child: Text(e['nome'].toString())))
                          .toList(),
                      validator: (v) => v == null
                          ? 'Escolha uma etapa aberta configurada pela escola.'
                          : null,
                      onChanged: _trocarEtapa),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                    key: ValueKey('criterio-$_etapa-$_criterio'),
                    initialValue: _criterio,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Tipo de pontuação / critério'),
                    items: _criterios
                        .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nome'].toString())))
                        .toList(),
                    validator: (v) => v == null
                        ? 'A Coordenação precisa configurar um critério para esta etapa.'
                        : null,
                    onChanged: _salvando
                        ? null
                        : (v) => setState(() {
                              _criterio = v;
                              if (widget.atividade == null &&
                                  widget.modelo == null) {
                                _valor.clear();
                              }
                              _padrao();
                            })),
                if (_criterio != null && _limite != null) ...[
                  const SizedBox(height: 8),
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                          'Neste tipo de pontuação: limite da Coordenação ${_formatar(_limite!)} pts · professor já distribuiu ${_formatar(_distribuido)} pts · ainda restam ${_formatar((_restante ?? 0).clamp(0, double.infinity).toDouble())} pts.')),
                ],
                const SizedBox(height: 16),
                TextFormField(
                    key: const ValueKey('atividade_valor'),
                    controller: _valor,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Valor / nota máxima'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (n == null || !n.isFinite || n <= 0 || n > 999.99) {
                        return 'Informe um valor entre 0,01 e 999,99.';
                      }
                      if (_restante != null && n > _restante! + .000001) {
                        return 'O máximo disponível neste critério é ${_formatar((_restante!).clamp(0, double.infinity).toDouble())}.';
                      }
                      return null;
                    }),
                const SizedBox(height: 16),
                TextFormField(
                    key: const ValueKey('atividade_data'),
                    controller: _data,
                    readOnly: true,
                    decoration: const InputDecoration(
                        labelText: 'Data de entrega',
                        suffixIcon: Icon(Icons.calendar_month)),
                    validator: (v) => DateTime.tryParse(v ?? '') == null
                        ? 'Escolha a data de entrega.'
                        : null,
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(_data.text) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (d != null) {
                        _data.text = d.toIso8601String().split('T').first;
                      }
                    }),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _descricao,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)')),
                const SizedBox(height: 12),
                if (widget.atividade != null)
                  AtividadeAnexos(atividadeId: widget.atividade!.id)
                else
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Arquivos da atividade',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                const Text(
                                    'Anexe material de apoio para consultar durante a correção.'),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                    onPressed:
                                        _salvando ? null : _selecionarAnexos,
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('Escolher arquivos')),
                                ..._novosAnexos.asMap().entries.map((entrada) =>
                                    ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                            Icons.insert_drive_file_outlined),
                                        title: Text(entrada.value.name),
                                        subtitle: Text(
                                            '${(entrada.value.size / 1024).ceil()} KB'),
                                        trailing: IconButton(
                                            tooltip: 'Remover',
                                            onPressed: _salvando
                                                ? null
                                                : () => setState(() =>
                                                    _novosAnexos
                                                        .removeAt(entrada.key)),
                                            icon: const Icon(Icons.close))))
                              ]))),
                const SizedBox(height: 12),
                TextButton.icon(
                    onPressed: _salvando ? null : _gerar,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Sugerir texto com IA')),
                if (_erro != null) ...[
                  Text(_erro!, style: const TextStyle(color: Colors.red)),
                  TextButton(
                      onPressed: _carregar,
                      child: const Text('Tentar novamente'))
                ],
              ]))));
}
