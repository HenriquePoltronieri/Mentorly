import 'dart:async';
import 'dart:convert';

import 'package:app_mentorly/app/routes.dart';
import 'package:app_mentorly/app/sessaoInvalida.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/core/services/authService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// M-05: sessao invalida (401, ou 403 de professor desativado) em chamada
// autenticada limpa a sessao e leva ao login, uma unica vez e sem poder voltar.
// 403 comum (papel/permissao) e 401 de login com senha errada NAO mexem na
// sessao. Tudo com MockClient: nenhum servidor real.

class _Servidor {
  final List<http.Request> pedidos = [];
  int status = 200;
  Map<String, Object?> corpo = {'ok': true};
  Completer<void>? segurar; // segura a resposta ate o teste liberar

  http.Client cliente() => MockClient((req) async {
        pedidos.add(req);
        if (segurar != null) await segurar!.future;
        return http.Response(jsonEncode(corpo), status,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });

  void responder(int codigo, Map<String, Object?> json) {
    status = codigo;
    corpo = json;
  }

  String? autorizacaoDoUltimoPedido() => pedidos.last.headers['Authorization'];
}

class _Observador extends NavigatorObserver {
  final List<String?> empilhadas = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    empilhadas.add(route.settings.name);
  }
}

Widget _tela(String nome) => Scaffold(body: Center(child: Text('tela:$nome')));

Widget _app(_Observador observador, {String inicial = '/home'}) => MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorObservers: [observador],
      initialRoute: inicial,
      routes: {
        '/home': (_) => _tela('home'),
        '/home/detalhe': (_) => _tela('detalhe'),
        AppRoutes.login: (_) => _tela('login-coordenacao'),
        AppRoutes.professorLogin: (_) => _tela('login-professor'),
        AppRoutes.perfilSelection: (_) => _tela('perfil'),
      },
    );

const _msgExpirada = 'Sua sessão expirou. Entre novamente.';
const _msgDesativado =
    'Seu acesso foi desativado. Entre novamente ou procure a coordenação.';

/// Prepara sessao + tratamento global + app, roda o corpo dentro do cliente
/// falso e devolve quantas vezes o tratamento global foi acionado.
Future<void> _cenario(
  WidgetTester tester,
  _Servidor servidor,
  String tipo,
  Future<void> Function(ApiService api, _Observador obs,
          List<MotivoSessaoEncerrada> acionamentos)
      corpo,
) async {
  SharedPreferences.setMockInitialValues({});
  final api = ApiService();
  await api
      .salvarSessao('token-valido', {'id': 1, 'nome': 'Fulano', 'tipo': tipo});
  registrarTratamentoDeSessao(api);
  final original = api.aoEncerrarSessao!;
  final acionamentos = <MotivoSessaoEncerrada>[];
  api.aoEncerrarSessao = (motivo, tipoUsuario) {
    acionamentos.add(motivo);
    original(motivo, tipoUsuario);
  };
  final observador = _Observador();
  await http.runWithClient(() async {
    await tester.pumpWidget(_app(observador));
    await tester.pumpAndSettle();
    await corpo(api, observador, acionamentos);
  }, servidor.cliente);
  // nao vaza estado entre testes (o ApiService e um singleton)
  await api.limparSessao();
  api.aoEncerrarSessao = null;
}

Future<ApiException?> _chamar(ApiService api, String endpoint) async {
  try {
    await api.get(endpoint);
    return null;
  } on ApiException catch (e) {
    return e;
  }
}

