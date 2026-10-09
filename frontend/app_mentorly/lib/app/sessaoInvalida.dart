import 'package:flutter/material.dart';
import '../core/services/apiService.dart';
import 'routes.dart';

// Chaves globais do MaterialApp: permitem navegar e avisar o usuario a partir
// de fora de uma tela (quando o ApiService descobre que a sessao nao vale mais).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Liga o ApiService a este tratamento. Chamado uma vez, no main().
void registrarTratamentoDeSessao(ApiService api) {
  api.aoEncerrarSessao = _aoEncerrarSessao;
}

// Sessao invalida: troca TODA a pilha pelo login do papel que estava logado
// (o botao "voltar" nao devolve a tela autenticada) e avisa uma vez. O
// ApiService garante que isto roda uma unica vez por sessao encerrada.
void _aoEncerrarSessao(MotivoSessaoEncerrada motivo, String? tipoUsuario) {
  final rota = switch (tipoUsuario) {
    'professor' => AppRoutes.professorLogin,
    'coordenacao' => AppRoutes.login,
    _ => AppRoutes.perfilSelection,
  };
  navigatorKey.currentState?.pushNamedAndRemoveUntil(rota, (_) => false);

  final mensagem = motivo == MotivoSessaoEncerrada.professorDesativado
      ? ApiService.mensagemProfessorDesativado
      : ApiService.mensagemSessaoExpirada;
  scaffoldMessengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(mensagem)));
}
