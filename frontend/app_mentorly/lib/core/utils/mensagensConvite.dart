// Texto para o Professor da Coordenacao sobre o envio do convite por e-mail.
//
// O backend responde "conviteEnviado": true/false. Quando false (SMTP ausente
// ou com falha) o professor FOI cadastrado/atualizado, so o e-mail nao saiu:
// a tela nao pode dizer "Convite enviado". A Coordenacao pode reenviar depois.
class MensagensConvite {
  static const String cadastroEnviado =
      'Professor cadastrado. Convite enviado por e-mail.';
  static const String cadastroNaoEnviado =
      'Professor cadastrado, mas o convite não pôde ser enviado por e-mail.';
  static const String reenvioEnviado = 'Convite reenviado por e-mail.';
  static const String reenvioNaoEnviado =
      'O convite foi renovado, mas o e-mail não pôde ser enviado.';
  static const String edicaoEnviado =
      'Professor atualizado. Novo convite enviado por e-mail.';
  static const String edicaoNaoEnviado =
      'Professor atualizado, mas o novo convite não pôde ser enviado por e-mail.';

  static bool _enviado(Map<String, dynamic> resposta) =>
      resposta['conviteEnviado'] == true;

  static String cadastro(Map<String, dynamic> resposta) =>
      _enviado(resposta) ? cadastroEnviado : cadastroNaoEnviado;

  static String reenvio(Map<String, dynamic> resposta) =>
      _enviado(resposta) ? reenvioEnviado : reenvioNaoEnviado;

  // So ha aviso quando a edicao gerou convite novo (e-mail de professor com
  // convite pendente trocado): a resposta traz "conviteEnviado" so nesse caso.
  static String? edicao(Map<String, dynamic> resposta) {
    if (!resposta.containsKey('conviteEnviado')) return null;
    return _enviado(resposta) ? edicaoEnviado : edicaoNaoEnviado;
  }
}
