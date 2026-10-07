import 'dart:async';

import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/professor/models/sugestaoAtividadeModel.dart';
import 'package:app_mentorly/features/professor/screens/atividades/gerarAtividadeIaDialog.dart';
import 'package:app_mentorly/features/professor/services/geracaoAtividadeIaService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _resposta() => {
      'contexto': {'turma': '9º A', 'anoLetivo': 2026},
      'geradoPorIA': true,
      'modelo': 'modelo-teste',
      'sugestao': {
        'titulo': 'Revolução Industrial',
        'descricao': 'Leia e responda.',
        'objetivo': 'Compreender causas.',
        'questoes': [
          {
            'tipo': 'objetiva',
            'enunciado': 'Qual país iniciou a Revolução Industrial?',
            'alternativas': ['França', 'Inglaterra', 'Brasil', 'Japão'],
            'respostaEsperada': 'B',
            'explicacao': 'Começou na Inglaterra.',
          },
          {
            'tipo': 'discursiva',
            'enunciado': 'Cite dois impactos sociais.',
            'alternativas': [],
            'respostaEsperada': 'Urbanização e trabalho fabril.',
            'explicacao': '',
          },
        ],
        'rubricaSugerida': [
          {'criterio': 'Compreensão', 'descricao': 'Entende o tema', 'peso': 60},
        ],
      },
    };

class _ServicoFalso extends GeracaoAtividadeIaService {
  int chamadas = 0;
  Map<String, Object?>? ultimo;
  Completer<SugestaoAtividadeModel>? espera;
  Object? erro;

  @override
  Future<SugestaoAtividadeModel> gerar({
    required String turmaId,
    required String tema,
    String objetivo = '',
    String observacoes = '',
    String dificuldade = 'media',
    int quantidadeQuestoes = 5,
    String tipo = 'mista',
    int? etapaId,
    int? criterioId,
  }) {
    chamadas++;
    ultimo = {
      'turmaId': turmaId,
      'tema': tema,
      'quantidade': quantidadeQuestoes,
      'tipo': tipo,
      'etapaId': etapaId,
      'criterioId': criterioId,
    };
    if (erro != null) return Future.error(erro!);
    return espera?.future ??
        Future.value(SugestaoAtividadeModel.fromJson(_resposta()));
  }
}

