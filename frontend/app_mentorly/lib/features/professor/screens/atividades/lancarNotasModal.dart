import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/apiService.dart';
import '../../services/lancarNotasService.dart';

// modal pra lancar notas em lote via planilha numa atividade
// segue o mesmo padrao do AdicionarAlunosModal (coordenacao)
//
// IMPORTANTE PRO BACKEND:
// endpoint 1 (baixar modelo) -> GET {baseUrl}/api/atividades/{atividadeId}/notas/modelo-planilha
// deve vir com a lista de alunos ja preenchida (nome/matricula) e coluna
// vazia pra nota, facilitando o preenchimento
//
// endpoint 2 (importar) -> POST {baseUrl}/api/atividades/{atividadeId}/notas/importar
// multipart/form-data, campo do arquivo chamado "arquivo"
// resposta esperada (201) -> { "lancadas": 8 }
// resposta esperada em erro (400) -> { "erro": "mensagem" }
//
// NOTA PRO BACKEND: esse fluxo manda o arquivo bruto direto pro servidor
// (o servidor que le a planilha), diferente do metodo
// "lancarNotasPlanilha" do AtividadesController, que espera receber os
// dados ja convertidos em lista. Usar UM dos dois - nao os dois juntos.
//
// uso: showDialog(context: context, builder: (_) => LancarNotasModal(atividadeId: atividade.id))
// retorna 'true' via Navigator.pop se alguma nota foi lancada
class LancarNotasModal extends StatefulWidget {
  final String atividadeId;

  const LancarNotasModal({super.key, required this.atividadeId});

  @override
  State<LancarNotasModal> createState() => _LancarNotasModalState();
}

class _LancarNotasModalState extends State<LancarNotasModal> {
  final LancarNotasService _lancarNotasService = LancarNotasService();
  final ApiService _api = ApiService();

  bool _enviando = false;
  String? _mensagemErro;
  String? _mensagemSucesso;

  Future<void> _baixarModelo() async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/atividades/${widget.atividadeId}/notas/modelo-planilha',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível baixar o modelo')),
      );
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
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/atividades/${widget.atividadeId}/notas/importar'),
      );
      if (_api.token != null) {
        request.headers['Authorization'] = 'Bearer ${_api.token}';
      }
      request.files.add(
        http.MultipartFile.fromBytes('arquivo', arquivo.bytes!, filename: arquivo.name),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final dados = jsonDecode(response.body);
        setState(() {
          _mensagemSucesso = '${dados['lancadas']} nota(s) lançada(s) com sucesso';
        });
      } else {
        final dados = jsonDecode(response.body);
        setState(() {
          _mensagemErro = dados['erro'] ?? 'Erro ao importar planilha';
        });
      }
    } catch (e) {
      setState(() => _mensagemErro = 'Não foi possível conectar ao servidor');
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
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
                  onPressed: () => Navigator.pop(context, _mensagemSucesso != null),
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
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, color: Colors.green),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Importar Planilha',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Baixe o modelo (já vem com os alunos da turma), preencha as notas e envie de volta',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _baixarModelo,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Baixar Modelo'),
                      ),
                      const SizedBox(width: 8),
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
            if (_enviando)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_mensagemErro != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_mensagemErro!, style: const TextStyle(color: Colors.red)),
              ),
            if (_mensagemSucesso != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_mensagemSucesso!, style: const TextStyle(color: Colors.green)),
              ),
          ],
        ),
      ),
    );
  }
}