import 'dart:convert';

import 'package:app_mentorly/features/coordenacao/models/turmaModel.dart';
import 'package:app_mentorly/features/professor/models/atividadeModel.dart';
import 'package:app_mentorly/features/professor/screens/atividades/turmaAtividadesScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// M-04: a lista de atividades mostra so uma previa curta da descricao (2 linhas
// com ellipsis). A descricao completa continua no model e no formulario de
// edicao. Nenhum teste fala com a rede nem com a IA.

const _turma = {'id': 7, 'name': 'Turma 7A', 'anoLetivo': 2026};

// Descricao no formato que o 9B grava: contexto, objetivo, varias questoes com
// alternativas, gabarito, explicacao e rubrica.
String _descricaoGeradaPorIa() {
  final b = StringBuffer()
    ..writeln(
        'Atividade sobre a Revolução Industrial. Leia com atenção e responda.')
    ..writeln(
        'Objetivo: compreender causas e consequências sociais e econômicas.')
    ..writeln();
  for (var i = 1; i <= 10; i++) {
    b
      ..writeln(
          'Questão $i (objetiva): Qual país iniciou a Revolução Industrial no século XVIII '
          'e por qual motivo as máquinas a vapor mudaram o trabalho nas fábricas?')
      ..writeln('A) França   B) Inglaterra   C) Brasil   D) Japão')
      ..writeln(
          'Gabarito: B. Explicação: a Inglaterra reuniu carvão, capital e mão de obra.')
      ..writeln();
  }
  b.writeln(
      'Rubrica sugerida: Compreensão do tema (40), Argumentação (30), Clareza (30).');
  return b.toString();
}

Map<String, dynamic> _atividade({
  int id = 9,
  String titulo = 'Prova 1',
  String descricao = '',
}) =>
    {
      'id': id,
      'title': titulo,
      'description': descricao,
      'class_id': 7,
      'etapa_id': 1,
      'etapa_nome': '1º Bimestre',
      'criterio_id': 1,
      'criterio_nome': 'Prova',
      'nota_maxima': 10.0,
      'due_date': '2026-09-15T00:00:00',
    };