void _telaGrande(WidgetTester tester) {
  // O dialogo e mais alto que a tela padrao de teste (800x600).
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _abrir(WidgetTester tester, _ServicoFalso servico) async {
  _telaGrande(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<SugestaoAtividadeModel>(
                context: context,
                builder: (_) => GerarAtividadeIaDialog(
                  turmaId: '10',
                  etapaId: 4,
                  criterioId: 7,
                  service: servico,
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('SugestaoAtividadeModel', () {
    test('converte a resposta estruturada da IA', () {
      final model = SugestaoAtividadeModel.fromJson(_resposta());
      expect(model.titulo, 'Revolução Industrial');
      expect(model.questoes, hasLength(2));
      expect(model.questoes.first.objetiva, isTrue);
      expect(model.questoes.first.alternativas[1], 'Inglaterra');
      expect(model.questoes.last.alternativas, isEmpty);
      expect(model.rubrica.single.peso, 60);
      expect(model.modelo, 'modelo-teste');
    });

    test('tolera campos ausentes sem quebrar', () {
      final model = SugestaoAtividadeModel.fromJson({
        'sugestao': {'titulo': 'Só título'},
      });
      expect(model.questoes, isEmpty);
      expect(model.rubrica, isEmpty);
      expect(model.descricaoFormatada(), '');
    });

    test('descricao formatada inclui questoes, alternativas e gabarito', () {
      final texto =
          SugestaoAtividadeModel.fromJson(_resposta()).descricaoFormatada();
      expect(texto, contains('Objetivo: Compreender causas.'));
      expect(texto, contains('1. Qual país iniciou a Revolução Industrial?'));
      expect(texto, contains('   B) Inglaterra'));
      expect(texto, contains('   Gabarito: B'));
      expect(texto, contains('2. Cite dois impactos sociais.'));
      expect(texto, isNot(contains('Rubrica sugerida')));
    });

    test('rubrica so entra quando o Professor escolhe incluir', () {
      final model = SugestaoAtividadeModel.fromJson(_resposta());
      expect(model.descricaoFormatada(incluirRubrica: true),
          contains('- Compreensão (60%) — Entende o tema'));
    });
  });

  group('GerarAtividadeIaDialog', () {
    testWidgets('exige tema e nao chama a IA sem ele', (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico);

      await tester.tap(find.text('Gerar sugestão'));
      await tester.pump();

      expect(find.text('Informe o tema da atividade'), findsOneWidget);
      expect(servico.chamadas, 0);
    });

    testWidgets('duplo toque gera um unico pedido e desabilita o botao',
        (tester) async {
      final servico = _ServicoFalso()..espera = Completer();
      await _abrir(tester, servico);

      await tester.enterText(find.byType(TextField).first, 'Revolução Industrial');
      await tester.tap(find.text('Gerar sugestão'));
      await tester.pump();
      expect(find.text('Gerando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Gerando...'), warnIfMissed: false);
      await tester.pump();
      expect(servico.chamadas, 1);
      expect(servico.ultimo!['etapaId'], 4);
      expect(servico.ultimo!['criterioId'], 7);

      servico.espera!.complete(SugestaoAtividadeModel.fromJson(_resposta()));
      await tester.pumpAndSettle();
      expect(find.text('Revisar sugestão'), findsOneWidget);
      expect(servico.chamadas, 1);
    });

    testWidgets('mostra aviso de IA e permite editar, remover e confirmar',
        (tester) async {
      final servico = _ServicoFalso();
      _telaGrande(tester);
      SugestaoAtividadeModel? devolvido;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  devolvido = await showDialog<SugestaoAtividadeModel>(
                    context: context,
                    builder: (_) => GerarAtividadeIaDialog(
                      turmaId: '10',
                      service: servico,
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Revolução Industrial');
      await tester.tap(find.text('Gerar sugestão'));
      await tester.pumpAndSettle();

      expect(find.text('Conteúdo gerado por IA. Revise antes de salvar.'),
          findsOneWidget);
      expect(find.text('Questões (2)'), findsOneWidget);

      // edita o titulo
      final titulo = find.widgetWithText(TextField, 'Título');
      await tester.enterText(titulo, 'Título revisado');
      // remove a segunda questao
      await tester.scrollUntilVisible(
        find.text('Questão 2 · Discursiva'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Remover questão').last);
      await tester.pumpAndSettle();
      expect(find.text('Questões (1)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Usar na atividade'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Usar na atividade'));
      await tester.pumpAndSettle();

      expect(devolvido, isNotNull);
      expect(devolvido!.titulo, 'Título revisado');
      expect(devolvido!.questoes, hasLength(1));
      expect(devolvido!.rubrica, isEmpty); // nao marcou incluir rubrica
    });

    testWidgets('cancelar descarta a sugestao', (tester) async {
      final servico = _ServicoFalso();
      _telaGrande(tester);
      SugestaoAtividadeModel? devolvido = SugestaoAtividadeModel(titulo: 'x');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  devolvido = await showDialog<SugestaoAtividadeModel>(
                    context: context,
                    builder: (_) =>
                        GerarAtividadeIaDialog(turmaId: '10', service: servico),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(devolvido, isNull);
      expect(servico.chamadas, 0);
    });

    testWidgets('erro da API aparece como mensagem e permite tentar de novo',
        (tester) async {
      final servico = _ServicoFalso()
        ..erro = ApiException(503, 'Não foi possível gerar a atividade agora.');
      await _abrir(tester, servico);

      await tester.enterText(find.byType(TextField).first, 'Fracoes');
      await tester.tap(find.text('Gerar sugestão'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível gerar a atividade agora.'),
          findsOneWidget);
      expect(find.text('Gerar sugestão'), findsOneWidget); // botao volta
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
