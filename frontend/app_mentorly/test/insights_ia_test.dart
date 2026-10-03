import 'package:app_mentorly/features/professor/models/insightsTurmaModel.dart';
import 'package:app_mentorly/features/professor/screens/turmas/insightsTurmaScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('model converte resposta estruturada de insights', () {
    final model = InsightsTurmaModel.fromJson({
      'contexto': {'turma': '9º A', 'anoLetivo': 2026, 'etapa': '2º bimestre'},
      'modelo': 'modelo-teste',
      'insights': {
        'resumo': 'Resumo baseado nos registros.',
        'pontosPositivos': ['Provas em 82%.'],
        'pontosAtencao': [
          {
            'titulo': 'Critério com menor resultado',
            'evidencia': 'Trabalhos em 54%.',
            'sugestao': 'Revisar as atividades do critério.',
          },
        ],
        'sugestoesGerais': ['Acompanhar os próximos registros.'],
      },
    });

    expect(model.turma, '9º A');
    expect(model.anoLetivo, 2026);
    expect(model.pontosAtencao.single.evidencia, 'Trabalhos em 54%.');
    expect(model.sugestoesGerais, hasLength(1));
  });

  test('model tolera listas opcionais ausentes', () {
    final model = InsightsTurmaModel.fromJson({
      'contexto': {'turma': '8º A'},
      'insights': {'resumo': 'Sem listas.'},
    });
    expect(model.pontosPositivos, isEmpty);
    expect(model.pontosAtencao, isEmpty);
    expect(model.sugestoesGerais, isEmpty);
  });

  testWidgets('tela aguarda clique e explica papel de apoio da IA',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InsightsTurmaScreen(
          turmaInicial: {'id': 1, 'nome': '9º A', 'anoLetivo': 2026},
        ),
      ),
    );

    expect(find.text('Gerar insights'), findsOneWidget);
    expect(find.textContaining('apoio pedagógico'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
