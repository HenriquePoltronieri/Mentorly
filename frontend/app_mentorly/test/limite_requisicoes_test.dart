import 'dart:convert';

import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/auth/screens/loginScreen.dart';
import 'package:app_mentorly/features/auth/screens/professorLoginScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// M-08: o 429 do limite de tentativas chega ao usuario como a mensagem do
// backend, sem texto tecnico, e nao e tratado como sessao invalida.

const _mensagem =
    'Muitas tentativas. Aguarde alguns minutos e tente novamente.';

http.Client _cliente429() => MockClient((req) async => http.Response(
      jsonEncode({'error': _mensagem}),
      429,
      headers: {'content-type': 'application/json', 'retry-after': '600'},
    ));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService().limparSessao();
  });

  testWidgets('login do professor: 429 mostra a mensagem amigavel',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ProfessorLoginScreen()));
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'professor@escola.test');
      await tester.enterText(campos.at(1), 'senha123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text(_mensagem), findsOneWidget);
      expect(find.textContaining('ApiException'), findsNothing);
      expect(ApiService().estaLogado, isFalse);
    }, _cliente429);
  });

  testWidgets('login da coordenacao: 429 mostra a mensagem amigavel',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'coord@escola.test');
      await tester.enterText(campos.at(1), 'senha123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text(_mensagem), findsOneWidget);
      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.text('Email ou senha incorretos'), findsNothing);
    }, _cliente429);
  });

  test(
      '429 em chamada autenticada mostra o erro da operacao e NAO encerra a sessao',
      () async {
    final api = ApiService();
    await api.salvarSessao('token-valido', {'id': 1, 'tipo': 'professor'});
    var acionado = false;
    api.aoEncerrarSessao = (_, __) => acionado = true;
    await http.runWithClient(() async {
      try {
        await api.post('/professor/turmas/1/insights', {});
        fail('deveria lancar');
      } on ApiException catch (e) {
        expect(e.statusCode, 429);
        expect(e.mensagem, _mensagem);
      }
    }, _cliente429);
    expect(api.estaLogado, isTrue);
    expect(acionado, isFalse);
    api.aoEncerrarSessao = null;
    await api.limparSessao();
  });
}
