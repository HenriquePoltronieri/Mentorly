import 'dart:convert';

import 'package:app_mentorly/core/utils/mensagensConvite.dart';
import 'package:app_mentorly/features/coordenacao/screens/professores/cadastroProfessorScreen.dart';
import 'package:app_mentorly/features/coordenacao/screens/professores/listaProfessoresScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// A tela nunca diz "Convite enviado" quando a API respondeu conviteEnviado:false.
// Sem rede: MockClient.

const _professorPendente = {
  'id': 7,
  'nome': 'Fulano Tal',
  'email': 'fulano@escola.test',
  'disciplina': 'Matematica',
  'status': 'convite_pendente',
  'habilitado': true,
  'totalTurmas': 0,
  'turmas': [],
};

http.Client _api({
  Map<String, Object?>? cadastro,
  Map<String, Object?>? reenvio,
  Map<String, Object?>? edicao,
}) =>
    MockClient((req) async {
      final rota = '${req.method} ${req.url.path}';
      Object? corpo;
      var status = 200;
      if (rota == 'GET /api/coordenacao/professores') {
        corpo = [_professorPendente];
      } else if (rota == 'POST /api/coordenacao/professores') {
        corpo = cadastro;
        status = 201;
      } else if (rota.endsWith('/reenviar-convite')) {
        corpo = reenvio;
      } else if (rota == 'PUT /api/coordenacao/professores/7') {
        corpo = edicao;
      }
      return http.Response(jsonEncode(corpo ?? {}), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> _abrirCadastro(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CadastroProfessorScreen()),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), 'Fulano Tal');
  await tester.enterText(campos.at(1), 'fulano@escola.test');
  await tester.enterText(campos.at(2), 'Matematica');
  await tester.tap(find.text('Cadastrar'));
  await tester.pumpAndSettle();
}

