import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/progress_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';   // NEW
import 'screens/verify_otp_screen.dart';         // NEW
import 'screens/reset_password_screen.dart';     // NEW
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final auth = AuthProvider();
  await auth.loadFromStorage();

  runApp(WorkoutApp(auth: auth));
}

class WorkoutApp extends StatelessWidget {
  final AuthProvider auth;
  const WorkoutApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => RoutineProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
      ],
      child: MaterialApp(
        title: 'AI Workout',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        initialRoute: '/splash',
        routes: {
          '/splash':           (_) => const SplashScreen(),
          '/login':            (_) => const LoginScreen(),
          '/signup':           (_) => const SignupScreen(),
          '/forgot-password':  (_) => const ForgotPasswordScreen(),   // NEW
          '/verify-otp':       (_) => const VerifyOtpScreen(),        // NEW
          '/reset-password':   (_) => const ResetPasswordScreen(),    // NEW
          '/onboarding':       (_) => const OnboardingScreen(),
          '/home':             (_) => const HomeScreen(),
          '/routine':          (_) => const RoutineScreen(),
          '/progress':         (_) => const ProgressScreen(),
          '/profile':          (_) => const ProfileScreen(),
        },
        onUnknownRoute: (_) =>
            MaterialPageRoute(builder: (_) => const LoginScreen()),
      ),
    );
  }

  ThemeData _buildTheme() {
    const primary = Color(0xFF6C5CE7);
    const accent  = Color(0xFF00CEC9);
    const bg      = Color(0xFF0F0F1E);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary, brightness: Brightness.dark,
        primary: primary, secondary: accent,
        surface: const Color(0xFF1A1A2E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E), elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2)),
        labelStyle: const TextStyle(color: Colors.white70),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accent)),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? primary : Colors.transparent),
        side: const BorderSide(color: Colors.white54, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    );
  }
}