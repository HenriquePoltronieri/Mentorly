// Validacoes simples usadas nos formularios
class Validators {
  static String? validarEmail(String? valor) {
    if (valor == null || valor.isEmpty) return 'Digite o email';
    final email = valor.trim();
    final partes = email.split('@');
    if (email.length > 150 || partes.length != 2) return 'Email inválido';
    final local = partes.first;
    final dominio = partes.last;
    final localValido = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$");
    if (local.isEmpty ||
        local.length > 64 ||
        !localValido.hasMatch(local) ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..')) {
      return 'Email inválido';
    }
    final rotulos = dominio.split('.');
    final rotuloValido =
        RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$');
    if (rotulos.length < 2 ||
        rotulos.any((r) => !rotuloValido.hasMatch(r)) ||
        rotulos.last.length < 2) {
      return 'Email inválido';
    }
    return null;
  }

  static String? validarTelefone(String? valor) {
    final digitos = (valor ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return 'Digite o telefone';
    if (digitos.length != 10 && digitos.length != 11) {
      return 'Digite DDD e telefone completos';
    }
    return null;
  }

  static String? validarSenha(String? valor) {
    if (valor == null || valor.isEmpty) return 'Digite a senha';
    if (valor.length < 8) return 'A senha precisa ter no minimo 8 caracteres';
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
