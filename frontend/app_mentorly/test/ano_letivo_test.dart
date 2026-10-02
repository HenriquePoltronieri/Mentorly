// Testes do modelo de Ano Letivo (Marco 6): o que a tela de Anos Letivos
// e o modal de turma leem da API, sem precisar de rede.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_mentorly/features/coordenacao/models/anoLetivoModel.dart';
import 'package:app_mentorly/features/coordenacao/models/historicoTurmaAlunoModel.dart';
import 'package:app_mentorly/features/coordenacao/models/turmaModel.dart';

void main() {
  group('AnoLetivoModel', () {
    test('le o JSON da API com os totais de turmas e etapas', () {
      final ano = AnoLetivoModel.fromJson({
        'id': 7,
        'ano': 2026,
        'status': 'atual',
        'totalTurmas': 3,
        'totalEtapas': 4,
      });

      expect(ano.id, 7);
      expect(ano.ano, 2026);
      expect(ano.ehAtual, isTrue);
      expect(ano.estaEncerrado, isFalse);
      expect(ano.estaEmPlanejamento, isFalse);
      expect(ano.totalTurmas, 3);
      expect(ano.totalEtapas, 4);
      expect(ano.temDados, isTrue);
      expect(ano.rotuloStatus, 'Atual');
    });

    test('totais ausentes valem zero e o ano pode ser excluido', () {
      final ano = AnoLetivoModel.fromJson({
        'id': 1,
        'ano': 2027,
        'status': 'planejamento',
      });

      expect(ano.estaEmPlanejamento, isTrue);
      expect(ano.temDados, isFalse);
      expect(ano.rotuloStatus, 'Em planejamento');
    });

    test('so turmas OU so etapas ja contam como dados', () {
      expect(
        AnoLetivoModel.fromJson(
          {'id': 1, 'ano': 2026, 'status': 'encerrado', 'totalTurmas': 1},
        ).temDados,
        isTrue,
      );
      expect(
        AnoLetivoModel.fromJson(
          {'id': 1, 'ano': 2026, 'status': 'encerrado', 'totalEtapas': 2},
        ).temDados,
        isTrue,
      );
    });

    test('ano encerrado mantem o status e o rotulo', () {
      final ano = AnoLetivoModel.fromJson(
        {'id': 2, 'ano': 2025, 'status': 'encerrado'},
      );

      expect(ano.estaEncerrado, isTrue);
      expect(ano.ehAtual, isFalse);
      expect(ano.rotuloStatus, 'Encerrado');
    });

    test('status ausente cai em planejamento', () {
      final ano = AnoLetivoModel.fromJson({'id': 3, 'ano': 2028});

      expect(ano.status, AnoLetivoModel.planejamento);
    });
  });

  group('TurmaModel e o ano letivo', () {
    test('mostra o ano da turma para as listas', () {
      final turma = TurmaModel.fromJson(
        {'id': 1, 'name': '9 Ano A', 'anoLetivo': 2026},
      );

      expect(turma.anoLetivo, 2026);
      expect(turma.rotuloAno, 'Ano letivo 2026');
    });

    test('turma sem ano (resposta antiga) nao inventa um', () {
      final turma = TurmaModel.fromJson({'id': 2, 'name': '9 Ano B'});

      expect(turma.anoLetivo, isNull);
      expect(turma.rotuloAno, isEmpty);
    });
  });

  group('HistoricoTurmaAlunoModel', () {
    test('le o vinculo aberto devolvido pela API', () {
      final item = HistoricoTurmaAlunoModel.fromJson({
        'id': 4,
        'turmaId': 9,
        'turma': '1 Ano B',
        'anoLetivo': 2026,
        'dataInicio': '2026-08-10',
        'dataFim': null,
      });

      expect(item.turma, '1 Ano B');
      expect(item.anoLetivo, 2026);
      expect(item.atual, isTrue);
    });

    test('vinculo fechado preserva a data final', () {
      final item = HistoricoTurmaAlunoModel.fromJson({
        'id': 3,
        'turmaId': 8,
        'turma': '1 Ano A',
        'anoLetivo': 2026,
        'dataInicio': '2026-02-01',
        'dataFim': '2026-08-10',
      });

      expect(item.atual, isFalse);
      expect(item.dataFim, '2026-08-10');
    });
  });
}
