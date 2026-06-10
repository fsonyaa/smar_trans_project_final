import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../language_provider.dart';
import '../services/firebase_auth_service.dart';
import 'current_user.dart';
import 'clientdashboard.dart';
import 'chauffeurdashboard.dart';
import 'admin_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  Future<void> login() async {
    final l10n = AppLocalizations.of(context)!;
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackBar(
        l10n.localeName == 'fr' ? "Veuillez remplir tous les champs" : "Please fill all fields",
        Colors.orange,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userData = await FirebaseAuthService.login(
        emailController.text,
        passwordController.text,
      );

      final String nom   = userData['nom']   ?? 'Utilisateur';
      final String photo = userData['photo'] ?? '';
      final int    id    = userData['id']    ?? 0;
      final String email = userData['email'] ?? '';
      final String role  = userData['role']  ?? '';
      final String uid   = userData['uid']   ?? '';

      debugPrint("✅ Login Firebase OK: nom=$nom | role=$role | uid=$uid");

      if (role.isEmpty) {
        _showSnackBar("Rôle introuvable. Contactez l'administrateur.", Colors.red);
        return;
      }

      await CurrentUser.saveSession(
        email, role, id,
        userNom: nom,
        userPhoto: photo,
        userUid: uid,
      );

      _showSnackBar("${l10n.welcome} $nom", Colors.green);

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      if (role == "client") {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ClientDashboard(clientId: id, userEmail: email)));
      } else if (role == "chauffeur") {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ChauffeurDashboard(driverId: id, userEmail: email)));
      } else if (role == "admin") {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AdminDashboard(adminEmail: email)));
      } else {
        _showSnackBar("Rôle inconnu: '$role'", Colors.red);
      }

    } catch (e) {
      debugPrint("❌ Login Error: $e");
      _showSnackBar(e.toString().replaceFirst("Exception: ", ""), Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildLanguageButton(context, langProvider, 'FR', 'fr'),
          _buildLanguageButton(context, langProvider, 'EN', 'en'),
          _buildLanguageButton(context, langProvider, 'AR', 'ar'),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_bus, size: 90, color: Colors.teal),
                const SizedBox(height: 10),
                Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    prefixIcon: const Icon(Icons.email, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 30),
                isLoading
                    ? const CircularProgressIndicator(color: Colors.teal)
                    : ElevatedButton(
                        onPressed: login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.login,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                  child: Text(l10n.forgotPassword,
                      style: const TextStyle(color: Colors.teal)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text(l10n.noAccount,
                      style: const TextStyle(color: Colors.teal)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(
      BuildContext context, LanguageProvider provider, String label, String code) {
    bool isSelected = provider.locale.languageCode == code;
    return TextButton(
      onPressed: () => provider.changeLanguage(code),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.teal : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
