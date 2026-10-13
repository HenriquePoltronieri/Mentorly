import 'dart:convert';

import 'package:app_mentorly/app/routes.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/auth/screens/definirSenhaProfessorScreen.dart';
import 'package:app_mentorly/features/auth/screens/professorLoginScreen.dart';
import 'package:app_mentorly/features/auth/screens/tela_login.dart';
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

  for (final largura in [320.0, 768.0]) {
    testWidgets('cadastro inválido não bloqueia login em ${largura.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(largura, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var chamadas = 0;
      final cliente = MockClient((request) async {
        chamadas++;
        expect(request.url.path, '/api/auth/login-coordenacao');
        expect(jsonDecode(request.body), {
          'email': 'validacao@escola.invalid',
          'senha': 'validacao123',
        });
        return http.Response(jsonEncode({'error': 'Resposta de teste'}), 401);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
            home: TelaLogin(professor: false, cadastroInicial: true)));
        await tester.pumpAndSettle();
        final criar = find.widgetWithText(ElevatedButton, 'Criar conta');
        await tester.ensureVisible(criar);
        await tester.tap(criar);
        await tester.pumpAndSettle();
        expect(chamadas, 0);
        expect(find.text('Campo obrigatorio'), findsNWidgets(2));
        final voltar = find.widgetWithText(FilledButton, 'Já tenho conta');
        await tester.ensureVisible(voltar);
        await tester.tap(voltar);
        await tester.pumpAndSettle();
        final campos = find.byType(TextFormField);
        expect(campos, findsNWidgets(2));
        await tester.enterText(campos.at(0), 'validacao@escola.invalid');
        await tester.enterText(campos.at(1), 'validacao123');
        final entrar = find.widgetWithText(ElevatedButton, 'Entrar');
        await tester.ensureVisible(entrar);
        await tester.tap(entrar);
        await tester.pumpAndSettle();
        expect(chamadas, 1);
        expect(find.text('Resposta de teste'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => cliente);
    });
  }

  for (final primeiroAcesso in [false, true]) {
    final fluxo = primeiroAcesso ? 'convite' : 'login';
    for (final sucesso in [false, true]) {
      testWidgets('$fluxo preserva resposta de ${sucesso ? 'sucesso' : 'erro'}',
          (tester) async {
        var chamadas = 0;
        final cliente = MockClient((request) async {
          if (request.url.path == '/api/auth/consultar-convite') {
            expect(jsonDecode(request.body), {'token': 'convite-teste'});
            return http.Response(
                jsonEncode({'email': 'professor@escola.test'}), 200);
          }
          chamadas++;
          expect(request.method, 'POST');
          expect(
              request.url.path,
              primeiroAcesso
                  ? '/api/auth/criar-senha-professor'
                  : '/api/auth/login-professor');
          expect(jsonDecode(request.body), {
            if (!primeiroAcesso) 'email': 'professor@escola.test',
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
          await tester.pumpAndSettle();
          final campos = find.byType(TextFormField);
          if (primeiroAcesso) {
            expect(campos, findsNWidgets(2));
            expect(find.text('professor@escola.test'), findsOneWidget);
          }
          if (!primeiroAcesso) {
            await tester.enterText(campos.at(0), 'professor@escola.test');
          }
          await tester.enterText(campos.at(primeiroAcesso ? 0 : 1), 'senha123');
          if (primeiroAcesso) await tester.enterText(campos.at(1), 'senha123');
          await tester.ensureVisible(find.widgetWithText(ElevatedButton,
              primeiroAcesso ? 'Criar senha e entrar' : 'Entrar'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ElevatedButton,
              primeiroAcesso ? 'Criar senha e entrar' : 'Entrar'));
          await tester.pumpAndSettle();

          expect(chamadas, 1);
          expect(ApiService().estaLogado, sucesso);
          if (sucesso) {
            expect(find.text('Turmas'), findsOneWidget);
            final prefs = await SharedPreferences.getInstance();
            expect(prefs.getString('mentorly.token'), 'jwt-teste');
            expect(ApiService().tipoUsuario, 'professor');
          } else {
            expect(find.text('Credenciais invalidas'), findsOneWidget);
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
    expect(campos, findsNWidgets(2));
    await tester.enterText(campos.at(0), 'senha123');
    await tester.enterText(campos.at(1), 'senha123');
    await tester.ensureVisible(find.text('Criar senha e entrar'));
    await tester.tap(find.text('Criar senha e entrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Token inválido ou ausente.'), findsOneWidget);
    expect(ApiService().estaLogado, isFalse);
  });
}
