import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_mentorly/core/services/apiService.dart';
import 'package:app_mentorly/features/professor/services/chat_ia_service.dart';
import 'package:app_mentorly/features/professor/models/insightsTurmaModel.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().token = 'teste';
    ApiService().usuario = {'id': 1};
  });

  test('atalho repetido apos falha nao duplica pergunta e preserva aviso local',
      () async {
    var chamadas = 0;
    final conversa = ConversaIa(7, 'teste');
    await http.runWithClient(() async {
      await conversa.enviar('Quais medidas aplicar?');
      expect(conversa.erro, isNotNull);
      await conversa.enviar('Quais medidas aplicar?');
      expect(conversa.mensagens.where((m) => m['role'] == 'user').length, 1);
      expect(conversa.mensagens.last['aviso'], 'Análise local');
      expect(conversa.erro, isNull);
      final restaurada = ConversaIa(7, 'teste');
      await Future<void>.delayed(Duration.zero);
      expect(restaurada.mensagens.last['aviso'], 'Análise local');
    },
        () => MockClient((r) async {
              chamadas++;
              return http.Response(
                  jsonEncode(chamadas == 1
                      ? {'error': 'Falha temporária'}
                      : {
                          'resposta': 'Revisar os objetivos avaliados.',
                          'aviso': 'Análise local',
                          'atalhos': []
                        }),
                  chamadas == 1 ? 503 : 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  test('sugestoes locais nao sao identificadas como geradas por IA', () {
    final modelo = InsightsTurmaModel.fromJson({
      'geradoPorIA': false,
      'aviso': 'Análise local',
      'insights': {'resumo': 'Dados registrados'}
    });
    expect(modelo.geradoPorIA, isFalse);
    expect(modelo.aviso, 'Análise local');
  });
}