http.Client _cliente(List<Map<String, dynamic>> atividades) =>
    MockClient((req) async {
      final corpo = req.url.path == '/api/activities' ? atividades : [];
      return http.Response(jsonEncode(corpo), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> _abrir(
  WidgetTester tester,
  List<Map<String, dynamic>> atividades, {
  Size tamanho = const Size(1280, 800),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await http.runWithClient(() async {
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: RouteSettings(
          name: '/',
          arguments: TurmaModel.fromJson(Map<String, dynamic>.from(_turma)),
        ),
        builder: (_) => const TurmaAtividadesScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }, () => _cliente(atividades));
}

Text _previa(WidgetTester tester, int id) =>
    tester.widget<Text>(find.byKey(ValueKey('atividade-previa-$id')));

void main() {
  group('descricao curta continua normal', () {
    testWidgets(
        'aparece inteira, sem corte, e o resumo mostra etapa, criterio, valor e data',
        (tester) async {
      await _abrir(tester, [_atividade(descricao: 'Capítulo 3 do livro.')]);

      expect(tester.takeException(), isNull);
      expect(find.text('Prova 1'), findsOneWidget);
      expect(
          find.text(
              '1º Bimestre • Prova • Vale 10 pontos • Entrega: 2026-09-15'),
          findsOneWidget);
      expect(find.text('Capítulo 3 do livro.'), findsOneWidget);
    });

    testWidgets('sem descricao nao cria linha de previa', (tester) async {
      await _abrir(tester, [_atividade()]);
      expect(find.byKey(const ValueKey('atividade-previa-9')), findsNothing);
      expect(find.textContaining('Vale 10 pontos'), findsOneWidget);
    });
  });

  group('descricao longa gerada pela IA (9B)', () {
    final longa = _descricaoGeradaPorIa();

    testWidgets('renderiza sem excecao, com limite de linhas e ellipsis',
        (tester) async {
      expect(longa.length, greaterThan(2000)); // o caso e realmente grande
      await _abrir(tester, [_atividade(descricao: longa)]);

      expect(tester.takeException(), isNull);
      final previa = _previa(tester, 9);
      expect(previa.maxLines, 2);
      expect(previa.overflow, TextOverflow.ellipsis);
      // a previa e curta e nao tem quebras de linha
      final texto = previa.data!;
      expect(texto.length, lessThanOrEqualTo(240));
      expect(texto.contains('\n'), isFalse);
      expect(texto, startsWith('Atividade sobre a Revolução Industrial.'));
      // o texto completo (ex.: a rubrica, no fim) nao esta na lista
      expect(find.textContaining('Rubrica sugerida'), findsNothing);
    });

    testWidgets('o card nao cresce com o tamanho da descricao', (tester) async {
      await _abrir(tester, [
        _atividade(id: 1, titulo: 'Curta', descricao: 'Capítulo 3.'),
        _atividade(id: 2, titulo: 'Gigante', descricao: longa),
      ]);
      expect(tester.takeException(), isNull);
      final alturas = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => tester.getSize(find.byWidget(t)).height)
          .toList();
      expect(alturas, hasLength(2));
      expect(alturas[1], lessThan(160));
      // so a previa (ate 2 linhas) a mais que a descricao curta
      expect(alturas[1] - alturas[0], lessThan(30));
    });

    testWidgets(
        'o essencial continua visivel: titulo, etapa, criterio, valor e data',
        (tester) async {
      await _abrir(tester, [_atividade(descricao: longa)]);
      expect(find.text('Prova 1'), findsOneWidget);
      expect(
          find.text(
              '1º Bimestre • Prova • Vale 10 pontos • Entrega: 2026-09-15'),
          findsOneWidget);
    });

    test('o model guarda a descricao completa, sem truncar', () {
      final modelo = AtividadeModel.fromJson(_atividade(descricao: longa));
      expect(modelo.descricao, longa);
    });

    testWidgets('ao editar, o formulario traz a descricao COMPLETA',
        (tester) async {
      await _abrir(tester, [_atividade(descricao: longa)]);

      await http.runWithClient(() async {
        await tester.tap(find.byTooltip('Editar'));
        await tester.pumpAndSettle();
      }, () => _cliente([_atividade(descricao: longa)]));

      final campo = tester.widget<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Descrição',
      ));
      expect(campo.controller!.text, longa);
      expect(campo.controller!.text.length, longa.length);
    });
  });

  group('largura da tela', () {
    final longa = _descricaoGeradaPorIa();
    final tituloLongo =
        'Avaliação bimestral de História: Revolução Industrial e seus impactos '
        'sociais, econômicos e ambientais no mundo contemporâneo';

    for (final caso in const [
      ('desktop 1280x800', Size(1280, 800)),
      ('tablet 768x1024', Size(768, 1024)),
      ('mobile 360x800', Size(360, 800)),
      ('mobile estreito 320x640', Size(320, 640)),
    ]) {
      testWidgets('${caso.$1}: sem overflow, titulo e botoes acessiveis',
          (tester) async {
        await _abrir(
          tester,
          [_atividade(titulo: tituloLongo, descricao: longa)],
          tamanho: caso.$2,
        );

        // RenderFlex overflow seria reportado como excecao do framework
        expect(tester.takeException(), isNull);
        expect(find.text(tituloLongo), findsOneWidget);
        expect(_previa(tester, 9).maxLines, 2);

        final tela = Offset.zero & caso.$2;
        for (final dica in ['Editar', 'Lançar notas', 'Excluir']) {
          final botao = find.byTooltip(dica);
          expect(botao, findsOneWidget, reason: dica);
          expect(tela.contains(tester.getCenter(botao)), isTrue,
              reason: '$dica dentro da tela');
        }
      });
    }

    testWidgets('lista com varias atividades longas rola sem erro (mobile)',
        (tester) async {
      await _abrir(
        tester,
        [
          for (var i = 1; i <= 8; i++)
            _atividade(id: i, titulo: 'Atividade $i', descricao: longa)
        ],
        tamanho: const Size(360, 800),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
