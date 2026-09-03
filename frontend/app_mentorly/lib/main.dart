import 'package:flutter/material.dart';
import 'app/routes.dart';
import 'app/theme.dart';
import 'core/services/apiService.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Recupera a sessao salva antes de montar a tela, para escolher a rota
  // inicial pelo papel do usuario em vez de sempre cair na selecao de perfil.
  final api = ApiService();
  await api.carregarSessao();

  runApp(MyApp(rotaInicial: _rotaInicial(api)));
}

// Rota pedida na propria URL. No Flutter Web (hash strategy) ela vem no
// fragmento: /#/definir-senha?token=abc
String? _rotaDaUrl() {
  final fragmento = Uri.base.fragment;
  if (fragmento.isEmpty) return null;

  final caminho = fragmento.split('?').first;
  if (caminho.isEmpty || caminho == '/') return null;

  return AppRoutes.routes.containsKey(caminho) ? caminho : null;
}

String _rotaInicial(ApiService api) {
  // Uma rota pedida explicitamente na URL vence a sessao salva. E o que faz
  // o link do convite (/#/definir-senha?token=...) abrir mesmo quando ja
  // existe uma coordenacao logada naquele navegador.
  final rotaPedida = _rotaDaUrl();
  if (rotaPedida != null) return rotaPedida;

  if (!api.estaLogado) return AppRoutes.perfilSelection;
  if (api.ehCoordenacao) return AppRoutes.coordenacaoHome;
  if (api.ehProfessor) return AppRoutes.listaTurmas;
  return AppRoutes.perfilSelection;
}

class MyApp extends StatelessWidget {
  final String rotaInicial;

  const MyApp({super.key, required this.rotaInicial});

  // O mapa de rotas do MaterialApp casa o nome EXATO. Uma URL com query
  // string ("/definir-senha?token=abc") nao bate com nenhuma chave, e o
  // Flutter cai silenciosamente na rota padrao - era por isso que o link
  // do convite abria a tela de selecao de perfil em vez do primeiro acesso.
  //
  // Aqui a query e separada do caminho e entregue a tela como arguments.
  Route<dynamic>? _gerarRota(RouteSettings settings) {
    final nome = settings.name ?? '';
    if (!nome.contains('?')) return null; // caso comum: usa AppRoutes.routes

    final partes = nome.split('?');
    final caminho = partes.first;
    final construtor = AppRoutes.routes[caminho];
    if (construtor == null) return null;

    final parametros = Uri.splitQueryString(partes.sublist(1).join('?'));
    return MaterialPageRoute(
      builder: construtor,
      settings: RouteSettings(
        name: caminho,
        // Se a tela ja recebeu arguments, eles vencem os da query.
        arguments: settings.arguments ?? parametros,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mentorly',
      theme: appTheme,
      initialRoute: rotaInicial,
      routes: AppRoutes.routes,
      onGenerateRoute: _gerarRota,
      debugShowCheckedModeBanner: false,
    );
  }
}
