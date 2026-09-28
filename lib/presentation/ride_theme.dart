import 'package:flutter/material.dart';

const ink = Color(0xFF15233D);
const electric = Color(0xFF315BFF);
const mist = Color(0xFFEAF0FF);
const orange = Color(0xFFFF8655);
const canvas = Color(0xFFF5F7FC);
const muted = Color(0xFF69758C);

ThemeData rideTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: electric,
    primary: electric,
    secondary: orange,
    surface: Colors.white,
    onSurface: ink,
  ),
  scaffoldBackgroundColor: canvas,
  appBarTheme: const AppBarTheme(
    backgroundColor: canvas,
    foregroundColor: ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -1.3,
    ),
    headlineSmall: TextStyle(
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -.7,
    ),
    titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
    bodyMedium: TextStyle(color: ink, height: 1.4),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: canvas,
    labelStyle: const TextStyle(color: muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFE5EAF5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: electric, width: 2),
    ),
    contentPadding: const EdgeInsets.all(18),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 54),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 50),
      side: const BorderSide(color: Color(0xFFDCE3F2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: mist,
    elevation: 0,
    height: 72,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800
            : FontWeight.w500,
        color: states.contains(WidgetState.selected) ? electric : muted,
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);

class RideBrand extends StatelessWidget {
  const RideBrand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: electric,
          borderRadius: BorderRadius.all(Radius.circular(13)),
        ),
        child: Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.near_me_rounded, color: Colors.white, size: 23),
        ),
      ),
      SizedBox(width: 10),
      Text(
        'ride',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: ink,
        ),
      ),
      Text(
        'move',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: electric,
        ),
      ),
    ],
  );
}
