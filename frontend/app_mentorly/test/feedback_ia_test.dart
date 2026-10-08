import 'dart:async';

import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/professor/models/estatisticaAlunoModel.dart';
import 'package:app_mentorly/features/professor/models/feedbackIaModel.dart';
import 'package:app_mentorly/features/professor/screens/turmas/feedbackIaDialog.dart';
import 'package:app_mentorly/features/professor/services/feedbackIaService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _resposta({String tipo = 'recuperacao'}) => {
      'contexto': {
        'etapa': '1 Bimestre',
        'etapaId': 4,
        'anoLetivo': 2026,
        'fechada': false,
        'tipoPlano': tipo,
        'resultadoOficial': {
          'nota': 5.4,
          'percentual': 54.0,
          'situacao': 'abaixo_do_minimo',
          'completo': true,
        },
        'atividades': {'avaliadas': 4, 'semNotaLancada': 1, 'total': 5},
      },
      'geradoPorIA': true,
      'modelo': 'modelo-teste',
      'sugestao': {
        'resumo': 'Resultado abaixo do mínimo em Argumentação.',
        'pontosConsolidados': ['Interpretação em 60%.'],
        'pontosAtencao': [
          {'descricao': 'Argumentação com menor desempenho.', 'evidencia': 'Aparece com 45%.'},
        ],
        'objetivosRecuperacao': ['Reforçar a construção de argumentos.'],
        'acoesSugeridas': [
          {'acao': 'Atividade curta com correção guiada.', 'motivo': 'Argumentação em 45%.'},
        ],
        'atividadesSugeridas': ['Exercício de argumento e justificativa.'],
        'acompanhamento': 'Observar as próximas atividades avaliadas.',
      },
    };

EtapaDesempenhoModel _etapa({String situacao = 'abaixo_do_minimo'}) =>
    EtapaDesempenhoModel.fromJson({
      'etapa_id': 4,
      'etapa': '1 Bimestre',
      'nota_minima': 6.0,
      'nota_maxima': 10.0,
      'situacao': situacao,
      'completo': situacao != 'em_andamento',
      'nota_calculada': situacao == 'em_andamento' ? null : (situacao == 'adequado' ? 8.2 : 5.4),
      'percentual': situacao == 'em_andamento' ? null : 54.0,
      'total_atividades': 5,
      'atividades_avaliadas': 4,
      'atividades_sem_nota': 1,
      'criterios': [],
    });

class _ServicoFalso extends FeedbackIaService {
  int chamadas = 0;
  int? ultimoAluno;
  int? ultimaEtapa;
  Completer<FeedbackIaModel>? espera;
  Object? erro;
  String tipo = 'recuperacao';

  @override
  Future<FeedbackIaModel> gerar({required int alunoId, required int etapaId}) {
    chamadas++;
    ultimoAluno = alunoId;
    ultimaEtapa = etapaId;
    if (erro != null) return Future.error(erro!);
    return espera?.future ??
        Future.value(FeedbackIaModel.fromJson(_resposta(tipo: tipo)));
  }
}

