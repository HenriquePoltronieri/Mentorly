import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/auth/screens/acesso_escola_screen.dart';

void main() {
  final api = ApiService();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api.aoBloquearEscola = null;
    await api.salvarSessao('sessao-qa', {'id': 1, 'tipo': 'coordenacao'});
  });

  for (final verbo in ['POST', 'PUT', 'DELETE']) {
    test('$verbo: vinte cliques compartilham um envio em andamento', () async {
      var envios = 0;
      final resposta = Completer<http.Response>();
      await http.runWithClient(() async {
        final futuros = List.generate(20, (_) => switch (verbo) {
          'POST' => api.post('/qa', {'nome': 'Escola'}),
          'PUT' => api.put('/qa', {'nome': 'Escola'}),
          _ => api.delete('/qa'),
        });
        await Future<void>.delayed(Duration.zero);
        expect(envios, 1);
        resposta.complete(http.Response('{"ok":true}', 200));
        expect(await Future.wait(futuros), hasLength(20));
      }, () => MockClient((r) { envios++; return resposta.future; }));
    });
  }

  test('erro libera novo envio e resposta HTML tem mensagem amigável', () async {
    var tentativas = 0;
    await http.runWithClient(() async {
      await expectLater(api.post('/qa', {}), throwsA(isA<ApiException>()));
      expect(await api.post('/qa', {}), {'ok': true});
    }, () => MockClient((r) async => ++tentativas == 1
        ? http.Response('<html>proxy</html>', 200)
        : http.Response('{"ok":true}', 200)));
    expect(tentativas, 2);
  });

  test('escola bloqueada preserva sessão e notifica uma vez', () async {
    var bloqueios = 0;
    api.aoBloquearEscola = () => bloqueios++;
    await http.runWithClient(() async {
      for (var i = 0; i < 3; i++) {
        await expectLater(api.get('/qa/$i'), throwsA(isA<ApiException>()));
      }
      expect(bloqueios, 1);
      expect(api.token, 'sessao-qa');
    }, () => MockClient((r) async => http.Response(
      '{"error":"Peça a liberação","code":"escola_sem_acesso"}', 403)));
  });

  test('download usa permissão curta e preserva filtro', () async {
    await http.runWithClient(() async {
      final uri = await api.autorizarDownload('/professor/turmas/1/resumo-reuniao?etapa_id=2');
      expect(uri.queryParameters, {'etapa_id': '2', 'token': 'permissao-curta'});
      expect(uri.toString(), isNot(contains('sessao-qa')));
    }, () => MockClient((r) async {
      expect(r.headers['Authorization'], 'Bearer sessao-qa');
      expect(r.url.queryParameters['caminho'], '/professor/turmas/1/resumo-reuniao');
      return http.Response('{"token":"permissao-curta"}', 200);
    }));
  });

  for (final largura in [320.0, 1280.0]) {
    testWidgets('plano e validade ficam legíveis em ${largura.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(largura, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AcessoEscolaScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Situação: Teste gratuito'), findsOneWidget);
        expect(find.text('Validade: 29/10/2026'), findsOneWidget);
        expect(find.text('Verificar liberação'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => MockClient((r) async => http.Response(jsonEncode({
        'plano_nome': 'Mentorly Escolar', 'situacao_nome': 'Teste gratuito',
        'valido_ate': '2026-10-29', 'liberado': false, 'mensagem': 'Peça a liberação.'
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
    });
  }
}
