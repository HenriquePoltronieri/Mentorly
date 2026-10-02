import 'dart:convert';

import 'package:app_mentorly/app/routes.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/auth/screens/definirSenhaProfessorScreen.dart';
import 'package:app_mentorly/features/auth/screens/professorLoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().limparSessao();
  });

  for (final primeiroAcesso in [false, true]) {
    final fluxo = primeiroAcesso ? 'convite' : 'login';
    for (final sucesso in [false, true]) {
      testWidgets('$fluxo preserva resposta de ${sucesso ? 'sucesso' : 'erro'}',
          (tester) async {
        var chamadas = 0;
        final cliente = MockClient((request) async {
          chamadas++;
          expect(request.method, 'POST');
          expect(
              request.url.path,
              primeiroAcesso
                  ? '/api/auth/criar-senha-professor'
                  : '/api/auth/login-professor');
          expect(jsonDecode(request.body), {
            'email': 'professor@escola.test',
            'senha': 'senha123',
            if (primeiroAcesso) 'token': 'convite-teste',
          });
          return http.Response(
              jsonEncode(sucesso
                  ? {
                      'token': 'jwt-teste',
                      'usuario': {
                        'id': 1,
                        'nome': 'Professor',
                        'email': 'professor@escola.test',
                        'tipo': 'professor',
                      },
                    }
                  : {'error': 'Credenciais invalidas'}),
              sucesso ? 200 : 401);
        });

        await http.runWithClient(() async {
          await tester.pumpWidget(MaterialApp(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings:
                  const RouteSettings(arguments: {'token': 'convite-teste'}),
              builder: (_) => primeiroAcesso
                  ? const DefinirSenhaProfessorScreen()
                  : const ProfessorLoginScreen(),
            ),
            routes: {
              AppRoutes.listaTurmas: (_) =>
                  const Scaffold(body: Text('Turmas')),
            },
          ));
          final campos = find.byType(TextFormField);
          await tester.enterText(campos.at(0), 'professor@escola.test');
          await tester.enterText(campos.at(1), 'senha123');
          if (primeiroAcesso) {
            await tester.enterText(campos.at(2), 'senha123');
          }
          await tester.tap(
              find.text(primeiroAcesso ? 'Definir senha e entrar' : 'Entrar'));
          await tester.pumpAndSettle();

          expect(chamadas, 1);
          expect(ApiService().estaLogado, sucesso);
          if (sucesso) {
            expect(find.text('Turmas'), findsOneWidget);
            final prefs = await SharedPreferences.getInstance();
            expect(prefs.getString('mentorly.token'), 'jwt-teste');
            expect(ApiService().tipoUsuario, 'professor');
          } else {
            expect(find.text('ApiException(401): Credenciais invalidas'),
                findsOneWidget);
            expect(find.text('Turmas'), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsNothing);
          }
        }, () => cliente);
      });
    }
  }

  testWidgets('convite exige token antes de enviar a senha', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: DefinirSenhaProfessorScreen()));
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'professor@escola.test');
    await tester.enterText(campos.at(1), 'senha123');
    await tester.enterText(campos.at(2), 'senha123');
    await tester.tap(find.text('Definir senha e entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Token inválido ou ausente. Acesse pelo link do e-mail.'),
        findsOneWidget);
    expect(ApiService().estaLogado, isFalse);
  });
}
