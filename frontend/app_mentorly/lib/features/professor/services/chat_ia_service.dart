import 'package:flutter/foundation.dart';
import '../../../core/services/apiService.dart';

class ConversaIa extends ChangeNotifier {
  final int? turmaId;
  final int? alunoId;
  final String? token;
  final List<Map<String, dynamic>> mensagens = [];
  bool digitando = false;
  String? erro, pendente;
  ConversaIa(this.turmaId, this.token, {this.alunoId});
  void nova() {
    if (digitando) return;
    mensagens.clear();
    erro = null;
    pendente = null;
    notifyListeners();
  }

  Future<void> enviar(String texto, {bool repetir = false}) async {
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
      pendente = texto;
      mensagens.add({'role': 'user', 'content': texto});
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
      final resposta = await ApiService().post('/professor/ia/chat', {
        'mensagem': texto,
        if (turmaId != null) 'turma_id': turmaId,
        if (alunoId != null) 'aluno_id': alunoId,
        'historico': recentes,
      });
      if (ApiService().token != token) return;
      mensagens.add({
        'role': 'assistant',
        'content': resposta['resposta'],
        'atalhos': resposta['atalhos']
      });
      pendente = null;
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
