import 'dart:convert';

import 'package:app_mentorly/app/theme.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/coordenacao/screens/turmas/relatorioTurmasScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().invalidarCache();
    ApiService().token = 'token-teste';
    ApiService().usuario = {'id': 1, 'tipo': 'coordenacao'};
  });

  testWidgets('relatório mostra turmas e total de atividades', (tester) async {
    Uri? requisicao;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: appTheme,
        home: const RelatorioTurmasScreen(),
      ));
      await tester.pumpAndSettle();

      expect(requisicao?.path, '/api/classes/relatorio/atividades');
      expect(find.text('Relatório de turmas'), findsOneWidget);
      expect(find.text('2 turmas · 5 atividades'), findsOneWidget);
      expect(find.text('7º A'), findsOneWidget);
      expect(find.text('2 atividades cadastradas'), findsOneWidget);
      expect(find.text('8º B'), findsOneWidget);
      expect(find.text('3 atividades cadastradas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requisicao = request.url;
              return http.Response(
                jsonEncode([
                  {'id': 1, 'turma': '7º A', 'total_atividades': 2},
                  {'id': 2, 'turma': '8º B', 'total_atividades': 3},
                ]),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }));
  });
}
