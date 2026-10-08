import 'dart:async';

import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/professor/models/correcaoSugeridaModel.dart';
import 'package:app_mentorly/features/professor/screens/atividades/corrigirRespostaIaDialog.dart';
import 'package:app_mentorly/features/professor/services/correcaoAssistidaIaService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _resposta() => {
      'contexto': {'atividade': 'Prova 1', 'valorMaximo': 2.0},
      'geradoPorIA': true,
      'modelo': 'modelo-teste',
      'sugestao': {
        'notaSugerida': 1.5,
        'percentual': 75.0,
        'valorMaximo': 2.0,
        'avaliacao': [
          {
            'criterio': 'Compreensão do conceito',
            'resultado': 'atendido_parcialmente',
            'evidencia': 'O aluno escreve "aumentou a produção".',
            'faltou': 'Não cita as máquinas.',
          },
        ],
        'pontosPositivos': ['Cita o aumento da produção.'],
        'pontosMelhorar': ['Explicar o papel das máquinas.'],
        'justificativa': 'Atende parte do esperado.',
        'feedbackAluno': 'Bom começo; explique o papel das máquinas.',
      },
    };

class _ServicoFalso extends CorrecaoAssistidaIaService {
  int chamadas = 0;
  Map<String, Object?>? ultimo;
  Completer<CorrecaoSugeridaModel>? espera;
  Object? erro;

  @override
  Future<CorrecaoSugeridaModel> corrigir({
    required String atividadeId,
    required String questao,
    required String respostaEsperada,
    required String respostaAluno,
    required double valorMaximo,
    List<Map<String, dynamic>> rubrica = const [],
  }) {
    chamadas++;
    ultimo = {
      'atividadeId': atividadeId,
      'questao': questao,
      'respostaEsperada': respostaEsperada,
      'respostaAluno': respostaAluno,
      'valorMaximo': valorMaximo,
      'rubrica': rubrica,
    };
    if (erro != null) return Future.error(erro!);
    return espera?.future ??
        Future.value(CorrecaoSugeridaModel.fromJson(_resposta()));
  }
}

class _Resultado {
  double? nota;
  bool fechou = false;
}

Future<_Resultado> _abrir(WidgetTester tester, _ServicoFalso servico,
    {double valorMaximo = 10}) async {
  // O dialogo e mais alto que a tela padrao de teste (800x600).
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final resultado = _Resultado();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                resultado.nota = await showDialog<double>(
                  context: context,
                  builder: (_) => CorrigirRespostaIaDialog(
                    atividadeId: '5',
                    valorMaximoAtividade: valorMaximo,
                    alunoNome: 'Ana Souza',
                    service: servico,
                  ),
                );
                resultado.fechou = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultado;
}

Future<void> _preencher(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'Questão'), 'Explique a Revolução.');
  await tester.enterText(find.widgetWithText(TextField, 'Resposta esperada'), 'Mecanização.');
  await tester.enterText(find.widgetWithText(TextField, 'Resposta do aluno'),
      'A industrialização aumentou a produção.');
}

