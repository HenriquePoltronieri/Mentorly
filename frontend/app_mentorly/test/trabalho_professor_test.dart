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
      await t.enterText(find.byType(TextFormField).at(1), '11');
      await t.enterText(find.byType(TextFormField).first, 'Aluno inexistente');
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
        () => MockClient((r) async => resposta({
              'notas': [
                {'alunoId': 2, 'aluno': 'Ana', 'valor': 9}
              ]
            })));
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
