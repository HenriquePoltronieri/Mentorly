import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_mentorly/app/theme.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/professor/services/rascunho_notas_service.dart';
import 'package:app_mentorly/features/professor/screens/dashboardScreen.dart';
import 'package:app_mentorly/features/professor/screens/turmas/grade_notas_screen.dart';
import 'package:app_mentorly/features/professor/screens/atividades/atividadeNotasScreen.dart';
import 'package:app_mentorly/features/professor/models/atividadeModel.dart';

http.Response resposta(Object valor) => http.Response(jsonEncode(valor), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
Widget tela(Widget child, {Object? args}) => MaterialApp(
    theme: appTheme,
    onGenerateRoute: (_) => MaterialPageRoute(
        settings: RouteSettings(arguments: args), builder: (_) => child));
Finder gradeScrollable() => find
    .descendant(
        of: find.byKey(const ValueKey('grade-lista')),
        matching: find.byType(Scrollable))
    .first;

Map<String, dynamic> gradeFixture() => {
      'etapas': [
        {'id': 1, 'nome': '1º Bimestre'},
        {'id': 2, 'nome': '2º Bimestre'}
      ],
      'atividades_cadastro': [
        {
          'id': 8,
          'title': 'Prova',
          'class_id': 7,
          'nota_maxima': 10,
          'etapa_id': 1
        },
        {
          'id': 9,
          'title': 'Trabalho',
          'class_id': 7,
          'nota_maxima': 20,
          'etapa_id': 2
        }
      ],
      'alunos': [
        {
          'id': 2,
          'nome': 'Ana',
          'atividades': [
            {'id': 8, 'nota': null, 'situacao': 'Ausente'},
            {'id': 9, 'nota': null, 'situacao': 'Sem nota lançada'}
          ]
        }
      ],
    };

Map<String, dynamic> gradeComResumoFixture() => {
      'etapas': [
        {'id': 1, 'nome': 'Etapa 1', 'nota_minima': 18, 'nota_maxima': 30}
      ],
      'criterios': [
        {
          'id': 4,
          'etapa_id': 1,
          'nome': 'Comportamento',
          'peso': 33.33,
          'nota_maxima': 10
        }
      ],
      'atividades_cadastro': [
        {
          'id': 8,
          'title': 'Participação',
          'class_id': 7,
          'nota_maxima': 2,
          'etapa_id': 1,
          'criterio_id': 4
        }
      ],
      'alunos': [
        {
          'id': 2,
          'nome': 'Ana',
          'acompanhamento_etapas': [
            {
              'etapa_id': 1,
              'risco': 'Médio',
              'motivos': [
                'Desempenho abaixo de 50% em atividade: Participação.'
              ]
            }
          ],
          'resultado_etapas': [],
          'atividades': [
            {'id': 8, 'nota': 1, 'situacao': 'Entregue', 'criterio_id': 4}
          ]
        }
      ],
    };

Map<String, dynamic> gradeTodasEtapasFixture() => {
      'etapas': [
        {'id': 1, 'nome': 'Etapa 1', 'nota_minima': 18, 'nota_maxima': 30},
        {'id': 2, 'nome': 'Etapa 2', 'nota_minima': 42, 'nota_maxima': 70}
      ],
      'criterios': [
        {
          'id': 11,
          'etapa_id': 1,
          'nome': 'Comportamento',
          'peso': 33.33,
          'nota_maxima': 10
        },
        {
          'id': 12,
          'etapa_id': 1,
          'nome': 'Provas',
          'peso': 33.33,
          'nota_maxima': 10
        },
        {
          'id': 13,
          'etapa_id': 1,
          'nome': 'Trabalhos',
          'peso': 33.34,
          'nota_maxima': 10
        },
        {
          'id': 21,
          'etapa_id': 2,
          'nome': 'Comportamento',
          'peso': 28.57,
          'nota_maxima': 20
        },
        {
          'id': 22,
          'etapa_id': 2,
          'nome': 'Provas',
          'peso': 42.86,
          'nota_maxima': 30
        },
        {
          'id': 23,
          'etapa_id': 2,
          'nome': 'Trabalhos',
          'peso': 28.57,
          'nota_maxima': 20
        }
      ],
      'atividades_cadastro': [
        {
          'id': 31,
          'title': 'Participação',
          'class_id': 7,
          'nota_maxima': 2,
          'etapa_id': 1,
          'criterio_id': 11
        },
        {
          'id': 32,
          'title': 'Prova 1',
          'class_id': 7,
          'nota_maxima': 10,
          'etapa_id': 1,
          'criterio_id': 12
        },
        {
          'id': 33,
          'title': 'Projeto',
          'class_id': 7,
          'nota_maxima': 15.34,
          'etapa_id': 2,
          'criterio_id': 23
        }
      ],
      'alunos': [
        {
          'id': 2,
          'nome': 'Ana',
          'acompanhamento_etapas': [],
          'resultado_etapas': [],
          'atividades': [
            {'id': 31, 'nota': 1, 'situacao': 'Entregue', 'criterio_id': 11},
            {'id': 32, 'nota': 8, 'situacao': 'Entregue', 'criterio_id': 12},
            {'id': 33, 'nota': 10, 'situacao': 'Entregue', 'criterio_id': 23}
          ]
        }
      ],
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().invalidarCache();
    ApiService().token = 'teste';
    ApiService().usuario = {'id': 1, 'coordenacao_id': 3, 'tipo': 'professor'};
  });
  test('rascunhos preservam a ordem de gravação e ficam separados por conta',
      () async {
    final a = RascunhoNotasService('atividade.8');
    final primeira = a.gravar({'nota': '1'});
    final segunda = a.gravar({'nota': '2'});
    await Future.wait([primeira, segunda]);
    expect((await a.ler())?['nota'], '2');
    ApiService().usuario = {'id': 2, 'coordenacao_id': 3, 'tipo': 'professor'};
    expect(await RascunhoNotasService('atividade.8').ler(), isNull);
    await a.apagar();
    expect(await a.ler(), isNull);
  });
  for (final largura in [320.0, 1280.0]) {
    testWidgets('painel com pendências e navegação sem overflow em $largura',
        (t) async {
      t.view.physicalSize = Size(largura, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await http.runWithClient(() async {
        await t.pumpWidget(tela(const DashboardScreen()));
        await t.pumpAndSettle();
        expect(find.text('Olá, Ana'), findsOneWidget);
        expect(find.text('O que precisa da sua atenção'), findsOneWidget);
        expect(find.text('Prova de frações'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
          () =>
              MockClient((r) async => resposta(r.url.path.endsWith('/trabalho')
                  ? {
                      'pendencias': [
                        {
                          'id': 8,
                          'titulo': 'Prova de frações',
                          'turma_id': 7,
                          'turma': '7A',
                          'sem_nota': 4,
                          'total_alunos': 30,
                          'etapa': '2º Bimestre',
                          'data_entrega': '2026-10-20'
                        }
                      ],
                      'turmas': [
                        {'id': 7, 'nome': '7A', 'totalAlunos': 30}
                      ],
                      'acompanhamentos': [],
                    }
                  : {
                      'nome': 'Ana Silva',
                      'anoLetivo': 2026,
                      'totalTurmas': 1,
                      'totalAlunos': 30,
                      'alunosEmRisco': []
                    })));
    });
  }
  testWidgets(
      'grade bloqueia nota inválida mesmo se campo for ocultado pelo filtro',
      (t) async {
    var posts = 0;
    await http.runWithClient(() async {
      await t.pumpWidget(
          tela(const GradeNotasScreen(), args: {'id': 7, 'nome': '7A'}));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('grade-2-8')), 600,
          scrollable: gradeScrollable());
      await t.enterText(find.byKey(const ValueKey('grade-2-8')), '11');
      await t.scrollUntilVisible(
          find.byKey(const ValueKey('busca-aluno')), -600,
          scrollable: gradeScrollable());
      await t.enterText(
          find.byKey(const ValueKey('busca-aluno')), 'Aluno inexistente');
      await t.pumpAndSettle();
      await t.tap(find.text('Salvar alterações'));
      await t.pumpAndSettle();
      expect(posts, 0);
      expect(find.textContaining('Revise a nota de Ana'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
        () => MockClient((r) async {
              if (r.method == 'POST') posts++;
              return resposta(gradeFixture());
            }));
  });
  testWidgets('grade mostra pontos simples, planejamento e alerta da etapa',
      (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await http.runWithClient(() async {
      await t.pumpWidget(
          tela(const GradeNotasScreen(), args: {'id': 7, 'nome': '7A'}));
      await t.pumpAndSettle();
      expect(find.text('Total permitido: 10 pts'), findsOneWidget);
      expect(find.text('Já distribuído: 2 pts'), findsOneWidget);
      expect(find.text('Restam 8 pts para distribuir'), findsOneWidget);
      expect(find.text('1 aluno(s) precisam de conferência nesta etapa.'),
          findsOneWidget);
      expect(find.textContaining('Desempenho abaixo de 50%'), findsOneWidget);
      expect(find.text('2 / 2'), findsNothing);
      expect(find.text('1 / 30'), findsNothing);
      expect(find.text('Total oficial'), findsOneWidget);
      expect(find.text('Mínimo para aprovação'), findsOneWidget);
      expect(find.text('30 pontos'), findsOneWidget);
      expect(find.text('18 pontos'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Boletim rápido da etapa'), 500,
          scrollable: gradeScrollable());
      expect(find.text('Total do aluno\nEscala: 30 pts'), findsOneWidget);
      expect(find.text('1 de 10 pts'), findsOneWidget);
      expect(find.text('de 2'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => resposta(gradeComResumoFixture())));
  });
  testWidgets(
      'todas as etapas usam total e mínimo oficiais e agrupam critérios',
      (t) async {
    t.view.physicalSize = const Size(1500, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await http.runWithClient(() async {
      await t.pumpWidget(
          tela(const GradeNotasScreen(), args: {'id': 7, 'nome': '7A'}));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<int>));
      await t.pumpAndSettle();
      await t.tap(find.text('Todas as etapas').last);
      await t.pumpAndSettle();

      expect(find.text('Todas as etapas'), findsWidgets);
      expect(find.text('100 pontos'), findsOneWidget);
      expect(find.text('60 pontos'), findsOneWidget);
      expect(find.text('27.34 pontos'), findsOneWidget);
      expect(find.text('72.66 pontos'), findsOneWidget);
      expect(find.text('Total permitido: 30 pts'), findsWidgets);
      expect(find.text('Total permitido: 40 pts'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Boletim geral'), 600,
          scrollable: gradeScrollable());
      expect(find.text('Total do aluno\nEscala: 100 pts'), findsOneWidget);
      expect(find.text('1 de 30 pts'), findsOneWidget);
      expect(find.text('8 de 40 pts'), findsOneWidget);
      expect(find.text('10 de 30 pts'), findsOneWidget);
      expect(find.text('19 de 100 pts'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => resposta(gradeTodasEtapasFixture())));
  });
  testWidgets('falha 500 da IA vira mensagem amigável na grade', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await http.runWithClient(() async {
      await t.pumpWidget(
          tela(const GradeNotasScreen(), args: {'id': 7, 'nome': '7A'}));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Gerar sugestões com IA'), 400,
          scrollable: gradeScrollable());
      await t.drag(gradeScrollable(), const Offset(0, -180));
      await t.pumpAndSettle();
      await t.tap(find.text('Gerar sugestões com IA'));
      await t.pumpAndSettle();
      expect(
          find.text(
              'Não foi possível gerar as sugestões agora. Tente novamente em instantes.'),
          findsOneWidget);
      expect(find.text('Erro interno do servidor.'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
        () => MockClient((r) async {
              if (r.method == 'POST' && r.url.path.endsWith('/insights')) {
                return http.Response(
                    jsonEncode({'error': 'Erro interno do servidor.'}), 500,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }
              return resposta(gradeComResumoFixture());
            }));
  });
  testWidgets('recuperação de rascunho preserva nota alterada no servidor',
      (t) async {
    await RascunhoNotasService('atividade.8').gravar({
      'campos': {
        '2': {'texto': '7.0', 'situacao': 'Nota', 'original': '5.0|Nota'}
      }
    });
    await http.runWithClient(() async {
      await t.pumpWidget(tela(const AtividadeNotasScreen(), args: {
        'atividade':
            AtividadeModel(id: '8', nome: 'Prova', turmaId: '7', notaMaxima: 10)
      }));
      await t.pumpAndSettle();
      await t.tap(find.text('Recuperar'));
      await t.pumpAndSettle();
      expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '9.0');
      expect(
          find.textContaining('1 campos mudaram no servidor'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('/anexos')) return resposta([]);
              return resposta({
                'notas': [
                  {'alunoId': 2, 'aluno': 'Ana', 'valor': 9}
                ]
              });
            }));
  });
  testWidgets('excluir uma nota preserva o rascunho dos demais alunos',
      (t) async {
    t.view.physicalSize = const Size(900, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var excluiu = false;
    await http.runWithClient(() async {
      await t.pumpWidget(tela(const AtividadeNotasScreen(), args: {
        'atividade':
            AtividadeModel(id: '8', nome: 'Prova', turmaId: '7', notaMaxima: 10)
      }));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).at(1), '8');
      await t.ensureVisible(find.byTooltip('Excluir nota'));
      await t.tap(find.byTooltip('Excluir nota'));
      await t.pumpAndSettle();
      await t.tap(find.text('Excluir'));
      await t.pumpAndSettle();
      expect(find.text('Continuar rascunho?'), findsOneWidget);
      await t.tap(find.text('Recuperar'));
      await t.pumpAndSettle();
      expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).at(0))
              .controller!
              .text,
          '');
      expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).at(1))
              .controller!
              .text,
          '8');
      await t.pumpWidget(const SizedBox());
    },
        () => MockClient((r) async {
              if (r.method == 'GET' && r.url.path.endsWith('/anexos')) {
                return resposta([]);
              }
              if (r.method == 'DELETE') {
                excluiu = true;
                return resposta({});
              }
              return resposta({
                'notas': [
                  {
                    'id': excluiu ? null : 1,
                    'alunoId': 2,
                    'aluno': 'Ana',
                    'valor': excluiu ? null : 5
                  },
                  {'alunoId': 3, 'aluno': 'Bia', 'valor': null}
                ]
              });
            }));
  });
}
