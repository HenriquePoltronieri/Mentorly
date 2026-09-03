// Teste de fumaca do app: garante que a arvore monta e que a rota inicial
// escolhida pelo main() e respeitada.
//
// O teste antigo era o contador padrao do template do Flutter, que nunca
// chegou a ser adaptado para este projeto.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_mentorly/app/routes.dart';
import 'package:app_mentorly/main.dart';

void main() {
  testWidgets('abre na selecao de perfil quando nao ha sessao salva',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(rotaInicial: AppRoutes.perfilSelection),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coordenação'), findsOneWidget);
    expect(find.text('Professor'), findsOneWidget);
  });
}
