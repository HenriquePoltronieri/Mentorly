import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/apiService.dart';
import '../services/atividade_anexos_service.dart';

class AtividadeAnexos extends StatefulWidget {
  final String atividadeId;
  final bool podeAlterar;
  final bool compacto;

  const AtividadeAnexos({
    super.key,
    required this.atividadeId,
    this.podeAlterar = true,
    this.compacto = false,
  });

  @override
  State<AtividadeAnexos> createState() => _AtividadeAnexosState();
}

class _AtividadeAnexosState extends State<AtividadeAnexos> {
  final _service = AtividadeAnexosService();
  List<Map<String, dynamic>> _anexos = [];
  bool _carregando = false;
  bool _carregado = false;
  bool _enviando = false;
  String? _erro;

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final anexos = await _service.listar(widget.atividadeId);
      if (!mounted) return;
      setState(() {
        _anexos = anexos;
        _carregado = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível carregar os arquivos.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _selecionar() async {
    final escolha = await FilePicker.platform.pickFiles(
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
    final arquivo =
        escolha == null || escolha.files.isEmpty ? null : escolha.files.first;
    if (arquivo == null || arquivo.bytes == null || !mounted) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await _service.enviar(widget.atividadeId,
          bytes: arquivo.bytes!, nome: arquivo.name);
      await _carregar();
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is ApiException
            ? e.mensagem
            : 'Não foi possível enviar o arquivo.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _baixar(Map<String, dynamic> anexo) async {
    try {
      final uri = await _service.autorizarDownload(
          widget.atividadeId, (anexo['id'] as num).toInt());
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('download não aberto');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível abrir o arquivo.')));
      }
    }
  }

  Future<void> _excluir(Map<String, dynamic> anexo) async {
    final confirmou = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Remover arquivo?'),
              content: Text('Remover ${anexo['nome']} desta atividade?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remover')),
              ],
            ));
    if (confirmou != true || !mounted) return;
    try {
      await _service.excluir(widget.atividadeId, (anexo['id'] as num).toInt());
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.mensagem
                : 'Não foi possível remover o arquivo.')));
      }
    }
  }

  String _tamanho(dynamic bytes) {
    final valor = (bytes as num?)?.toInt() ?? 0;
    if (valor >= 1024 * 1024) {
      return '${(valor / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (valor >= 1024) return '${(valor / 1024).toStringAsFixed(0)} KB';
    return '$valor B';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compacto) {
      return TextButton.icon(
          onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 680, maxHeight: 650),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: AtividadeAnexos(
                            atividadeId: widget.atividadeId,
                            podeAlterar: widget.podeAlterar),
                      ),
                    ),
                  )),
          icon: const Icon(Icons.attach_file),
          label: const Text('Arquivos da atividade'));
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.attach_file),
        title: Text(_carregado
            ? 'Arquivos da atividade (${_anexos.length})'
            : 'Arquivos da atividade'),
        subtitle: const Text('Material de apoio para consultar na correção'),
        onExpansionChanged: (aberto) {
          if (aberto && !_carregado && !_carregando) _carregar();
        },
        children: [
          if (_carregando) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_erro != null) ...[
                Text(_erro!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton(
                    onPressed: _carregar,
                    child: const Text('Tentar novamente')),
              ],
              if (_carregado && _anexos.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nenhum arquivo anexado.')),
              ..._anexos.map((anexo) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(anexo['nome']?.toString() ?? 'Arquivo'),
                    subtitle: Text(_tamanho(anexo['tamanho_bytes'])),
                    onTap: () => _baixar(anexo),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          tooltip: 'Baixar arquivo',
                          onPressed: () => _baixar(anexo),
                          icon: const Icon(Icons.download_outlined)),
                      if (widget.podeAlterar)
                        IconButton(
                            tooltip: 'Remover arquivo',
                            onPressed: () => _excluir(anexo),
                            icon: const Icon(Icons.delete_outline)),
                    ]),
                  )),
              if (widget.podeAlterar)
                OutlinedButton.icon(
                    onPressed: _enviando ? null : _selecionar,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_enviando ? 'Enviando…' : 'Adicionar')),
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'PDF, imagem, Office, texto ou CSV · até 8 MB · máximo de 10 arquivos.',
                      style: TextStyle(fontSize: 12))),
            ]),
          ),
        ],
      ),
    );
  }
}
