import 'dart:convert';

import 'package:app_mentorly/core/widgets/confirmarExclusaoDialog.dart';
import 'package:app_mentorly/features/coordenacao/models/turmaModel.dart';
import 'package:app_mentorly/features/coordenacao/screens/alunos/listaAlunosTurmaScreen.dart';
import 'package:app_mentorly/features/coordenacao/screens/turmas/gerenciarTurmasScreen.dart';
import 'package:app_mentorly/features/professor/screens/atividades/turmaAtividadesScreen.dart';
import 'package:app_mentorly/features/professor/screens/turmas/turmaAlunosScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Marco I-05: as confirmacoes de exclusao destrutiva informam o impacto real
// (cascatas do schema) e continuam chamando a mesma operacao de exclusao.
// Nenhum teste fala com a rede: o http e substituido por um MockClient.

class _Api {
  final List<String> chamadas = [];
  int statusExclusao = 204;
  String corpoExclusao = '';
  final Map<String, Object> listagens;

  _Api(this.listagens);

  List<String> get exclusoes =>
      chamadas.where((c) => c.startsWith('DELETE')).toList();

  http.Client cliente() => MockClient((req) async {
        final rota = '${req.method} ${req.url.path}';
        chamadas.add(rota);
        if (req.method == 'DELETE') {
          return http.Response(corpoExclusao, statusExclusao,
              headers: {'content-type': 'application/json'});
        }
        final corpo = listagens[req.url.path];
        if (corpo == null) return http.Response('[]', 200);
        return http.Response(jsonEncode(corpo), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

Widget _app(Widget tela, {Object? argumentos}) => MaterialApp(
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: RouteSettings(name: '/', arguments: argumentos),
        builder: (_) => tela,
      ),
    );

Future<void> _executar(
  WidgetTester tester,
  _Api api,
  Future<void> Function() corpo,
) async {
  // O http de nivel superior usa o cliente da zona: o corpo inteiro (inclusive
  // os toques, que disparam os handlers de forma sincrona) roda nela.
  await http.runWithClient(corpo, api.cliente);
}

const _turma = {'id': 7, 'name': 'Turma 7A', 'anoLetivo': 2026};
const _aluno = {'id': 3, 'nome': 'Ana Souza', 'matricula': 'M1', 'media': 7.5};
const _atividade = {
  'id': 9,
  'title': 'Prova 1',
  'class_id': 7,
  'etapa_id': 1,
  'criterio_id': 1,
  'nota_maxima': 10.0,
};

Future<void> _tocarEExcluir(WidgetTester tester) async {
  await tester.tap(find.text('Excluir').last);
  await tester.pumpAndSettle();
}

void main() {
  group('texto das confirmacoes (schema: cascatas reais)', () {
    test('turma avisa alunos, atividades e notas, sem prometer o que o banco recusa', () {
      expect(AvisosDeExclusao.turma, contains('alunos'));
      expect(AvisosDeExclusao.turma, contains('atividades'));
      expect(AvisosDeExclusao.turma, contains('notas'));
      expect(AvisosDeExclusao.turma, contains('pode excluir'));
      expect(AvisosDeExclusao.turma, contains('não pode ser desfeita'));
      // historico protegido por FK RESTRICT nao e prometido como apagado
      expect(AvisosDeExclusao.turma.toLowerCase(), isNot(contains('histórico')));
    });

    test('atividade avisa as notas vinculadas', () {
      expect(AvisosDeExclusao.atividade, contains('notas vinculadas'));
      expect(AvisosDeExclusao.atividade, contains('excluídas'));
      expect(AvisosDeExclusao.atividade, contains('não pode ser desfeita'));
    });

    test('aluno avisa notas e historico de turmas (ambos em cascata no schema)', () {
      expect(AvisosDeExclusao.aluno, contains('notas'));
      expect(AvisosDeExclusao.aluno, contains('histórico de turmas'));
      expect(AvisosDeExclusao.aluno, contains('não pode ser desfeita'));
    });
  });

  group('turma (coordenacao)', () {
    testWidgets('confirmacao mostra o aviso; cancelar NAO exclui', (tester) async {
      final api = _Api({'/api/classes': [_turma]});
      await _executar(tester, api, () async {
        await tester.pumpWidget(_app(const GerenciarTurmasScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Excluir'));
        await tester.pumpAndSettle();
        expect(find.text('Excluir turma?'), findsOneWidget);
        expect(find.textContaining('alunos, atividades e notas vinculados a esta turma'),
            findsOneWidget);
        expect(find.textContaining('Turma 7A'), findsWidgets);
        expect(find.text('Cancelar'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(api.exclusoes, isEmpty);
      });
    });

    testWidgets('confirmar chama a mesma exclusao (DELETE /api/classes/7)', (tester) async {
      final api = _Api({'/api/classes': [_turma]});
      await _executar(tester, api, () async {
        await tester.pumpWidget(_app(const GerenciarTurmasScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Excluir'));
        await tester.pumpAndSettle();
        await _tocarEExcluir(tester);

        expect(api.exclusoes, ['DELETE /api/classes/7']);
        expect(find.textContaining('excluída'), findsOneWidget);
      });
    });

    testWidgets('409 do backend aparece com a mensagem amigavel', (tester) async {
      final api = _Api({'/api/classes': [_turma]})
        ..statusExclusao = 409
        ..corpoExclusao = jsonEncode({
          'error':
              'Esta turma possui dados historicos vinculados e nao pode ser excluida.'
        });
      await _executar(tester, api, () async {
        await tester.pumpWidget(_app(const GerenciarTurmasScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Excluir'));
        await tester.pumpAndSettle();
        await _tocarEExcluir(tester);

        expect(api.exclusoes, ['DELETE /api/classes/7']);
        expect(
          find.text('Erro ao excluir: Esta turma possui dados historicos '
              'vinculados e nao pode ser excluida.'),
          findsOneWidget,
        );
        // a turma continua listada (nada foi removido da tela)
        expect(find.text('Turma 7A'), findsOneWidget);
      });
    });
  });

  group('atividade (professor)', () {
    final turma = TurmaModel.fromJson(Map<String, dynamic>.from(_turma));

    testWidgets('confirmacao menciona as notas vinculadas; cancelar NAO exclui', (tester) async {
      final api = _Api({'/api/activities': [_atividade]});
      await _executar(tester, api, () async {
        await tester.pumpWidget(
            _app(const TurmaAtividadesScreen(), argumentos: turma));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Excluir'));
        await tester.pumpAndSettle();
        expect(find.text('Excluir atividade?'), findsOneWidget);
        expect(find.textContaining('As notas vinculadas a esta atividade também serão excluídas'),
            findsOneWidget);
        expect(find.textContaining('Prova 1'), findsWidgets);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(api.exclusoes, isEmpty);
      });
    });

    testWidgets('confirmar chama a mesma exclusao (DELETE /api/activities/9)', (tester) async {
      final api = _Api({'/api/activities': [_atividade]});
      await _executar(tester, api, () async {
        await tester.pumpWidget(
            _app(const TurmaAtividadesScreen(), argumentos: turma));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Excluir'));
        await tester.pumpAndSettle();
        await _tocarEExcluir(tester);

        expect(api.exclusoes, ['DELETE /api/activities/9']);
        expect(find.textContaining('excluída'), findsOneWidget);
      });
    });

    testWidgets('erro do backend (etapa fechada, 400) continua aparecendo', (tester) async {
      final api = _Api({'/api/activities': [_atividade]})
        ..statusExclusao = 400
        ..corpoExclusao = jsonEncode({
          'error': 'Esta atividade pertence a uma etapa fechada. Peca a '
              'coordenacao para reabri-la antes de excluir.'
        });
      await _executar(tester, api, () async {
        await tester.pumpWidget(
            _app(const TurmaAtividadesScreen(), argumentos: turma));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Excluir'));
        await tester.pumpAndSettle();
        await _tocarEExcluir(tester);

        expect(find.textContaining('Erro ao excluir: Esta atividade pertence a uma etapa fechada'),
            findsOneWidget);
      });
    });
  });

  group('aluno', () {
    Future<void> abrirMenuExcluir(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir').last);
      await tester.pumpAndSettle();
    }

    testWidgets('coordenacao: aviso de notas e historico; cancelar NAO exclui', (tester) async {
      final api = _Api({'/api/coordenacao/turmas/7/alunos': [_aluno]});
      await _executar(tester, api, () async {
        await tester.pumpWidget(_app(const ListaAlunosTurmaScreen(),
            argumentos: TurmaModel.fromJson(Map<String, dynamic>.from(_turma))));
        await tester.pumpAndSettle();

        await abrirMenuExcluir(tester);
        expect(find.text('Excluir aluno?'), findsOneWidget);
        expect(find.textContaining('As notas e o histórico de turmas deste aluno também serão excluídos'),
            findsOneWidget);
        expect(find.textContaining('Ana Souza'), findsWidgets);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(api.exclusoes, isEmpty);
      });
    });

    testWidgets('coordenacao: confirmar chama DELETE /api/coordenacao/alunos/3', (tester) async {
      final api = _Api({'/api/coordenacao/turmas/7/alunos': [_aluno]});
      await _executar(tester, api, () async {
        await tester.pumpWidget(_app(const ListaAlunosTurmaScreen(),
            argumentos: TurmaModel.fromJson(Map<String, dynamic>.from(_turma))));
        await tester.pumpAndSettle();
        await abrirMenuExcluir(tester);
        await _tocarEExcluir(tester);

        expect(api.exclusoes, ['DELETE /api/coordenacao/alunos/3']);
        expect(find.textContaining('excluído'), findsOneWidget);
      });
    });

    testWidgets('professor: mesmo aviso; cancelar nao exclui e confirmar chama DELETE /api/professor/alunos/3', (tester) async {
      final api = _Api({'/api/professor/turmas/7/alunos': [_aluno]});
      await _executar(tester, api, () async {
        await tester.pumpWidget(
            _app(const TurmaAlunosScreen(), argumentos: {'id': 7, 'nome': 'Turma 7A'}));
        await tester.pumpAndSettle();

        await abrirMenuExcluir(tester);
        expect(find.textContaining('As notas e o histórico de turmas deste aluno também serão excluídos'),
            findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(api.exclusoes, isEmpty);

        await abrirMenuExcluir(tester);
        await _tocarEExcluir(tester);
        expect(api.exclusoes, ['DELETE /api/professor/alunos/3']);
      });
    });
  });
}
