import 'dart:convert';
import 'package:app_mentorly/app/routes.dart';
import 'package:app_mentorly/app/theme.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/coordenacao/controllers/configAnoLetivoController.dart';
import 'package:app_mentorly/features/coordenacao/screens/config/configEtapasScreen.dart';
import 'package:app_mentorly/features/coordenacao/screens/config/configNotasEtapaScreen.dart';
import 'package:app_mentorly/features/coordenacao/screens/config/configCriteriosScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _rolar(WidgetTester tester, Finder alvo) async {
  if (alvo.evaluate().isEmpty) {
    await tester.scrollUntilVisible(alvo, 100,
        scrollable: find.byType(Scrollable).first);
  } else {
    await tester.ensureVisible(alvo);
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiService()
        .salvarSessao('teste', {'tipo': 'coordenacao', 'nome': 'Escola'});
    ConfigAnoLetivoController().anoLetivo = 2026;
  });

  for (final quantidade in [1, 2, 3, 4, 5]) {
    testWidgets(
        'assistente salva $quantidade etapas, mantém rascunho e reabre em 320px',
        (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var salvo = <dynamic>[];
      var gravacoes = 0;
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          expect(
              request.url.path, '/api/config/anos-letivos/2026/configuracao');
          final corpo = jsonDecode(request.body) as Map;
          expect((corpo['etapas'] as List).length, quantidade);
          final criterios = corpo['criterios'] as List;
          expect(criterios.map((c) => c['peso']), [60.0, 40.0]);
          gravacoes++;
          salvo = (corpo['etapas'] as List)
              .asMap()
              .entries
              .map((e) => {
                    ...e.value as Map,
                    'id': e.key + 1,
                    'numero': e.key + 1,
                    'ano_letivo': 2026,
                    'criterios': criterios
                        .asMap()
                        .entries
                        .map((c) => {
                              ...c.value as Map,
                              'id': 100 + c.key,
                              'etapa_id': e.key + 1,
                            })
                        .toList(),
                  })
              .toList();
          return http.Response(jsonEncode(salvo), 200);
        }
        if (request.url.path == '/api/config/etapas') {
          return http.Response(jsonEncode(salvo), 200);
        }
        if (request.url.path == '/api/coordenacao/professores') {
          return http.Response('[{"id":1}]', 200);
        }
        throw StateError('Requisição inesperada: ${request.url}');
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
            theme: appTheme,
            home: const ConfigEtapasScreen(),
            routes: {
              AppRoutes.configNotasEtapa: (_) => const ConfigNotasEtapaScreen(),
              AppRoutes.configCriterios: (_) => const ConfigCriteriosScreen(),
              AppRoutes.coordenacaoHome: (_) =>
                  const Scaffold(body: Text('Painel salvo')),
            }));
        await tester.pumpAndSettle();
        if (quantidade <= 4) {
          await tester
              .tap(find.text('$quantidade Etapa${quantidade > 1 ? 's' : ''}'));
        } else {
          await tester.tap(find.text('Personalizado'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '$quantidade');
          await tester.tap(find.text('Usar'));
          await tester.pumpAndSettle();
        }
        await _rolar(tester, find.text('Salvar e continuar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvar e continuar'));
        await tester.pumpAndSettle();
        for (var i = 1; i <= quantidade; i++) {
          final campos = find.byType(TextField);
          await tester.enterText(campos.at(0), '6');
          await tester.enterText(campos.at(1), '10');
          final botao = find.text(i == quantidade
              ? 'Salvar e continuar'
              : 'Salvar e ir para a etapa ${i + 1}');
          await _rolar(tester, botao);
          await tester.pumpAndSettle();
          await tester.tap(botao);
          await tester.pumpAndSettle();
        }
        expect(gravacoes, 0);
        await tester.tap(find.text('Provas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trabalhos'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('peso_Trabalhos')), 80,
            scrollable: find
                .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable))
                .first);
        final campos = find.byType(TextField);
        expect((tester.widget<TextField>(campos.at(0))).controller!.text, '50');
        expect((tester.widget<TextField>(campos.at(1))).controller!.text, '50');
        await tester.enterText(campos.at(0), '60');
        await tester.pump();
        expect(
            (tester.widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Concluir configuração')))
                .onPressed,
            isNull);
        await tester.enterText(campos.at(1), '40');
        // Volta pelo AppBar e avança de novo: mantém pesos e notas digitados.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
            (tester.widget<TextField>(find.byType(TextField).at(0)))
                .controller!
                .text,
            '6');
        await _rolar(tester, find.text('Salvar e continuar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvar e continuar'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('peso_Trabalhos')), 80,
            scrollable: find
                .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable))
                .first);
        expect(
            (tester.widget<TextField>(find.byType(TextField).at(0)))
                .controller!
                .text,
            '60');
        expect(
            (tester.widget<TextField>(find.byType(TextField).at(1)))
                .controller!
                .text,
            '40');
        await tester.scrollUntilVisible(find.text('Concluir configuração'), 80,
            scrollable: find
                .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable))
                .first);
        await tester.tap(find.text('Concluir configuração'));
        await tester.pumpAndSettle();
        expect(find.text('Painel salvo'), findsOneWidget);
        expect(gravacoes, 1);
        await ConfigAnoLetivoController().carregarConfiguracaoExistente();
        expect(ConfigAnoLetivoController().etapas.length, quantidade);
        expect(ConfigAnoLetivoController().criterios.first.peso, 60);
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }

  testWidgets('erro legível do servidor no concluir, sem perder pesos',
      (tester) async {
    final controller = ConfigAnoLetivoController();
    await controller.definirQuantidadeEtapas(1);
    await controller.salvarNotasEtapa(1, 6, 10);
    controller.criterios = [];
    controller.criteriosSelecionados = null;
    controller.rascunhosPesos.clear();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: const ConfigCriteriosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Provas'));
      await tester.pumpAndSettle();
      await _rolar(tester, find.text('Concluir configuração'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluir configuração'));
      await tester.pumpAndSettle();
      expect(find.text('A etapa está fechada.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
        () => MockClient((r) async => r.method == 'PUT'
            ? http.Response('{"error":"A etapa está fechada."}', 400)
            : http.Response('[]', 200)));
  });
}
