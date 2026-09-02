import 'package:flutter/material.dart';

// telas de autenticacao
import '../features/auth/screens/perfilSelectionScreen.dart';
import '../features/auth/screens/loginScreen.dart';
import '../features/auth/screens/cadastroScreen.dart';
import '../features/auth/screens/professorLoginScreen.dart';
import '../features/auth/screens/definirSenhaProfessorScreen.dart';
import '../features/auth/screens/twoFactorScreen.dart';

// telas coordenacao
import '../features/coordenacao/screens/config/configEtapasScreen.dart';
import '../features/coordenacao/screens/config/configNotasEtapaScreen.dart';
import '../features/coordenacao/screens/config/configCriteriosScreen.dart';
import '../features/coordenacao/screens/coordenacaoHomeScreen.dart';
import '../features/coordenacao/screens/professores/cadastroProfessorScreen.dart';
import '../features/coordenacao/screens/professores/listaProfessoresScreen.dart';
import '../features/coordenacao/screens/turmas/gerenciarTurmasScreen.dart';
import '../features/coordenacao/screens/turmas/listaTurmasProfessorScreen.dart';
import '../features/coordenacao/screens/alunos/listaAlunosTurmaScreen.dart';
import '../features/coordenacao/screens/relatorios/relatorioTurmasScreen.dart';

// telas professor
import '../features/professor/screens/dashboardScreen.dart';
import '../features/professor/screens/turmas/listaTurmasScreen.dart';
import '../features/professor/screens/turmas/turmaAlunosScreen.dart';
import '../features/professor/screens/turmas/alunoDetailScreen.dart';
import '../features/professor/screens/atividades/listaAtividadesScreen.dart';
import '../features/professor/screens/atividades/turmaAtividadesScreen.dart';
import '../features/professor/screens/atividades/atividadeNotasScreen.dart';
import '../features/professor/screens/atividades/buscarAtividadesScreen.dart';

// Nomes das rotas e o mapa usado no MaterialApp.
// Pra passar dado pra tela (turma, aluno, atividade) usa o parametro arguments
// do Navigator.pushNamed e pega de volta com ModalRoute.of(context).settings.arguments
class AppRoutes {
  // auth
  static const String perfilSelection = '/';
  static const String login = '/login';
  static const String cadastro = '/cadastro';
  static const String professorLogin = '/professor-login';
  static const String definirSenha = '/definir-senha';
  static const String twoFactor = '/two-factor';

  // coordenacao
  static const String coordenacaoHome = '/coordenacao/home';
  static const String configEtapas = '/coordenacao/config-etapas';
  static const String configNotasEtapa = '/coordenacao/config-notas';
  static const String configCriterios = '/coordenacao/config-criterios';
  static const String cadastroProfessor = '/coordenacao/cadastro-professor';
  static const String listaProfessores = '/coordenacao/professores';
  static const String gerenciarTurmas = '/coordenacao/gerenciar-turmas';
  static const String listaTurmasProfessor = '/coordenacao/turmas';
  static const String listaAlunosTurma = '/coordenacao/alunos';
  static const String relatorioTurmas = '/coordenacao/relatorio-turmas';

  // professor
  static const String dashboard = '/professor/dashboard';
  static const String listaTurmas = '/professor/turmas';
  static const String turmaAlunos = '/professor/turma-alunos';
  static const String alunoDetail = '/professor/aluno-detail';
  static const String listaAtividades = '/professor/atividades';
  static const String turmaAtividades = '/professor/turma-atividades';
  static const String atividadeNotas = '/professor/atividade-notas';
  static const String buscarAtividades = '/professor/buscar-atividades';

  static Map<String, WidgetBuilder> routes = {
    perfilSelection: (context) => PerfilSelectionScreen(),
    login: (context) => LoginScreen(),
    cadastro: (context) => CadastroScreen(),
    professorLogin: (context) => ProfessorLoginScreen(),
    definirSenha: (context) => DefinirSenhaProfessorScreen(),
    twoFactor: (context) => TwoFactorScreen(),

    coordenacaoHome: (context) => CoordenacaoHomeScreen(),
    configEtapas: (context) => ConfigEtapasScreen(),
    configNotasEtapa: (context) => ConfigNotasEtapaScreen(),
    configCriterios: (context) => ConfigCriteriosScreen(),
    cadastroProfessor: (context) => CadastroProfessorScreen(),
    listaProfessores: (context) => ListaProfessoresScreen(),
    gerenciarTurmas: (context) => GerenciarTurmasScreen(),
    listaTurmasProfessor: (context) => ListaTurmasProfessorScreen(),
    listaAlunosTurma: (context) => ListaAlunosTurmaScreen(),
    relatorioTurmas: (context) => RelatorioTurmasScreen(),

    // professor
    dashboard: (context) => DashboardScreen(),
    listaTurmas: (context) => ListaTurmasScreen(),
    turmaAlunos: (context) => TurmaAlunosScreen(),
    alunoDetail: (context) => AlunoDetailScreen(),
    listaAtividades: (context) => ListaAtividadesScreen(),
    turmaAtividades: (context) => TurmaAtividadesScreen(),
    atividadeNotas: (context) => AtividadeNotasScreen(),
    buscarAtividades: (context) => BuscarAtividadesScreen(),
  };
}