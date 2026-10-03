import 'package:app_mentorly/features/coordenacao/models/professorModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('professor pendente separa convite de acesso administrativo', () {
    final professor = ProfessorModel.fromJson({
      'id': 1, 'nome': 'Ana', 'email': 'ana@escola.test',
      'habilitado': true, 'senhaConfigurada': false,
    });
    expect(professor.status, ProfessorModel.convitePendente);
    expect(professor.rotuloStatus, 'Convite pendente');
  });

  test('professor desativado prevalece sobre senha configurada', () {
    final professor = ProfessorModel.fromJson({
      'id': 2, 'nome': 'Bruno', 'email': 'bruno@escola.test',
      'habilitado': false, 'senhaConfigurada': true,
    });
    expect(professor.status, ProfessorModel.desativado);
    expect(professor.rotuloStatus, 'Desativado');
  });

  test('resposta legada com ativo continua aparecendo como ativa', () {
    final professor = ProfessorModel.fromJson({
      'id': 3, 'nome': 'Caio', 'email': 'caio@escola.test', 'ativo': true,
    });
    expect(professor.status, ProfessorModel.ativo);
    expect(professor.rotuloStatus, 'Ativo');
  });
}