Future<void> _abrir(WidgetTester tester, _ServicoFalso servico,
    {String situacao = 'abaixo_do_minimo'}) async {
  // O dialogo e mais alto que a tela padrao de teste (800x600).
  tester.view.physicalSize = const Size(1000, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => FeedbackIaDialog(
                  alunoId: 9,
                  etapa: _etapa(situacao: situacao),
                  alunoNome: 'Ana Souza',
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
  group('FeedbackIaModel', () {
    test('converte a resposta estruturada', () {
      final m = FeedbackIaModel.fromJson(_resposta());
      expect(m.etapa, '1 Bimestre');
      expect(m.tipoPlano, 'recuperacao');
      expect(m.notaOficial, 5.4);
      expect(m.situacaoOficial, 'abaixo_do_minimo');
      expect(m.atividadesSemNota, 1);
      expect(m.pontosAtencao.single.evidencia, 'Aparece com 45%.');
      expect(m.acoes.single.motivo, 'Argumentação em 45%.');
      expect(m.objetivos, hasLength(1));
      expect(m.modelo, 'modelo-teste');
    });

    test('titulos mudam conforme o tipo de plano', () {
      String titulo(String t) =>
          FeedbackIaModel.fromJson(_resposta(tipo: t)).tituloDoPlano;
      String objetivos(String t) =>
          FeedbackIaModel.fromJson(_resposta(tipo: t)).tituloDosObjetivos;
      expect(titulo('recuperacao'), 'Plano de recuperação');
      expect(titulo('continuidade'), 'Plano de continuidade');
      expect(titulo('acompanhamento'), 'Plano de acompanhamento');
      expect(objetivos('continuidade'), 'Objetivos de consolidação e aprofundamento');
      expect(objetivos('recuperacao'), 'Objetivos de recuperação');
    });

    test('tolera campos ausentes sem quebrar', () {
      final m = FeedbackIaModel.fromJson({'contexto': {}, 'sugestao': {}});
      expect(m.notaOficial, isNull);
      expect(m.pontosAtencao, isEmpty);
      expect(m.acoes, isEmpty);
      expect(m.resumo, '');
    });
  });

  group('FeedbackIaDialog', () {
    testWidgets('abrir nao chama a IA e mostra situacao oficial e aviso',
        (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico);

      expect(servico.chamadas, 0); // nenhuma chamada antes do clique
      expect(find.text('Aluno: Ana Souza'), findsOneWidget);
      expect(find.textContaining('Nenhum dado pessoal do aluno'), findsOneWidget);
      expect(find.textContaining('Sugestões geradas por IA'), findsOneWidget);
      expect(find.text('Nota 5,4 de 10 — abaixo do mínimo (6)'), findsOneWidget);
      expect(find.textContaining('A IA não altera nota, situação'), findsOneWidget);
    });

    testWidgets('duplo toque gera um unico pedido e desabilita o botao',
        (tester) async {
      final servico = _ServicoFalso()..espera = Completer();
      await _abrir(tester, servico);

      await tester.tap(find.text('Gerar feedback com IA'));
      await tester.pump();
      expect(find.text('Gerando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Gerando...'), warnIfMissed: false);
      await tester.pump();
      expect(servico.chamadas, 1);
      expect(servico.ultimoAluno, 9);
      expect(servico.ultimaEtapa, 4); // etapa explicita, nunca implicita

      servico.espera!.complete(FeedbackIaModel.fromJson(_resposta()));
      await tester.pumpAndSettle();
      expect(find.text('Plano de recuperação'), findsOneWidget);
      expect(servico.chamadas, 1);
    });

    testWidgets('resultado mostra todas as secoes e o aviso', (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico);
      await tester.tap(find.text('Gerar feedback com IA'));
      await tester.pumpAndSettle();

      for (final texto in const [
        'Plano de recuperação',
        'Resumo da situação',
        'Pontos consolidados',
        'Pontos de atenção',
        'Objetivos de recuperação',
        'Ações sugeridas',
        'Atividades sugeridas',
        'Acompanhamento recomendado',
      ]) {
        expect(find.text(texto), findsOneWidget, reason: texto);
      }
      expect(find.text('Evidência: Aparece com 45%.'), findsOneWidget);
      expect(find.textContaining('Motivo: Argumentação em 45%.'), findsOneWidget);
      expect(find.textContaining('Revise antes de utilizar'), findsOneWidget);
      // A situacao oficial continua vindo do motor, ao lado da sugestao.
      expect(find.text('Nota 5,4 de 10 — abaixo do mínimo (6)'), findsOneWidget);
    });

    testWidgets('adequado mostra plano de continuidade, nao de recuperacao',
        (tester) async {
      final servico = _ServicoFalso()..tipo = 'continuidade';
      await _abrir(tester, servico, situacao: 'adequado');
      expect(find.text('Nota 8,2 de 10 — adequado'), findsOneWidget);
      await tester.tap(find.text('Gerar feedback com IA'));
      await tester.pumpAndSettle();

      expect(find.text('Plano de continuidade'), findsOneWidget);
      expect(find.text('Objetivos de consolidação e aprofundamento'), findsOneWidget);
      expect(find.text('Plano de recuperação'), findsNothing);
    });

    testWidgets('em andamento mostra plano de acompanhamento', (tester) async {
      final servico = _ServicoFalso()..tipo = 'acompanhamento';
      await _abrir(tester, servico, situacao: 'em_andamento');
      expect(find.text('Em andamento — ainda faltam notas para calcular'),
          findsOneWidget);
      await tester.tap(find.text('Gerar feedback com IA'));
      await tester.pumpAndSettle();
      expect(find.text('Plano de acompanhamento'), findsOneWidget);
    });

    testWidgets('falha mostra mensagem amigavel e permite tentar de novo',
        (tester) async {
      final servico = _ServicoFalso()
        ..erro = ApiException(503, 'Não foi possível gerar o feedback agora.');
      await _abrir(tester, servico);
      await tester.tap(find.text('Gerar feedback com IA'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível gerar o feedback agora.'), findsOneWidget);
      expect(find.text('Gerar feedback com IA'), findsOneWidget); // botao volta
      expect(find.text('Plano de recuperação'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      servico.erro = null;
      await tester.tap(find.text('Gerar feedback com IA'));
      await tester.pumpAndSettle();
      expect(find.text('Plano de recuperação'), findsOneWidget);
      expect(servico.chamadas, 2);
    });

    testWidgets('fechar encerra o dialogo sem chamar a IA', (tester) async {
      final servico = _ServicoFalso();
      await _abrir(tester, servico);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Feedback com IA'), findsNothing);
      expect(servico.chamadas, 0);
    });
  });
}
