import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFFE8501A); // naranja moto

  // Alto mínimo de los botones de acción: pensado para pulsarse con
  // guantes de moto puestos, no con la precisión de un dedo desnudo.
  static const double _glovedButtonHeight = 56;
  static const double _glovedIconTapSize = 48;

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    // Dark mode por defecto: es el modo "ideal para conducción" que pide el
    // spec (menos deslumbramiento de noche, mejor contraste con el sol
    // directo de día que un fondo blanco).
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF121212),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primaryColor,
        minimumSize: const Size.fromHeight(_glovedButtonHeight),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(_glovedButtonHeight),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(_glovedIconTapSize),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      height: 64,
    ),
  );
}
