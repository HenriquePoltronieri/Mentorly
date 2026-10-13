import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_mentorly/app/routes.dart';
import 'package:app_mentorly/app/theme.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/professor/screens/chat_ia_screen.dart';
import 'package:app_mentorly/features/professor/screens/turmas/turmaAlunosScreen.dart';
import 'package:app_mentorly/features/professor/widgets/estatisticas_view.dart';

http.Response resposta(Object dados) => http.Response(jsonEncode(dados), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

final aluno = {
  'id': 3,
  'nome': 'Mariana',
  'turma': '7A',
  'turma_id': 7,
  'media': 5,
  'risco': 'Em andamento',
  'pontos_obtidos': 1,
  'pontos_avaliados': 2,
  'entregues': 1,
  'pendentes': 0,
  'maior_nota': 5,
  'menor_nota': 5,
  'etapas': [],
  'acompanhamento': {'etapa': 'Etapa 1'},
  'atividades': [
    {
      'id': 8,
      'titulo': 'Trabalho de frações',
      'nota': 1,
      'nota_maxima': 2,
      'nota_normalizada': 5,
      'media_turma': 8,
      'status': 'Entregue',
      'data': '2026-08-02'
    }
  ],
};

void main() {
  setUp(() {
    ApiService().invalidarCache();
    ApiService().token =
        'acompanhamento-${DateTime.now().microsecondsSinceEpoch}';
    ApiService().usuario = {'id': 1, 'tipo': 'professor'};
  });

  testWidgets('lista mostra 1 de 2 pontos sem alertar em largura móvel',
      (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await http.runWithClient(() async {
      await t.pumpWidget(MaterialApp(
          theme: appTheme,
          onGenerateRoute: (_) => MaterialPageRoute(
              settings: const RouteSettings(arguments: {'id': 7, 'nome': '7A'}),
              builder: (_) => const TurmaAlunosScreen())));
      await t.pumpAndSettle();
      expect(find.text('1,0/2,0 pts'), findsOneWidget);
      expect(find.text('Em andamento · Etapa 1'), findsOneWidget);
      expect(find.text('5.0'), findsNothing);
      expect(find.textContaining('Alto'), findsNothing);
      expect(t.takeException(), isNull);
    },
        () => MockClient((r) async => r.url.path.endsWith('/estatisticas')
            ? resposta({
                'alunos': [aluno]
              })
            : resposta([aluno])));
  });

  testWidgets(
      'detalhe abre chat individual com pergunta pronta e envia o aluno',
      (t) async {
    Map<String, dynamic>? pedido;
    await http.runWithClient(() async {
      await t.pumpWidget(MaterialApp(
          theme: appTheme,
          home: const Scaffold(body: EstatisticasView(turmaId: 7, alunoId: 3)),
          routes: {AppRoutes.chatIa: (_) => const ChatIaScreen()}));
      await t.pumpAndSettle();
      await t.tap(find.text('Como ajudar este aluno?'));
      await t.pumpAndSettle();
      expect(find.text('IA · Mariana'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
          contains('Como posso ajudar Mariana a melhorar as notas'));
      await t.tap(find.byTooltip('Enviar mensagem'));
      await t.pumpAndSettle();
      expect(pedido?['turma_id'], 7);
      expect(pedido?['aluno_id'], 3);
      expect(pedido?['historico'], isEmpty);
      expect(find.text('Revise o trabalho de frações com Mariana.'),
          findsOneWidget);
      expect(t.takeException(), isNull);
    },
        () => MockClient((r) async {
              if (r.method == 'POST') {
                pedido = jsonDecode(r.body) as Map<String, dynamic>;
                return resposta({
                  'resposta': 'Revise o trabalho de frações com Mariana.',
                  'atalhos': []
                });
              }
              return resposta(aluno);
            }));
  });
}
