import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Monochrome palette. Black and white carry the whole interface; the three
/// semantic hues exist only to signal state (available/paid, pending,
/// overdue/destructive) and are never used for decoration.
class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF0B0B0C);
  static const Color inkSoft = Color(0xFF1D1D20);
  static const Color muted = Color(0xFF6E6E73);
  static const Color subtle = Color(0xFFA1A1A6);
  static const Color border = Color(0xFFE8E8EA);
  static const Color fill = Color(0xFFF4F4F5);
  /// Strong neutral for outlines, disabled fills and chart tracks.
  static const Color line = Color(0xFFD4D4D8);
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFEAF6EE);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFDF3E4);
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerSoft = Color(0xFFFDEDEB);

  /// "Live" indicator dot, used only on black surfaces.
  static const Color live = Color(0xFF4ADE80);
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: .06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get lifted => [
        BoxShadow(
          color: Colors.black.withValues(alpha: .18),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ];
}

/// Single source of truth for the app's visual language.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Inter';

  static const SystemUiOverlayStyle lightChrome = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static const SystemUiOverlayStyle darkChrome = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static const _radius = BorderRadius.all(Radius.circular(16));

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      primaryContainer: AppColors.fill,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.ink,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.fill,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAFAFA),
      surfaceContainer: AppColors.fill,
      surfaceContainerHigh: Color(0xFFEFEFF0),
      surfaceContainerHighest: Color(0xFFEAEAEB),
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      inverseSurface: AppColors.ink,
      onInverseSurface: Colors.white,
      surfaceTint: Colors.transparent,
    );

    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -.1,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        // Tuned for Inter: tight tracking on large bold type, near-neutral
        // at body sizes where Inter is already spaced for screens.
        displaySmall: TextStyle(
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: AppColors.ink),
        headlineLarge: TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -.9,
            color: AppColors.ink),
        headlineMedium: TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
            color: AppColors.ink),
        headlineSmall: TextStyle(
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.45,
            color: AppColors.ink),
        titleLarge: TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -.35,
            color: AppColors.ink),
        titleMedium: TextStyle(
            fontSize: 15.5,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -.2,
            color: AppColors.ink),
        titleSmall: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
            letterSpacing: -.1,
            color: AppColors.ink),
        bodyLarge: TextStyle(
            fontSize: 15.5,
            height: 1.5,
            letterSpacing: -.2,
            color: AppColors.ink),
        bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.45,
            letterSpacing: -.1,
            color: AppColors.ink),
        bodySmall:
            TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted),
        labelLarge: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -.1,
            color: AppColors.ink),
        labelMedium: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
        labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
            color: AppColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        systemOverlayStyle: lightChrome,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
          color: AppColors.ink,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: const OutlineInputBorder(
            borderRadius: _radius, borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(
            borderRadius: _radius, borderSide: BorderSide.none),
        disabledBorder: const OutlineInputBorder(
            borderRadius: _radius, borderSide: BorderSide.none),
        focusedBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.ink, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.danger, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppColors.muted),
        floatingLabelStyle: const TextStyle(
            color: AppColors.ink, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.subtle),
        helperStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
        prefixIconColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.focused)
                ? AppColors.ink
                : AppColors.muted),
        suffixIconColor: AppColors.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: buttonText,
          shape: const RoundedRectangleBorder(borderRadius: _radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: const BorderSide(color: AppColors.line, width: 1.2),
          textStyle: buttonText,
          shape: const RoundedRectangleBorder(borderRadius: _radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: buttonText.copyWith(fontSize: 14),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : AppColors.surface),
          foregroundColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : AppColors.ink),
          side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.line)),
          textStyle: const WidgetStatePropertyAll(TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 13.5)),
          minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.fill,
        side: BorderSide.none,
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 8),
        labelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.ink),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.ink,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.fill,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : AppColors.subtle,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? AppColors.ink
                  : AppColors.subtle,
            )),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18))),
        extendedTextStyle: TextStyle(
            fontFamily: fontFamily, fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.ink,
        collapsedIconColor: AppColors.muted,
        shape: Border(),
        collapsedShape: Border(),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Color(0x33000000),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        actionTextColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14))),
        contentTextStyle: TextStyle(
            fontFamily: fontFamily,
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(26))),
        titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
            color: AppColors.ink),
        contentTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            height: 1.45,
            color: AppColors.muted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        dragHandleColor: AppColors.line,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.ink,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(26))),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.all(Radius.circular(8))),
        textStyle: TextStyle(
            fontFamily: fontFamily, color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.fill,
        circularTrackColor: Colors.transparent,
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: AppColors.ink,
      secondary: Colors.white,
      onSecondary: AppColors.ink,
      surface: AppColors.ink,
      onSurface: Colors.white,
      error: AppColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.ink,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: darkChrome,
      ),
    );
  }
}
