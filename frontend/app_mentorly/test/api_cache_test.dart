import 'dart:async';
import 'dart:convert';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().salvarSessao('escola-a', {'tipo': 'coordenacao'});
  });
  test('leituras simultâneas compartilham uma requisição e isolam os dados',
      () async {
    var chamadas = 0;
    final resposta = Completer<http.Response>();
    await http.runWithClient(() async {
      final api = ApiService();
      final primeira = api.get('/classes');
      final segunda = api.get('/classes');
      resposta.complete(http.Response('[{"id":1,"nome":"Turma A"}]', 200));
      final dados = await Future.wait([primeira, segunda]);
      expect(chamadas, 1);
      dados[0][0]['nome'] = 'Alterado';
      expect(dados[1][0]['nome'], 'Turma A');
      expect((await api.get('/classes'))[0]['nome'], 'Turma A');
      expect(chamadas, 1);
    },
        () => MockClient((r) {
              chamadas++;
              return resposta.future;
            }));
  });
  test('salvar, atualizar e trocar de sessão renovam o cache', () async {
    var leituras = 0;
    await http.runWithClient(() async {
      final api = ApiService();
      await api.get('/classes');
      await api.get('/classes');
      expect(leituras, 1);
      await api.post('/classes', {'nome': 'Nova turma'});
      await api.get('/classes');
      expect(leituras, 2);
      await api.get('/classes', atualizar: true);
      expect(leituras, 3);
      await api.salvarSessao('escola-b', {'tipo': 'coordenacao'});
      await api.get('/classes');
      expect(leituras, 4);
    },
        () => MockClient((r) async {
              if (r.method == 'GET') leituras++;
              return http.Response(
                  jsonEncode(r.method == 'GET' ? [] : {'id': 1}), 200);
            }));
  });
  test('uma resposta atrasada anterior à gravação não preenche o cache',
      () async {
    var leituras = 0;
    final atrasada = Completer<http.Response>();
    await http.runWithClient(() async {
      final api = ApiService();
      final primeira = api.get('/classes');
      await api.post('/classes', {'nome': 'Nova turma'});
      atrasada.complete(http.Response('[]', 200));
      await primeira;
      await api.get('/classes');
      expect(leituras, 2);
    },
        () => MockClient((r) async {
              if (r.method != 'GET') return http.Response('{"id":1}', 201);
              leituras++;
              if (leituras == 1) return await atrasada.future;
              return http.Response('[{"id":1}]', 200);
            }));
  });
}
