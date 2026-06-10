import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nomController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool isLoading = false;
  bool _obscure = true;

  Future<void> register() async {
    if (nomController.text.isEmpty ||
        emailController.text.isEmpty ||
        passController.text.isEmpty) {
      _showMsg("Veuillez remplir tous les champs", Colors.orange);
      return;
    }
    if (passController.text.length < 6) {
      _showMsg("Mot de passe: minimum 6 caractères", Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuthService.register(
        nomController.text,
        emailController.text,
        passController.text,
      );

      _showMsg("Compte créé avec succès ✅", Colors.green);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMsg(e.toString().replaceFirst("Exception: ", ""), Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMsg(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: col,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    nomController.dispose();
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Créer un compte"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 70, color: Colors.teal),
              const SizedBox(height: 20),
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: "Nom complet",
                  prefixIcon: const Icon(Icons.person, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
              isLoading
                  ? const CircularProgressIndicator(color: Colors.teal)
                  : ElevatedButton(
                      onPressed: register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "S'inscrire",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}