import '../../app/theme.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/apiService.dart';

// Gerenciamento exclusivo da Coordenação.
enum PapelAluno { coordenacao, professor }

class AdicionarAlunosModal extends StatefulWidget {
  final int turmaId;
  final PapelAluno papel;

  const AdicionarAlunosModal({
    super.key,
    required this.turmaId,
    this.papel = PapelAluno.coordenacao,
  });

  @override
  State<AdicionarAlunosModal> createState() => _AdicionarAlunosModalState();
}

class _AdicionarAlunosModalState extends State<AdicionarAlunosModal> {
  final ApiService _api = ApiService();

  bool _enviando = false;
  bool _adicionouAlgum = false;
  String? _mensagemErro;
  String? _mensagemSucesso;

  // Erros linha a linha devolvidos pela importacao:
  // [{ "linha": 4, "motivo": "nome incompleto" }, ...]
  List<dynamic> _errosDaPlanilha = [];

  String get _base => '/coordenacao/turmas/${widget.turmaId}/alunos';

  void _limparMensagens() {
    _mensagemErro = null;
    _mensagemSucesso = null;
    _errosDaPlanilha = [];
  }

  Future<void> _baixarModelo() async {
    // launchUrl abre outra aba e nao manda cabecalho, entao o token vai na
    // query string (o backend aceita ?token= so nos downloads).
    try {
      final url = await _api.autorizarDownload('$_base/modelo-planilha');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('download');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Não foi possível baixar o modelo');
    }
  }

  Future<void> _enviarArquivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );

    if (!mounted || resultado == null || resultado.files.isEmpty) return;
    final arquivo = resultado.files.first;

    if (arquivo.bytes == null) {
      setState(
          () => _mensagemErro = 'Não foi possível ler o arquivo selecionado');
      return;
    }

    setState(() {
      _enviando = true;
      _limparMensagens();
    });

    try {
      final dados = await _api.enviarArquivo(
        '$_base/importar',
        bytes: arquivo.bytes!,
        nomeArquivo: arquivo.name,
      );

      final adicionados = dados['adicionados'] ?? 0;
      final erros = (dados['erros'] as List?) ?? [];

      if (!mounted) return;
      setState(() {
        _errosDaPlanilha = erros;
        _adicionouAlgum = _adicionouAlgum || adicionados > 0;
        _mensagemSucesso = adicionados > 0
            ? '$adicionados aluno(s) importado(s) com sucesso'
            : null;
        if (adicionados == 0) {
          _mensagemErro = erros.isEmpty
              ? 'Nenhum aluno foi importado'
              : 'Nenhum aluno foi importado: todas as linhas tinham erro';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = e.mensagem);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _adicionarManual() async {
    final nomeController = TextEditingController();
    final matriculaController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar aluno manualmente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  helperText: 'Informe nome e sobrenome',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: matriculaController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.pop(context, true),
                decoration: const InputDecoration(
                  labelText: 'Matrícula (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    if (confirmou != true || nomeController.text.trim().isEmpty) return;

    setState(() {
      _enviando = true;
      _limparMensagens();
    });

    try {
      await _api.post(_base, {
        'nome': nomeController.text.trim(),
        if (matriculaController.text.trim().isNotEmpty)
          'matricula': matriculaController.text.trim(),
      });
      setState(() {
        _adicionouAlgum = true;
        _mensagemSucesso = 'Aluno adicionado com sucesso';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagemErro = e.mensagem);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.papel == PapelAluno.professor || !ApiService().ehCoordenacao) {
      return const AlertDialog(
          title: Text('Acesso restrito'),
          content: Text('Somente a Coordenação gerencia os alunos.'));
    }

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppVisual.raioCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                      child: Text('Adicionar Alunos',
                          style: TextStyle(fontSize: 22))),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _adicionouAlgum),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _blocoPlanilha(),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Ou', style: TextStyle(color: Colors.black54)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _enviando ? null : _adicionarManual,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Adicionar um aluno manualmente'),
                ),
              ),
              if (_enviando) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_mensagemSucesso != null) ...[
                const SizedBox(height: 16),
                _aviso(_mensagemSucesso!, Colors.green,
                    Icons.check_circle_outline),
              ],
              if (_mensagemErro != null) ...[
                const SizedBox(height: 12),
                _aviso(_mensagemErro!, Colors.red, Icons.error_outline),
              ],
              if (_errosDaPlanilha.isNotEmpty) _listaDeErros(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blocoPlanilha() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Importar Planilha',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Baixe o modelo (colunas nome, matricula e email), preencha e '
            'envie de volta. O nome completo é obrigatório.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _enviando ? null : _baixarModelo,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Baixar Modelo'),
              ),
              OutlinedButton.icon(
                onPressed: _enviando ? null : _enviarArquivo,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Enviar Arquivo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Mostra exatamente qual linha da planilha falhou e por que, pra pessoa
  // conseguir corrigir sem adivinhar.
  Widget _listaDeErros() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_errosDaPlanilha.length} linha(s) não importada(s):',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._errosDaPlanilha.map(
              (erro) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Linha ${erro['linha']}: ${erro['motivo']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aviso(String texto, Color cor, IconData icone) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: cor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: TextStyle(color: cor))),
      ],
    );
  }
}
