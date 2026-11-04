import 'package:flutter/services.dart';

/// Máscara brasileira para telefone fixo e celular.
///
/// A tela mostra (11) 91234-5678, mas o backend recebe apenas os dígitos.
class TelefoneBrasileiroFormatter extends TextInputFormatter {
  const TelefoneBrasileiroFormatter();

  static String somenteDigitos(String valor) =>
      valor.replaceAll(RegExp(r'\D'), '');

  static String formatar(String valor) {
    final digitos = somenteDigitos(valor);
    final limitado = digitos.length > 11 ? digitos.substring(0, 11) : digitos;
    if (limitado.isEmpty) return '';
    if (limitado.length < 3) return '($limitado';

    final ddd = limitado.substring(0, 2);
    final numero = limitado.substring(2);
    if (numero.length <= 4) return '($ddd) $numero';

    final tamanhoPrefixo = limitado.length == 11 ? 5 : 4;
    final fimPrefixo =
        tamanhoPrefixo < numero.length ? tamanhoPrefixo : numero.length;
    final prefixo = numero.substring(0, fimPrefixo);
    final sufixo = numero.substring(prefixo.length);
    return sufixo.isEmpty ? '($ddd) $prefixo' : '($ddd) $prefixo-$sufixo';
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final texto = formatar(newValue.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
