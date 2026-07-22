// Validacoes simples usadas nos formularios
class Validators {
  static String? validarEmail(String? valor) {
    if (valor == null || valor.isEmpty) return 'Digite o email';
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(valor)) return 'Email invalido';
    return null;
  }

  static String? validarSenha(String? valor) {
    if (valor == null || valor.isEmpty) return 'Digite a senha';
    if (valor.length < 6) return 'A senha precisa ter no minimo 6 caracteres';
    return null;
  }

  static String? validarCampoObrigatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Campo obrigatorio';
    return null;
  }

  static String? validarNumero(String? valor) {
    if (valor == null || valor.isEmpty) return 'Digite um numero';
    if (double.tryParse(valor) == null) return 'Numero invalido';
    return null;
  }
}