void main() {
  group('CorrecaoSugeridaModel', () {
    test('converte a resposta estruturada', () {
      final model = CorrecaoSugeridaModel.fromJson(_resposta());
      expect(model.notaSugerida, 1.5);
      expect(model.percentual, 75);
      expect(model.valorMaximo, 2);
      expect(model.avaliacao.single.rotuloResultado, 'Parcialmente atendido');
      expect(model.avaliacao.single.evidencia, contains('aumentou a produção'));
      expect(model.pontosMelhorar, hasLength(1));
      expect(model.modelo, 'modelo-teste');
    });

    test('rotulos dos tres resultados', () {
      String rotulo(String r) =>
          AvaliacaoCriterioIa(criterio: 'c', resultado: r).rotuloResultado;
      expect(rotulo('atendido'), 'Atendido');
      expect(rotulo('atendido_parcialmente'), 'Parcialmente atendido');
      expect(rotulo('nao_atendido'), 'Não atendido');
    });

    test('tolera campos ausentes sem quebrar', () {
      final model = CorrecaoSugeridaModel.fromJson({'sugestao': {}});
      expect(model.notaSugerida, 0);
      expect(model.avaliacao, isEmpty);
      expect(model.feedbackAluno, '');
    });
  });

  group('CorrigirRespostaIaDialog', () {
    testWidgets('mostra aviso, nao revela o aluno a IA e exige os campos',
        (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico);

      expect(find.text('Aluno: Ana Souza'), findsOneWidget);
      expect(find.textContaining('não é enviado à IA'), findsOneWidget);
      expect(find.textContaining('apenas uma sugestão'), findsOneWidget);

      await tester.tap(find.text('Analisar resposta'));
      await tester.pump();
      expect(find.text('Cole a questão'), findsOneWidget);
      expect(servico.chamadas, 0);
    });

    testWidgets('valor maximo acima da atividade e recusado sem chamar a IA',
        (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico, valorMaximo: 2);
      await _preencher(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Valor máximo desta resposta'), '5');
      await tester.tap(find.text('Analisar resposta'));
      await tester.pump();

      expect(find.textContaining('não pode passar do valor da atividade'),
          findsOneWidget);
      expect(servico.chamadas, 0);
    });

    testWidgets('duplo toque gera um unico pedido e desabilita o botao',
        (tester) async {
      final servico = _ServicoFalso()..espera = Completer();
      await _abrir(tester, servico);
      await _preencher(tester);

      await tester.tap(find.text('Analisar resposta'));
      await tester.pump();
      expect(find.text('Analisando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Analisando...'), warnIfMissed: false);
      await tester.pump();
      expect(servico.chamadas, 1);

      servico.espera!.complete(CorrecaoSugeridaModel.fromJson(_resposta()));
      await tester.pumpAndSettle();
      expect(find.text('Sugestão da IA'), findsOneWidget);
      expect(servico.chamadas, 1);
    });

    testWidgets('envia texto e rubrica ao servico, sem dado do aluno',
        (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico);
      await _preencher(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Valor máximo desta resposta'), '2,5');
      await tester.enterText(find.widgetWithText(TextField, 'Rubrica (opcional)'),
          'Compreensão do conceito: 60\nClareza');
      await tester.tap(find.text('Analisar resposta'));
      await tester.pumpAndSettle();

      expect(servico.ultimo!['atividadeId'], '5');
      expect(servico.ultimo!['valorMaximo'], 2.5);
      expect(servico.ultimo!['rubrica'], [
        {'item': 'Compreensão do conceito', 'peso': 60.0},
        {'item': 'Clareza'},
      ]);
      expect(servico.ultimo!.toString().contains('Ana'), isFalse);
    });

    testWidgets('resultado mostra nota, percentual, evidencia e feedback',
        (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico);
      await _preencher(tester);
      await tester.tap(find.text('Analisar resposta'));
      await tester.pumpAndSettle();

      expect(find.text('Sugestão da IA'), findsOneWidget);
      expect(find.text('1,5 de 2  ·  75%'), findsOneWidget);
      expect(find.textContaining('apenas uma sugestão'), findsOneWidget);
      expect(find.textContaining('O percentual é calculado pelo Mentorly'),
          findsOneWidget);
      expect(find.textContaining('Evidência: O aluno escreve'), findsOneWidget);
      expect(find.text('Compreensão do conceito · Parcialmente atendido'),
          findsOneWidget);
      expect(find.text('Bom começo; explique o papel das máquinas.'),
          findsOneWidget);
    });

    testWidgets('usar nota sugerida devolve so o numero, sem salvar nada',
        (tester) async {
      final servico = _ServicoFalso();
      final resultado = await _abrir(tester, servico);
      await _preencher(tester);
      await tester.tap(find.text('Analisar resposta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usar nota sugerida'));
      await tester.pumpAndSettle();
      expect(resultado.fechou, isTrue);
      expect(resultado.nota, 1.5);
      expect(servico.chamadas, 1); // so a analise: nenhuma outra chamada
    });

    testWidgets('cancelar e voltar nao devolvem nota e voltar guarda o texto',
        (tester) async {
      final servico = _ServicoFalso();
      final resultado = await _abrir(tester, servico);
      await _preencher(tester);
      await tester.tap(find.text('Analisar resposta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('A industrialização aumentou a produção.'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(resultado.fechou, isTrue);
      expect(resultado.nota, isNull);
    });

    testWidgets('falha da IA mostra mensagem e nao perde o que foi digitado',
        (tester) async {
      final servico = _ServicoFalso()
        ..erro = ApiException(503, 'Não foi possível analisar a resposta agora.');
      await _abrir(tester, servico);
      await _preencher(tester);
      await tester.tap(find.text('Analisar resposta'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível analisar a resposta agora.'),
          findsOneWidget);
      expect(find.text('A industrialização aumentou a produção.'), findsOneWidget);
      expect(find.text('Explique a Revolução.'), findsOneWidget);
      expect(find.text('Analisar resposta'), findsOneWidget); // botao volta
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