void main() {
  group('textos (MensagensConvite)', () {
    test('enviado = true diz que o convite foi enviado', () {
      expect(MensagensConvite.cadastro({'conviteEnviado': true}),
          'Professor cadastrado. Convite enviado por e-mail.');
      expect(MensagensConvite.reenvio({'conviteEnviado': true}),
          'Convite reenviado por e-mail.');
      expect(MensagensConvite.edicao({'conviteEnviado': true}),
          'Professor atualizado. Novo convite enviado por e-mail.');
    });

    test('enviado = false (ou ausente) NUNCA diz que foi enviado', () {
      for (final resposta in [
        {'conviteEnviado': false},
        <String, dynamic>{},
      ]) {
        final textos = [
          MensagensConvite.cadastro(resposta),
          MensagensConvite.reenvio(resposta),
        ];
        for (final texto in textos) {
          expect(texto, contains('não pôde ser enviado'));
          expect(texto, isNot(contains('Convite enviado')));
          expect(texto, isNot(contains('Convite reenviado')));
        }
      }
      expect(MensagensConvite.cadastro({'conviteEnviado': false}),
          'Professor cadastrado, mas o convite não pôde ser enviado por e-mail.');
    });

    test('edicao so avisa quando houve convite novo', () {
      expect(MensagensConvite.edicao({'id': 7, 'nome': 'Fulano'}), isNull);
      expect(MensagensConvite.edicao({'conviteEnviado': false}),
          'Professor atualizado, mas o novo convite não pôde ser enviado por e-mail.');
    });
  });

  group('cadastro de professor', () {
    testWidgets('conviteEnviado=true: avisa que enviou e volta para a lista',
        (tester) async {
      await http.runWithClient(() async {
        await _abrirCadastro(tester);
        expect(find.text('Professor cadastrado. Convite enviado por e-mail.'),
            findsOneWidget);
        expect(find.text('Cadastrar Professor'), findsNothing); // tela fechou
      }, () => _api(cadastro: {'id': 7, 'conviteEnviado': true}));
    });

    testWidgets('conviteEnviado=false: cadastrado, mas o e-mail nao saiu',
        (tester) async {
      await http.runWithClient(() async {
        await _abrirCadastro(tester);
        expect(
            find.text(
                'Professor cadastrado, mas o convite não pôde ser enviado por e-mail.'),
            findsOneWidget);
        expect(find.text('Professor cadastrado. Convite enviado por e-mail.'),
            findsNothing);
        expect(find.text('Cadastrar Professor'), findsNothing);
      }, () => _api(cadastro: {'id': 7, 'conviteEnviado': false}));
    });

    testWidgets(
        'modo dev (conviteToken) sem e-mail: mantem o link local e diz a verdade',
        (tester) async {
      await http.runWithClient(() async {
        await _abrirCadastro(tester);
        expect(find.textContaining('definir-senha?token=tok-local'),
            findsOneWidget);
        expect(find.textContaining('não pôde ser enviado'), findsOneWidget);
        expect(find.text('Copiar link'), findsOneWidget);
        expect(find.text('Cadastrar Professor'), findsOneWidget); // nao fechou
      },
          () => _api(cadastro: {
                'id': 7,
                'conviteEnviado': false,
                'conviteToken': 'tok-local'
              }));
    });

    testWidgets('modo dev com e-mail enviado: link local e aviso de envio',
        (tester) async {
      await http.runWithClient(() async {
        await _abrirCadastro(tester);
        expect(find.textContaining('definir-senha?token=tok-local'),
            findsOneWidget);
        expect(find.textContaining('O convite foi enviado por e-mail'),
            findsOneWidget);
        expect(find.textContaining('não pôde ser enviado'), findsNothing);
      },
          () => _api(cadastro: {
                'id': 7,
                'conviteEnviado': true,
                'conviteToken': 'tok-local'
              }));
    });
  });

  group('lista de professores', () {
    Future<void> reenviar(WidgetTester tester) async {
      await tester
          .pumpWidget(const MaterialApp(home: ListaProfessoresScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reenviar convite'));
      await tester.pumpAndSettle();
    }

    testWidgets('reenvio com e-mail enviado', (tester) async {
      await http.runWithClient(() async {
        await reenviar(tester);
        expect(find.text('Convite reenviado por e-mail.'), findsOneWidget);
      }, () => _api(reenvio: {'id': 7, 'conviteEnviado': true}));
    });

    testWidgets('reenvio com conviteEnviado=false nao diz que reenviou',
        (tester) async {
      await http.runWithClient(() async {
        await reenviar(tester);
        expect(
            find.text(
                'O convite foi renovado, mas o e-mail não pôde ser enviado.'),
            findsOneWidget);
        expect(find.text('Convite reenviado por e-mail.'), findsNothing);
      }, () => _api(reenvio: {'id': 7, 'conviteEnviado': false}));
    });

    testWidgets('reenvio em modo dev preserva o token local', (tester) async {
      await http.runWithClient(() async {
        await reenviar(tester);
        expect(
            find.text(
                'Convite renovado. Ambiente de desenvolvimento: token tok-local'),
            findsOneWidget);
      },
          () => _api(reenvio: {
                'id': 7,
                'conviteEnviado': false,
                'conviteToken': 'tok-local'
              }));
    });

    testWidgets(
        'trocar o e-mail de convite pendente avisa se o novo convite nao saiu',
        (tester) async {
      await http.runWithClient(() async {
        await tester
            .pumpWidget(const MaterialApp(home: ListaProfessoresScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
        expect(
            find.text(
                'Professor atualizado, mas o novo convite não pôde ser enviado por e-mail.'),
            findsOneWidget);
      }, () => _api(edicao: {'id': 7, 'conviteEnviado': false}));
    });

    testWidgets('editar sem gerar convite novo nao mostra aviso de e-mail',
        (tester) async {
      await http.runWithClient(() async {
        await tester
            .pumpWidget(const MaterialApp(home: ListaProfessoresScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
        expect(find.textContaining('e-mail'), findsNothing);
      }, () => _api(edicao: {'id': 7, 'nome': 'Fulano Tal'}));
    });
  });
}
