import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../l10n/generated/app_localizations.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  bool isLoading = false;
  bool emailSent = false;

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> sendResetEmail() async {
    if (emailController.text.isEmpty) {
      _showSnackBar("Veuillez entrer votre email", Colors.orange);
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuthService.resetPassword(emailController.text);
      setState(() => emailSent = true);
      _showSnackBar(
        "Email de réinitialisation envoyé ! Vérifiez votre boîte mail.",
        Colors.green,
      );
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst("Exception: ", ""), Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPassword),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emailSent ? Icons.mark_email_read : Icons.lock_reset,
              size: 80,
              color: emailSent ? Colors.green : Colors.teal,
            ),
            const SizedBox(height: 20),
            Text(
              emailSent
                  ? "Email envoyé ! Vérifiez votre boîte mail et suivez le lien pour réinitialiser votre mot de passe."
                  : "Entrez votre email pour recevoir un lien de réinitialisation de mot de passe.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: emailSent ? Colors.green[700] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 30),
            if (!emailSent) ...[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 25),
              isLoading
                  ? const CircularProgressIndicator(color: Colors.teal)
                  : ElevatedButton(
                      onPressed: sendResetEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.sendCode,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
            ],
            if (emailSent) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Retour à la connexion"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: sendResetEmail,
                child: const Text(
                  "Renvoyer l'email",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
