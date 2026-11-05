import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/apiService.dart';

class ConversaIa extends ChangeNotifier {
  final int? turmaId;
  final int? alunoId;
  final String? token;
  final List<Map<String, dynamic>> mensagens = [];
  final List<Map<String, dynamic>> historico = [];
  bool digitando = false;
  bool carregando = true;
  String? erro, pendente;
  late final Future<void> _pronto;

  ConversaIa(this.turmaId, this.token, {this.alunoId}) {
    _pronto = _carregar();
  }

  String get _chave {
    final usuario = ApiService().usuario?['id']?.toString() ?? 'sem-usuario';
    var escola = 'sem-escola';
    try {
      final parte = token!.split('.')[1];
      final normalizada = base64Url.normalize(parte);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalizada)));
      escola = payload['coordenacao_id']?.toString() ?? escola;
    } catch (_) {
      // A chave local e apenas um namespace; a autenticacao continua no backend.
    }
    return 'mentorly.chat_ia.$escola.$usuario.${turmaId ?? 'geral'}.${alunoId ?? 'turma'}';
  }

  Future<void> _carregar() async {
    try {
      final bruto = (await SharedPreferences.getInstance()).getString(_chave);
      if (bruto != null) {
        final dados = jsonDecode(bruto) as Map<String, dynamic>;
        mensagens.addAll(_mensagensValidas(dados['atual']));
        final salvas = dados['historico'];
        if (salvas is List) {
          for (final item in salvas) {
            if (item is! Map) continue;
            final convertido = item.cast<String, dynamic>();
            final lista = _mensagensValidas(convertido['mensagens']);
            if (lista.isEmpty) continue;
            historico.add({
              'id': convertido['id']?.toString() ?? '',
              'titulo': convertido['titulo']?.toString() ?? 'Conversa',
              'data': convertido['data']?.toString() ?? '',
              'mensagens': lista,
            });
          }
        }
      }
    } catch (_) {
      // Preferencias antigas/corrompidas nao impedem uma nova conversa.
      mensagens.clear();
      historico.clear();
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _mensagensValidas(dynamic bruto) {
    if (bruto is! List) return [];
    final resultado = <Map<String, dynamic>>[];
    for (final item in bruto) {
      if (item is! Map) continue;
      final mapa = item.cast<String, dynamic>();
      if ((mapa['role'] != 'user' && mapa['role'] != 'assistant') ||
          mapa['content'] is! String) {
        continue;
      }
      resultado.add({
        'role': mapa['role'],
        'content': mapa['content'],
        if (mapa['atalhos'] is List) 'atalhos': mapa['atalhos'],
        if (mapa['tipo'] is String) 'tipo': mapa['tipo'],
        if (mapa['aviso'] is String) 'aviso': mapa['aviso'],
        if (mapa['limpar_foco'] == true) 'limpar_foco': true,
      });
    }
    return resultado;
  }

  Future<void> _salvar() async {
    await (await SharedPreferences.getInstance()).setString(
      _chave,
      jsonEncode({'atual': mensagens, 'historico': historico}),
    );
  }

  void _arquivarAtual() {
    if (mensagens.isEmpty) return;
    final primeira = mensagens.firstWhere(
      (m) => m['role'] == 'user',
      orElse: () => mensagens.first,
    );
    final texto = primeira['content'].toString().replaceAll('\n', ' ').trim();
    historico.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'titulo': texto.length > 70 ? '${texto.substring(0, 70)}…' : texto,
      'data': DateTime.now().toIso8601String(),
      'mensagens': mensagens.map((m) => Map<String, dynamic>.from(m)).toList(),
    });
    if (historico.length > 30) historico.removeRange(30, historico.length);
  }

  void nova() {
    if (digitando) return;
    _arquivarAtual();
    mensagens.clear();
    erro = null;
    pendente = null;
    _salvar();
    notifyListeners();
  }

  void restaurar(String id) {
    if (digitando) return;
    final indice = historico.indexWhere((item) => item['id'] == id);
    if (indice < 0) return;
    final escolhida = historico.removeAt(indice);
    _arquivarAtual();
    mensagens
      ..clear()
      ..addAll(_mensagensValidas(escolhida['mensagens']));
    erro = null;
    pendente = null;
    _salvar();
    notifyListeners();
  }

  void excluirHistorico(String id) {
    historico.removeWhere((item) => item['id'] == id);
    _salvar();
    notifyListeners();
  }

  void limparHistorico() {
    historico.clear();
    _salvar();
    notifyListeners();
  }

  Future<void> enviar(String texto, {bool repetir = false}) async {
    await _pronto;
    texto = texto.trim();
    if (digitando || texto.isEmpty) return;
    if (texto.length > 1000) {
      erro = 'Use uma mensagem de até 1.000 caracteres.';
      notifyListeners();
      return;
    }
    if (ApiService().token != token) {
      erro = 'Sua sessão mudou. Abra uma nova conversa.';
      notifyListeners();
      return;
    }
    if (!repetir) {
      // O mesmo atalho apos uma falha retenta a mensagem ja exibida.
      if (pendente == texto &&
          mensagens.isNotEmpty &&
          mensagens.last['role'] == 'user' &&
          mensagens.last['content'] == texto) {
        return enviar(texto, repetir: true);
      }
      pendente = texto;
      mensagens.add({'role': 'user', 'content': texto});
      await _salvar();
    }
    digitando = true;
    erro = null;
    notifyListeners();
    try {
      final anteriores = mensagens.take(mensagens.length - 1).toList();
      final recentes = anteriores
          .skip(anteriores.length > 10 ? anteriores.length - 10 : 0)
          .map((m) => {'role': m['role'], 'content': m['content']})
          .toList();
      Map<String, dynamic>? focoAnterior;
      for (final mensagem in anteriores.reversed) {
        if (mensagem['role'] == 'assistant' && mensagem['limpar_foco'] == true) break;
        if (mensagem['role'] != 'assistant' || mensagem['atalhos'] is! List) {
          continue;
        }
        final atalhos = mensagem['atalhos'] as List;
        if (atalhos.isEmpty || atalhos.first is! Map) continue;
        final atalho = (atalhos.first as Map).cast<String, dynamic>();
        if (atalho['turma_id'] is int) {
          focoAnterior = {
            'turma_id': atalho['turma_id'],
            if (atalho['aluno_id'] is int) 'aluno_id': atalho['aluno_id'],
          };
          break;
        }
      }
      final resposta = await ApiService().post('/professor/ia/chat', {
        'mensagem': texto,
        if (turmaId != null) 'turma_id': turmaId,
        if (alunoId != null) 'aluno_id': alunoId,
        'historico': recentes,
        if (focoAnterior != null) 'foco_anterior': focoAnterior,
      });
      if (ApiService().token != token) return;
      mensagens.add({
        'role': 'assistant',
        'content': resposta['resposta'],
        'atalhos': resposta['atalhos'],
        if (resposta['tipo'] is String) 'tipo': resposta['tipo'],
        if (resposta['aviso'] is String) 'aviso': resposta['aviso'],
        if (resposta['limpar_foco'] == true) 'limpar_foco': true,
      });
      pendente = null;
      await _salvar();
    } catch (e) {
      erro = e is ApiException
          ? e.mensagem
          : 'Não foi possível consultar a IA. Tente novamente.';
    } finally {
      digitando = false;
      notifyListeners();
    }
  }
}

class ChatIaService {
  static String? _token;
  static final _conversas = <String, ConversaIa>{};
  static ConversaIa conversa(int? turmaId, {int? alunoId}) {
    if (_token != ApiService().token) {
      _conversas.clear();
      _token = ApiService().token;
    }
    return _conversas.putIfAbsent('$turmaId:$alunoId',
        () => ConversaIa(turmaId, _token, alunoId: alunoId));
  }
}
