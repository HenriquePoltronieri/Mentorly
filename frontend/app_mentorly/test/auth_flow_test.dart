import 'dart:convert';

import 'package:app_mentorly/app/routes.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/core/utils/telefone_formatter.dart';
import 'package:app_mentorly/core/utils/validators.dart';
import 'package:app_mentorly/features/auth/screens/definirSenhaProfessorScreen.dart';
import 'package:app_mentorly/features/auth/screens/professorLoginScreen.dart';
import 'package:app_mentorly/features/auth/screens/tela_login.dart';
import 'package:app_mentorly/features/auth/screens/twoFactorScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final documentos = {
    'documentos': {
      'uso': {'titulo': 'Termo de Uso', 'texto': 'Texto de uso', 'sha256': 'hash-uso'},
      'consentimento': {'titulo': 'Termo de Consentimento', 'texto': 'Texto de consentimento', 'sha256': 'hash-consentimento'},
    }
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().limparSessao();
  });

  test('email, telefone e máscara validam o cadastro', () {
    expect(Validators.validarEmail('coord@escola.com'), isNull);
    for (final email in [
      'coord',
      '.coord@escola.com',
      'co ord@escola.com',
      'coord@-escola.com'
    ]) {
      expect(Validators.validarEmail(email), isNotNull);
    }
    expect(Validators.validarTelefone('(11) 98765-4321'), isNull);
    expect(Validators.validarTelefone('(11) 1234'), isNotNull);
    expect(
        TelefoneBrasileiroFormatter.formatar('11987654321'), '(11) 98765-4321');
  });

  testWidgets('cadastro só cria conta depois do código enviado por email',
      (tester) async {
    final caminhos = <String>[];
    final cliente = MockClient((request) async {
      if (request.url.path == '/api/termos/atuais') {
        return http.Response(jsonEncode(documentos), 200);
      }
      caminhos.add(request.url.path);
      final corpo = request.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      if (request.url.path == '/api/auth/enviar-codigo') {
        expect(corpo, {'email': 'coord@escola.com'});
        return http.Response(jsonEncode({'enviado': true}), 200);
      }
      if (request.url.path == '/api/auth/cadastro-coordenacao') {
        expect(corpo['telefone'], '11987654321');
        expect(corpo['codigoVerificacao'], '123456');
        expect(corpo['termos'], {
          'decisoes': {'uso': true, 'consentimento': false},
          'versoes': {'uso': 'hash-uso', 'consentimento': 'hash-consentimento'}
        });
        return http.Response(
            jsonEncode({
              'token': 'jwt-coordenacao',
              'usuario': {
                'id': 1,
                'nome': 'Escola Teste',
                'email': 'coord@escola.com',
                'tipo': 'coordenacao'
              }
            }),
            201);
      }
      if (request.url.path == '/api/acesso') {
        return http.Response(jsonEncode({'liberado': true}), 200);
      }
      return http.Response(jsonEncode({'error': 'Rota inesperada'}), 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: const TelaLogin(professor: false, cadastroInicial: true),
        routes: {
          AppRoutes.twoFactor: (_) => const TwoFactorScreen(),
          AppRoutes.coordenacaoHome: (_) =>
              const Scaffold(body: Text('Coordenação verificada')),
          AppRoutes.acesso: (_) => const Scaffold(body: Text('Acesso')),
        },
      ));
      await tester.pumpAndSettle();
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Escola Teste');
      await tester.enterText(campos.at(1), 'coord@escola.com');
      await tester.enterText(campos.at(2), 'senha123');
      await tester.enterText(campos.at(3), 'senha123');
      await tester.enterText(campos.at(4), '11987654321');
      expect(find.text('(11) 98765-4321'), findsOneWidget);
      await tester.ensureVisible(find.text('Aceito o Termo de Uso'));
      await tester.tap(find.text('Aceito o Termo de Uso'));
      await tester.ensureVisible(find.text('Não dou meu consentimento'));
      await tester.tap(find.text('Não dou meu consentimento'));
      final criar = find.widgetWithText(ElevatedButton, 'Criar conta');
      await tester.ensureVisible(criar);
      await tester.tap(criar);
      await tester.pumpAndSettle();
      expect(caminhos, ['/api/auth/enviar-codigo']);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(caminhos, [
        '/api/auth/enviar-codigo',
        '/api/auth/cadastro-coordenacao',
        '/api/acesso'
      ]);
      expect(find.text('Coordenação verificada'), findsOneWidget);
    }, () => cliente);
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
        if (request.url.path == '/api/termos/atuais') {
          return http.Response(jsonEncode(documentos), 200);
        }
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
        expect(find.text('Campo obrigatorio'), findsOneWidget);
        expect(find.text('Digite o telefone'), findsOneWidget);
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
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var chamadas = 0;
        final cliente = MockClient((request) async {
          if (request.url.path == '/api/termos/atuais') {
            return http.Response(jsonEncode(documentos), 200);
          }
          if (request.url.path == '/api/acesso') {
            return http.Response(jsonEncode({'liberado': true}), 200);
          }
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
            if (primeiroAcesso) 'termos': {
              'decisoes': {'uso': true, 'consentimento': true},
              'versoes': {'uso': 'hash-uso', 'consentimento': 'hash-consentimento'}
            },
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
              AppRoutes.dashboard: (_) =>
                  const Scaffold(body: Text('Início do professor')),
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
          if (primeiroAcesso) {
            await tester.ensureVisible(find.text('Aceito o Termo de Uso'));
            await tester.tap(find.text('Aceito o Termo de Uso'));
            await tester.ensureVisible(find.text('Dou meu consentimento'));
            await tester.tap(find.text('Dou meu consentimento'));
          }
          await tester.ensureVisible(find.widgetWithText(ElevatedButton,
              primeiroAcesso ? 'Criar senha e entrar' : 'Entrar'));
          await tester.pumpAndSettle();
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ElevatedButton,
              primeiroAcesso ? 'Criar senha e entrar' : 'Entrar'));
          await tester.pumpAndSettle();

          expect(chamadas, 1);
          expect(ApiService().estaLogado, sucesso);
          if (sucesso) {
            expect(find.text('Início do professor'), findsOneWidget);
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
