import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/admin/services/admin_service.dart';
import 'package:app_mentorly/features/admin/screens/admin_screen.dart';

Map<String, dynamic> painel() => {
      'escolas': [
        {
          'id': 1,
          'nome': '<script>Escola QA</script>',
          'email': 'escola@qa.test',
          'versao': 1,
          'plano_codigo': 'escolar',
          'plano_nome': 'Mentorly Escolar',
          'situacao': 'teste',
          'valido_ate': null,
          'acesso': {'situacao_nome': 'Teste gratuito', 'liberado': false}
        }
      ],
      'planos': [
        {'codigo': 'escolar', 'nome': 'Mentorly Escolar'}
      ],
      'situacoes': {
        'teste': 'Teste gratuito',
        'paga': 'Assinatura paga',
        'cortesia': 'Cortesia',
        'suspensa': 'Suspensa'
      },
      'historico': [],
    };
http.Response resposta(Map dados, [int status = 200]) =>
    http.Response(jsonEncode(dados), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('sessão separada usa CSRF e cookie sem enviar token da escola',
      () async {
    final servico = AdminService(cliente: MockClient((r) async {
      expect(r.headers.containsKey('Authorization'), isFalse);
      if (r.url.path.endsWith('/sessao')) {
        return http.Response(
            '{"csrf":"csrf-antes","usuario":null}', 200, headers: {
          'set-cookie': 'mentorly_admin=cookie-qa; HttpOnly; SameSite=Strict'
        });
      }
      expect(r.headers['X-CSRF-Token'], 'csrf-antes');
      expect(r.headers['Cookie'], 'mentorly_admin=cookie-qa');
      expect(jsonDecode(r.body)['senha'], 'a');
      return resposta({
        'csrf': 'csrf-novo',
        'usuario': {'id': 2, 'nome': 'Admin QA'}
      });
    }));
    await servico.entrar('admin@qa.test', 'a');
    expect(servico.usuario?['id'], 2);
    servico.dispose();
  });

  test('sessão expirada limpa identidade administrativa', () async {
    final servico = AdminService(
        cliente: MockClient((r) async => r.url.path.endsWith('/sessao')
            ? resposta({
                'csrf': 'teste',
                'usuario': {'id': 1, 'nome': 'Admin'}
              })
            : resposta({'error': 'Entre novamente.'}, 401)));
    await servico.consultarSessao();
    await expectLater(servico.listar(''), throwsA(isA<ApiException>()));
    expect(servico.usuario, isNull);
    servico.dispose();
  });

  test('resposta HTML não é tratada como dados de administração', () async {
    final servico = AdminService(
        cliente:
            MockClient((r) async => http.Response('<html>erro</html>', 200)));
    await expectLater(servico.consultarSessao(), throwsA(isA<ApiException>()));
    servico.dispose();
  });

  for (final largura in [320.0, 1280.0]) {
    testWidgets('login e liberação com texto literal em ${largura.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(largura, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var logins = 0, gravacoes = 0;
      final gravar = Completer<http.Response>();
      final servico = AdminService(cliente: MockClient((r) async {
        if (r.url.path.endsWith('/sessao'))
          return resposta({'csrf': 'qa', 'usuario': null});
        if (r.url.path.endsWith('/login')) {
          logins++;
          return resposta({
            'csrf': 'qa-novo',
            'usuario': {'id': 1, 'nome': 'Admin QA'}
          });
        }
        if (r.method == 'PUT') {
          gravacoes++;
          final corpo = jsonDecode(r.body);
          expect(corpo['situacao'], 'cortesia');
          expect(corpo['versao'], 1);
          expect(r.headers['X-CSRF-Token'], 'qa-novo');
          return gravar.future;
        }
        return resposta(painel());
      }));
      await tester.pumpWidget(MaterialApp(home: AdminScreen(servico: servico)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'admin@qa.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'a');
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(logins, 1);
      expect(find.text('<script>Escola QA</script>'), findsOneWidget);
      await tester.ensureVisible(find.text('Gerenciar acesso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gerenciar acesso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar acesso'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o motivo.'), findsOneWidget);
      expect(gravacoes, 0);
      await tester.enterText(
          find.byType(TextFormField).last, 'Demonstração autorizada');
      await tester.tap(find.text('Salvar acesso'));
      await tester.pumpAndSettle();
      expect(find.text('Escolha a validade do teste ou assinatura.'),
          findsOneWidget);
      await tester.tap(find.text('Teste gratuito').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cortesia').last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Salvar acesso'));
      }
      await tester.pump();
      expect(gravacoes, 1);
      gravar.complete(resposta({'mensagem': 'Acesso atualizado.'}));
      await tester.pumpAndSettle();
      expect(find.text('Acesso atualizado para a escola e seus professores.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
