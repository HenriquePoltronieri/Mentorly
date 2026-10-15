import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/app/theme.dart';
import 'package:app_mentorly/features/coordenacao/screens/professores/cadastroProfessorScreen.dart';
import 'package:app_mentorly/features/professor/screens/atividades/atividadeNotasScreen.dart';
import 'package:app_mentorly/features/professor/models/atividadeModel.dart';
import 'package:app_mentorly/features/coordenacao/models/turmaModel.dart';
import 'package:app_mentorly/features/professor/screens/atividades/adicionarAtividadeModal.dart';
import 'package:app_mentorly/features/professor/screens/chat_ia_screen.dart';
import 'package:app_mentorly/features/professor/widgets/estatisticas_view.dart';

Widget app(Widget tela, {Object? args}) => MaterialApp(
    theme: appTheme,
    onGenerateRoute: (_) => MaterialPageRoute(
        settings: RouteSettings(arguments: args), builder: (_) => tela));
http.Response json(Object o, [int status = 200]) =>
    http.Response(jsonEncode(o), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().invalidarCache();
    ApiService().token = 'teste-${DateTime.now().microsecondsSinceEpoch}';
    ApiService().usuario = {'id': 1, 'tipo': 'professor'};
  });

  testWidgets('cadastro valida inline e mantém preenchimento se servidor falha',
      (t) async {
    ApiService().usuario = {'id': 1, 'tipo': 'coordenacao'};
    Map<String, dynamic>? enviado;
    await http.runWithClient(() async {
      await t.pumpWidget(app(const CadastroProfessorScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text('Cadastrar e enviar convite'));
      await t.pumpAndSettle();
      expect(find.text('Informe o nome completo.'), findsOneWidget);
      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      final campos = find.byType(TextFormField);
      await t.enterText(campos.at(0), 'Professor Teste');
      await t.enterText(campos.at(1), 'teste@example.invalid');
      await t.tap(find.text('7A'));
      await t.tap(find.text('Cadastrar e enviar convite'));
      await t.pumpAndSettle();
      expect(enviado?['turma_ids'], [7]);
      expect(enviado?['nome'], 'Professor Teste');
      expect(find.text('Professor Teste'), findsOneWidget);
      expect(find.text('Tente novamente mais tarde.'), findsOneWidget);
      expect(find.text('Disciplina'), findsNothing);
    },
        () => MockClient((r) async {
              if (r.method == 'GET') {
                return json([
                  {'id': 7, 'nome': '7A'}
                ]);
              }
              enviado = jsonDecode(r.body) as Map<String, dynamic>;
              return json({'error': 'Tente novamente mais tarde.'}, 503);
            }));
  });

  testWidgets(
      'atividade preseleciona turma e etapa atual e usa valor configurado',
      (t) async {
    Map<String, dynamic>? enviado;
    await http.runWithClient(() async {
      await t.pumpWidget(app(AdicionarAtividadeModal(
          turmas: [TurmaModel(id: '7', nome: '7A', anoLetivo: 2026)])));
      await t.pumpAndSettle();
      final campos = find.byType(TextFormField);
      expect(t.widget<TextFormField>(campos.at(1)).controller!.text, '20');
      await t.enterText(campos.at(0), 'Atividade teste');
      await t.ensureVisible(campos.at(2));
      await t.pumpAndSettle();
      await t.tap(campos.at(2));
      await t.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.text('Salvar atividade'));
      await t.pumpAndSettle();
      expect(enviado?['class_id'], 7);
      expect(enviado?['etapa_id'], 2);
      expect(enviado?['nota_maxima'], 20);
      expect(find.text('Lançar notas agora?'), findsOneWidget);
    },
        () => MockClient((r) async {
              if (r.method == 'GET') {
                return json([
                  {
                    'id': 1,
                    'nome': 'Anterior',
                    'ordem': 1,
                    'ativa': true,
                    'fechada': false,
                    'nota_maxima': 10
                  },
                  {
                    'id': 2,
                    'nome': 'Atual',
                    'ordem': 2,
                    'ativa': true,
                    'fechada': false,
                    'nota_maxima': 20,
                    'data_inicio': '2000-01-01',
                    'data_fim': '2099-01-01'
                  }
                ]);
              }
              enviado = jsonDecode(r.body) as Map<String, dynamic>;
              return json({
                'id': 8,
                'title': 'Atividade teste',
                'class_id': 7,
                'nota_maxima': 20,
                'etapa_id': 2
              });
            }));
  });

  testWidgets(
      'notas inválidas não salvam; falta de entrega preserva nota vazia',
      (t) async {
    final posts = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await t.pumpWidget(app(const AtividadeNotasScreen(), args: {
        'atividade':
            AtividadeModel(id: '8', nome: 'Prova', turmaId: '7', notaMaxima: 10)
      }));
      await t.pumpAndSettle();
      final campos = find.byType(TextFormField);
      await t.enterText(campos.at(0), '11');
      await t.tap(find.text('Salvar tudo'));
      await t.pumpAndSettle();
      expect(posts, isEmpty);
      expect(find.text('De 0 a 10.0'), findsOneWidget);
      await t.enterText(campos.at(0), '8');
      await t.drag(find.byType(ListView).last, const Offset(0, -180));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(DropdownButton<String>).at(1));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButton<String>).at(1));
      await t.pumpAndSettle();
      await t.tap(find.text('Não entregou').last);
      await t.pumpAndSettle();
      expect(find.text('1/2 preenchidas'), findsOneWidget);
      await t.tap(find.text('Salvar tudo'));
      await t.pumpAndSettle();
      final notas = posts.single['notas'] as List;
      expect(notas[0]['valor'], 8);
      expect(notas[1]['valor'], isNull);
      expect(notas[1]['situacao'], 'Não entregou');
      expect(notas[1]['observacao'], 'Não entregou');
      expect(
          find.text('Notas salvas! Estatísticas atualizadas.'), findsOneWidget);
    },
        () => MockClient((r) async {
              if (r.method == 'POST') {
                posts.add(jsonDecode(r.body) as Map<String, dynamic>);
                return json({'lancadas': 2});
              }
              return json({
                'notas': [
                  {'alunoId': 1, 'aluno': 'Ana Teste', 'valor': null},
                  {'alunoId': 2, 'aluno': 'Bia Teste', 'valor': null}
                ]
              });
            }));
  });

  testWidgets(
      'chat mantém histórico, repete sem duplicar usuário e nova conversa limpa',
      (t) async {
    var chamadas = 0;
    final pedidos = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await t
          .pumpWidget(app(const ChatIaScreen(), args: {'id': 7, 'nome': '7A'}));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Resumo da turma');
      await t.tap(find.byTooltip('Enviar mensagem'));
      await t.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      await t.tap(find.text('Tentar novamente'));
      await t.pumpAndSettle();
      expect(pedidos.last['turma_id'], 7);
      expect(pedidos.last['historico'], isEmpty);
      expect(find.text('Resumo real da turma.'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Quais medidas aplicar?');
      await t.tap(find.byTooltip('Enviar mensagem'));
      await t.pumpAndSettle();
      expect((pedidos.last['historico'] as List).length, 2);
      await t.tap(find.text('Nova conversa'));
      await t.pumpAndSettle();
      expect(find.text('Resumo real da turma.'), findsNothing);
    },
        () => MockClient((r) async {
              pedidos.add(jsonDecode(r.body) as Map<String, dynamic>);
              if (++chamadas == 1) {
                return json({'error': 'IA indisponível.'}, 503);
              }
              return json({'resposta': 'Resumo real da turma.', 'atalhos': []});
            }));
  });

  testWidgets('gráficos reais renderizam linha e risco em largura móvel',
      (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await http.runWithClient(() async {
      await t
          .pumpWidget(app(const Scaffold(body: EstatisticasView(turmaId: 7))));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byType(LineChart), 200);
      expect(find.byType(LineChart), findsOneWidget);
      final grafico = t.widget<LineChart>(find.byType(LineChart)).data;
      expect(grafico.lineBarsData.first.spots.single.y, 1);
      expect(grafico.maxY, 2);
      await t.scrollUntilVisible(find.byType(PieChart), 200);
      expect(find.byType(PieChart), findsOneWidget);
      expect(t.takeException(), isNull);
    },
        () => MockClient((r) async => json({
              'turma': {'id': 7, 'nome': '7A'},
              'etapas': [],
              'media': 5,
              'percentual_entregas': 100,
              'alunos_em_risco': 1,
              'pior_atividade': {'id': 1, 'titulo': 'Prova', 'media': 5},
              'distribuicao_risco': {
                'Alto': 1,
                'Médio': 0,
                'Baixo': 0,
                'Sem dados': 0
              },
              'atividades': [
                {
                  'id': 1,
                  'titulo': 'Prova',
                  'media': 5,
                  'media_pontos': 1,
                  'nota_maxima': 2
                }
              ],
              'alunos': [
                {'id': 1, 'nome': 'Ana Teste', 'risco': 'Alto', 'media': 5}
              ],
            })));
  });

  testWidgets('estatísticas sem notas têm estado vazio e filtro por etapa',
      (t) async {
    final consultas = <Uri>[];
    await http.runWithClient(() async {
      await t.pumpWidget(
          app(const Scaffold(body: EstatisticasView(turmaId: 7, alunoId: 1))));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
          find.textContaining('Ainda não há notas.'), 200);
      expect(find.textContaining('Ainda não há notas.'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Etapa 1'), -150);
      await t.tap(find.text('Etapa 1'));
      await t.pumpAndSettle();
      expect(consultas.last.queryParameters['etapa_id'], '1');
      expect(t.takeException(), isNull);
    },
        () => MockClient((r) async {
              consultas.add(r.url);
              return json({
                'nome': 'Ana Teste',
                'turma': '7A',
                'media': null,
                'risco': 'Sem dados',
                'atividades': [],
                'etapas': [
                  {'id': 1, 'nome': 'Etapa 1'}
                ],
                'maior_nota': null,
                'menor_nota': null,
                'entregues': 0,
                'pendentes': 0
              });
            }));
  });
}