void main() {
  group('401 em chamada autenticada', () {
    testWidgets('apaga o token e a sessao salva', (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        expect(api.estaLogado, isTrue);
        final erro = await _chamar(api, '/professor/turmas');
        await tester.pumpAndSettle();

        expect(erro!.statusCode, 401);
        expect(api.token, isNull);
        expect(api.usuario, isNull);
        expect(api.estaLogado, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('mentorly.token'), isNull);
        expect(prefs.getString('mentorly.usuario'), isNull);
        expect(acion, [MotivoSessaoEncerrada.expirada]);
      });
    });

    testWidgets('professor volta para o login do professor', (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        await _chamar(api, '/professor/turmas');
        await tester.pumpAndSettle();
        expect(find.text('tela:login-professor'), findsOneWidget);
        expect(find.text('tela:home'), findsNothing);
      });
    });

    testWidgets('coordenacao volta para o login da coordenacao',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'});
      await _cenario(tester, servidor, 'coordenacao', (api, obs, acion) async {
        await _chamar(api, '/classes');
        await tester.pumpAndSettle();
        expect(find.text('tela:login-coordenacao'), findsOneWidget);
      });
    });

    testWidgets('a pilha autenticada e removida: nao da para voltar',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        // usuario navegou ate uma tela mais funda
        navigatorKey.currentState!.pushNamed('/home/detalhe');
        await tester.pumpAndSettle();
        expect(navigatorKey.currentState!.canPop(), isTrue);

        await _chamar(api, '/professor/turmas');
        await tester.pumpAndSettle();

        expect(find.text('tela:login-professor'), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isFalse);
        expect(await navigatorKey.currentState!.maybePop(), isFalse);
        await tester.pumpAndSettle();
        expect(find.text('tela:login-professor'), findsOneWidget);
        expect(find.text('tela:detalhe'), findsNothing);
        expect(find.text('tela:home'), findsNothing);
      });
    });

    testWidgets('mostra a mensagem amigavel, sem texto tecnico',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        final erro = await _chamar(api, '/professor/turmas');
        await tester.pumpAndSettle();

        expect(find.text(_msgExpirada), findsOneWidget);
        expect(find.textContaining('Autenticacao necessaria'), findsNothing);
        expect(find.textContaining('ApiException'), findsNothing);
        // quem ainda mostrar o erro da chamada tambem recebe o texto amigavel
        expect(erro!.mensagem, _msgExpirada);
      });
    });

    testWidgets('varias chamadas simultaneas com 401: um unico tratamento',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'})
        ..segurar = Completer<void>();
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        final chamadas = [
          for (final rota in [
            '/professor/turmas',
            '/classes',
            '/activities',
            '/professor/dashboard',
            '/config/etapas'
          ])
            _chamar(api, rota),
        ];
        await tester.pump();
        expect(servidor.pedidos, hasLength(5));
        // as 5 sairam com o mesmo token
        expect(servidor.pedidos.map((p) => p.headers['Authorization']).toSet(),
            {'Bearer token-valido'});

        servidor.segurar!.complete();
        final erros = await Future.wait(chamadas);
        await tester.pumpAndSettle();

        expect(erros.every((e) => e != null && e.statusCode == 401), isTrue);
        expect(acion, hasLength(1),
            reason: 'tratamento global acionado uma vez');
        expect(obs.empilhadas.where((n) => n == AppRoutes.professorLogin),
            hasLength(1),
            reason: 'um unico redirect para o login');
        expect(find.text(_msgExpirada), findsOneWidget,
            reason: 'uma unica mensagem');
        expect(find.text('tela:login-professor'), findsOneWidget);
      });
    });

    testWidgets('nenhuma chamada nova usa o token removido', (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        await _chamar(api, '/professor/turmas');
        expect(servidor.autorizacaoDoUltimoPedido(), 'Bearer token-valido');
        await tester.pumpAndSettle();

        servidor.pedidos.clear();
        await _chamar(api, '/professor/turmas');
        expect(servidor.pedidos, hasLength(1));
        expect(servidor.autorizacaoDoUltimoPedido(), isNull,
            reason: 'sem cabecalho Authorization depois do logout');
        expect(acion, hasLength(1),
            reason: 'sem token, o 401 seguinte nao dispara nada');
      });
    });

    testWidgets(
        'resposta atrasada de uma sessao anterior nao derruba a sessao nova',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'})
        ..segurar = Completer<void>();
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        final pendente =
            _chamar(api, '/professor/turmas'); // sai com 'token-valido'
        await tester.pump();

        // enquanto isso: logout manual e novo login
        await api.limparSessao();
        await api.salvarSessao('token-novo', {'id': 2, 'tipo': 'professor'});

        servidor.segurar!.complete();
        await pendente;
        await tester.pumpAndSettle();

        expect(api.token, 'token-novo');
        expect(acion, isEmpty);
        expect(find.text('tela:home'), findsOneWidget);
      });
    });
  });

  group('403', () {
    testWidgets('403 comum (papel/permissao) NAO encerra a sessao',
        (tester) async {
      final servidor = _Servidor()
        ..responder(403, {'error': 'Esta acao e exclusiva da Coordenacao'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        final erro = await _chamar(api, '/config/anos-letivos');
        await tester.pumpAndSettle();

        expect(erro!.statusCode, 403);
        expect(erro.mensagem, 'Esta acao e exclusiva da Coordenacao');
        expect(api.token, 'token-valido');
        expect(api.estaLogado, isTrue);
        expect(acion, isEmpty);
        expect(find.text('tela:home'), findsOneWidget);
        expect(find.text(_msgExpirada), findsNothing);
      });
    });

    testWidgets('403 com outro codigo tambem mantem a sessao', (tester) async {
      final servidor = _Servidor()
        ..responder(403, {'error': 'Sem permissao', 'code': 'outra_coisa'});
      await _cenario(tester, servidor, 'coordenacao', (api, obs, acion) async {
        final erro = await _chamar(api, '/classes');
        await tester.pumpAndSettle();
        expect(erro!.codigo, 'outra_coisa');
        expect(api.estaLogado, isTrue);
        expect(acion, isEmpty);
      });
    });

    testWidgets(
        'professor desativado (403 + code) encerra a sessao com mensagem propria',
        (tester) async {
      final servidor = _Servidor()
        ..responder(403,
            {'error': 'Professor desativado', 'code': 'professor_desativado'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        final erro = await _chamar(api, '/professor/turmas');
        await tester.pumpAndSettle();

        expect(api.token, isNull);
        expect(acion, [MotivoSessaoEncerrada.professorDesativado]);
        expect(find.text('tela:login-professor'), findsOneWidget);
        expect(find.text(_msgDesativado), findsOneWidget);
        expect(find.textContaining('Professor desativado'), findsNothing);
        expect(erro!.mensagem, _msgDesativado);
        expect(navigatorKey.currentState!.canPop(), isFalse);
      });
    });

    testWidgets(
        '403 "Professor desativado" SEM o code nao e tratado como sessao invalida',
        (tester) async {
      // O app so confia no campo estruturado, nunca no texto da mensagem.
      final servidor = _Servidor()
        ..responder(403, {'error': 'Professor desativado'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        await _chamar(api, '/professor/turmas');
        await tester.pumpAndSettle();
        expect(api.estaLogado, isTrue);
        expect(acion, isEmpty);
      });
    });
  });

  group('autenticacao inicial e logout manual', () {
    testWidgets('login com senha errada (401) NAO aciona o tratamento global',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Email ou senha invalidos'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        // mesmo com um token antigo guardado, o 401 do login e resposta normal
        try {
          await api.post(
              '/auth/login-professor', {'email': 'a@b.cc', 'senha': 'errada'});
          fail('deveria lancar');
        } on ApiException catch (e) {
          expect(e.statusCode, 401);
          expect(e.mensagem, 'Email ou senha invalidos');
        }
        await tester.pumpAndSettle();

        expect(acion, isEmpty);
        expect(api.token, 'token-valido');
        expect(find.text('tela:home'), findsOneWidget);
        expect(find.text(_msgExpirada), findsNothing);
        expect(obs.empilhadas.where((n) => n == AppRoutes.professorLogin),
            isEmpty);
      });
    });

    testWidgets(
        'login com senha errada sem sessao anterior tambem nao redireciona',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Email ou senha invalidos'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        await api.limparSessao();
        final auth = AuthService();
        await expectLater(
          auth.loginProfessor(email: 'a@b.cc', senha: 'errada'),
          throwsA(isA<ApiException>().having(
              (e) => e.mensagem, 'mensagem', 'Email ou senha invalidos')),
        );
        await tester.pumpAndSettle();
        expect(acion, isEmpty);
        expect(find.text('tela:home'), findsOneWidget);
      });
    });

    testWidgets('401 sem token (ninguem logado) nao aciona o tratamento',
        (tester) async {
      final servidor = _Servidor()
        ..responder(401, {'error': 'Autenticacao necessaria'});
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        await api.limparSessao();
        final erro = await _chamar(api, '/classes');
        await tester.pumpAndSettle();
        expect(erro!.statusCode, 401);
        expect(erro.mensagem, 'Autenticacao necessaria');
        expect(acion, isEmpty);
      });
    });

    testWidgets('logout manual continua funcionando e nao dispara o tratamento',
        (tester) async {
      final servidor = _Servidor();
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        await AuthService().sair();
        await tester.pumpAndSettle();

        expect(api.token, isNull);
        expect(api.usuario, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('mentorly.token'), isNull);
        expect(acion, isEmpty);
        expect(find.text(_msgExpirada), findsNothing);
        expect(find.text('tela:home'), findsOneWidget);
      });
    });

    testWidgets(
        'respostas 2xx e erros comuns (400, 404, 409) seguem como antes',
        (tester) async {
      final servidor = _Servidor();
      await _cenario(tester, servidor, 'professor', (api, obs, acion) async {
        expect(await api.get('/classes'), {'ok': true});
        for (final status in [400, 404, 409, 422, 500, 503]) {
          servidor.responder(status, {'error': 'erro $status'});
          final erro = await _chamar(api, '/classes');
          expect(erro!.statusCode, status);
          expect(erro.mensagem, 'erro $status');
        }
        expect(api.estaLogado, isTrue);
        expect(acion, isEmpty);
      });
    });
  });
}
