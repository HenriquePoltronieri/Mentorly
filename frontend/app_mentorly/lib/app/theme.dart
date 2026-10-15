import 'package:flutter/material.dart';

// Valores aproximados do design fornecido; sem referência Figma/prints anexos.
abstract final class AppCores {
  static const acento = Color(0xFF62E0D0);
  static const azul = Color(0xFF5AABF5);
  static const azulForma = Color(0xFFA9C4E2);
  static const coordenacao = Color(0xFF1F4FE6);
  static const professorVerde = Color(0xFF3FD6A0);
  static const professorCiano = Color(0xFF1FC8D8);
  static const professorAzul = Color(0xFF1E9BE8);
  static const neutro = Color(0xFF2AA0FF);
  static const texto = Color(0xFF171B24);
  static const secundario = Color(0xFF424B5A);
  static const fundo = Color(0xFFF5F7FB);
  static const linha = Color(0xFFE0E6EF);
  static const vidro = Color(0xFFFFFFFF);
  static const sucesso = Color(0xFF236844);
  static const atencao = Color(0xFF995410);
}

abstract final class AppEspacos {
  static const pequeno = 8.0;
  static const medio = 16.0;
  static const grande = 24.0;
  static const secao = 32.0;
}

abstract final class AppVisual {
  static const raioCard = 14.0;
  static const raioPilula = 10.0;
  static const bordaPeso = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(raioPilula)),
      borderSide: BorderSide(color: AppCores.secundario));
  static const transicao = Duration(milliseconds: 280);
  static const sombraCard = [
    BoxShadow(color: Color(0x050B2440), blurRadius: 8, offset: Offset(0, 2))
  ];
  static const sombraCampo = [
    BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))
  ];
  static final pilula =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(raioPilula));
}

final _borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppVisual.raioPilula),
    borderSide: const BorderSide(color: AppCores.linha));

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  visualDensity: VisualDensity.standard,
  materialTapTargetSize: MaterialTapTargetSize.padded,
  fontFamily: 'Poppins',
  scaffoldBackgroundColor: AppCores.fundo,
  colorScheme:
      ColorScheme.fromSeed(seedColor: AppCores.azul, surface: AppCores.fundo)
          .copyWith(
    primary: AppCores.coordenacao,
    onPrimary: Colors.white,
    secondary: AppCores.azul,
    onSurface: AppCores.texto,
    outline: AppCores.secundario,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w300,
        height: 1.25,
        color: AppCores.texto),
    headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppCores.texto),
    headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: AppCores.texto),
    titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w500, color: AppCores.texto),
    titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w500, color: AppCores.texto),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppCores.texto),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppCores.texto),
    bodySmall: TextStyle(fontSize: 13, height: 1.5, color: AppCores.secundario),
  ),
  appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppCores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppCores.texto)),
  elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
          backgroundColor: AppCores.coordenacao,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: AppVisual.pilula)),
  filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          backgroundColor: AppCores.coordenacao,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: AppVisual.pilula)),
  outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          foregroundColor: AppCores.texto,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: AppVisual.pilula,
          side: const BorderSide(color: AppCores.secundario))),
  textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: AppCores.texto,
          minimumSize: const Size(48, 48),
          shape: AppVisual.pilula)),
  iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
          minimumSize: const Size(48, 48), foregroundColor: AppCores.texto)),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppCores.acento,
      foregroundColor: AppCores.texto,
      elevation: 2,
      shape: StadiumBorder()),
  inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: _borda,
      enabledBorder: _borda,
      focusedBorder: _borda.copyWith(
          borderSide: const BorderSide(color: AppCores.coordenacao, width: 2)),
      errorBorder: _borda.copyWith(
          borderSide: const BorderSide(color: Color(0xFFBA1A1A))),
      labelStyle: const TextStyle(fontSize: 14, color: AppCores.secundario),
      helperStyle: const TextStyle(fontSize: 13, color: AppCores.secundario),
      errorStyle: const TextStyle(fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      helperMaxLines: 3,
      errorMaxLines: 3),
  chipTheme: ChipThemeData(
      shape: AppVisual.pilula,
      side: const BorderSide(color: AppCores.linha),
      padding: const EdgeInsets.all(8),
      selectedColor: AppCores.azulForma),
  cardTheme: CardThemeData(
      elevation: 0,
      color: AppCores.vidro,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppVisual.raioCard),
          side: const BorderSide(color: AppCores.linha))),
  dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFF0F4F7),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppVisual.raioCard))),
  dividerTheme: const DividerThemeData(color: AppCores.linha, thickness: 1),
  listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      iconColor: AppCores.texto),
);
