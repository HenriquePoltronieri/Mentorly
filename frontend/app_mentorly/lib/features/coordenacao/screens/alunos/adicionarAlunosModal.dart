import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/apiService.dart';
import '../../services/alunosService.dart';

// modal pra coordenacao adicionar alunos numa turma - via planilha ou manual
// IMPORTANTE PRO BACKEND:
// endpoint 1 (baixar modelo) -> GET {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos/modelo-planilha
// deve retornar um arquivo .xlsx ou .csv pronto pra download, com as colunas
// que o backend espera (ex: nome, matricula)
//
// endpoint 2 (importar) -> POST {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos/importar
// multipart/form-data, campo do arquivo chamado "arquivo"
// resposta esperada (201) -> { "adicionados": 15 }
// resposta esperada em erro (400) -> { "erro": "mensagem, ex: planilha com formato invalido" }
//
// endpoint 3 (manual) -> POST {baseUrl}/api/coordenacao/turmas/{turmaId}/alunos
// body enviado -> { "nome": "...", "matricula": "..." }
// resposta esperada (201) -> { "id": 1, "nome": "...", "matricula": "..." }
//
// uso: showDialog(context: context, builder: (_) => AdicionarAlunosModal(turmaId: turma['id']))
// retorna 'true' via Navigator.pop se algum aluno foi adicionado (pra tela recarregar a lista)
class AdicionarAlunosModal extends StatefulWidget {
  final int turmaId;

  const AdicionarAlunosModal({super.key, required this.turmaId});

  @override
  State<AdicionarAlunosModal> createState() => _AdicionarAlunosModalState();
}

class _AdicionarAlunosModalState extends State<AdicionarAlunosModal> {
  final AlunosService _alunosService = AlunosService();
  final ApiService _api = ApiService();

  bool _enviando = false;
  String? _mensagemErro;
  String? _mensagemSucesso;

  Future<void> _baixarModelo() async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/coordenacao/turmas/${widget.turmaId}/alunos/modelo-planilha',
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
        Uri.parse('${ApiService.baseUrl}/coordenacao/turmas/${widget.turmaId}/alunos/importar'),
      );
      // Add auth header if token exists
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
          _mensagemSucesso = '${dados['adicionados']} aluno(s) adicionado(s) com sucesso';
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
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: matriculaController,
                decoration: const InputDecoration(labelText: 'Matrícula'),
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
      _mensagemErro = null;
      _mensagemSucesso = null;
    });

    try {
      await _alunosService.cadastrarAluno(
        turmaId: widget.turmaId,
        nome: nomeController.text.trim(),
        matricula: matriculaController.text.trim(),
      );
      setState(() => _mensagemSucesso = 'Aluno adicionado com sucesso');
    } on ApiException catch (e) {
      setState(() => _mensagemErro = e.mensagem);
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
        width: 460,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Adicionar Alunos', style: TextStyle(fontSize: 22)),
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
                    'Baixe o modelo, preencha com os dados dos seus alunos e envie de volta',
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
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Adicionar Aluno Manualmente'),
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
                child: Text(
                  _mensagemErro!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_mensagemSucesso != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _mensagemSucesso!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }
}