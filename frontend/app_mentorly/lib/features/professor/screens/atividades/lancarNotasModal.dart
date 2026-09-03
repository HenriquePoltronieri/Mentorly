import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/apiService.dart';

// Lancamento de notas em lote por planilha, numa atividade.
// Mesmo padrao do AdicionarAlunosModal.
//
// Endpoints (exclusivos do Professor - a Coordenacao recebe 403):
//   GET  {baseUrl}/atividades/{id}/notas/modelo-planilha
//        vem com os alunos da turma ja preenchidos e a coluna nota vazia
//   POST {baseUrl}/atividades/{id}/notas/importar
//        multipart, campo "arquivo"
//        resposta 201 -> { "lancadas": 8, "erros": [{ "linha": 3, "motivo": "..." }] }
//
// uso: showDialog(context: context, builder: (_) => LancarNotasModal(atividadeId: ...))
// retorna true via Navigator.pop se alguma nota foi lancada.
class LancarNotasModal extends StatefulWidget {
  final String atividadeId;

  const LancarNotasModal({super.key, required this.atividadeId});

  @override
  State<LancarNotasModal> createState() => _LancarNotasModalState();
}

class _LancarNotasModalState extends State<LancarNotasModal> {
  final ApiService _api = ApiService();

  bool _enviando = false;
  bool _lancouAlguma = false;
  String? _mensagemErro;
  String? _mensagemSucesso;
  List<dynamic> _errosDaPlanilha = [];

  String get _base => '/atividades/${widget.atividadeId}/notas';

  Future<void> _baixarModelo() async {
    // launchUrl abre outra aba e nao manda cabecalho: o token vai na query
    // string, que o backend aceita so nos downloads de modelo.
    final url = Uri.parse(_api.urlComToken('$_base/modelo-planilha'));
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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

    if (resultado == null || resultado.files.isEmpty) return;
    final arquivo = resultado.files.first;

    if (arquivo.bytes == null) {
      setState(() => _mensagemErro = 'Não foi possível ler o arquivo selecionado');
      return;
    }

    setState(() {
      _enviando = true;
      _mensagemErro = null;
      _mensagemSucesso = null;
      _errosDaPlanilha = [];
    });

    try {
      final dados = await _api.enviarArquivo(
        '$_base/importar',
        bytes: arquivo.bytes!,
        nomeArquivo: arquivo.name,
      );

      final lancadas = dados['lancadas'] ?? 0;
      final erros = (dados['erros'] as List?) ?? [];

      setState(() {
        _errosDaPlanilha = erros;
        _lancouAlguma = _lancouAlguma || lancadas > 0;
        _mensagemSucesso =
            lancadas > 0 ? '$lancadas nota(s) lançada(s) com sucesso' : null;
        if (lancadas == 0) {
          _mensagemErro = erros.isEmpty
              ? 'Nenhuma nota foi lançada'
              : 'Nenhuma nota foi lançada: todas as linhas tinham erro';
        }
      });
    } on ApiException catch (e) {
      setState(() => _mensagemErro = e.mensagem);
    } catch (_) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lançar Notas', style: TextStyle(fontSize: 22)),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _lancouAlguma),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
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
                      'O modelo já vem com os alunos da turma. Preencha só a '
                      'coluna nota e envie de volta.',
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
              ),
              if (_enviando) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_mensagemSucesso != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_mensagemSucesso!,
                          style: const TextStyle(color: Colors.green)),
                    ),
                  ],
                ),
              ],
              if (_mensagemErro != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_mensagemErro!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
              // Mostra a linha exata e o motivo, pra pessoa corrigir sem
              // ter que adivinhar o que a planilha tinha de errado.
              if (_errosDaPlanilha.isNotEmpty)
                Padding(
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
                          '${_errosDaPlanilha.length} linha(s) não lançada(s):',
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
