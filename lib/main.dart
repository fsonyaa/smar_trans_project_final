import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/chauffeurdashboard.dart';
import 'pages/clientdashboard.dart';
import 'pages/current_user.dart';
import 'pages/forgot_password_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await CurrentUser.loadSession();
  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _getInitialPage() {
    if (CurrentUser.email.isEmpty) {
      return const LoginPage();
    }

    switch (CurrentUser.role) {
      case 'admin':
        return AdminDashboard(adminEmail: CurrentUser.email);
      case 'chauffeur':
        return ChauffeurDashboard(driverId: CurrentUser.id, userEmail: CurrentUser.email);
      case 'client':
        return ClientDashboard(clientId: CurrentUser.id, userEmail: CurrentUser.email);
      default:
        return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart-Trans',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: false,
      ),
      locale: context.watch<LanguageProvider>().locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      home: _getInitialPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/admin_dashboard': (context) => AdminDashboard(adminEmail: CurrentUser.email),
      },
    );
  }
}