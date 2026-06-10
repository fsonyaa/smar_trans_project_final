import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../services/firebase_auth_service.dart';
import 'current_user.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;

  const ProfilePage({
    super.key,
    required this.userEmail,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isPickingImage = false;
  bool _obscurePassword = true;
  
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final data = await FirebaseAuthService.getProfile(CurrentUser.uid);
      if (mounted) {
        setState(() {
          if (data != null) {
            _nameController.text = data["nom"] ?? CurrentUser.nom;
            _emailController.text = data["email"] ?? CurrentUser.email;
            _base64Image = data["photo"] != '' ? data["photo"] : CurrentUser.photo;
          } else {
            _nameController.text = CurrentUser.nom;
            _emailController.text = CurrentUser.email;
            _base64Image = CurrentUser.photo;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      await FirebaseAuthService.updateProfile(
        uid: CurrentUser.uid,
        nom: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
        photo: _base64Image,
      );

      await CurrentUser.saveSession(
        _emailController.text.trim(),
        CurrentUser.role,
        CurrentUser.id,
        userNom: _nameController.text.trim(),
        userPhoto: _base64Image ?? "",
        userUid: CurrentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil mis à jour avec succès"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _logout() async {
    await CurrentUser.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade800, Colors.teal.shade50],
            stops: const [0.0, 0.4],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      _buildAppBar(),
                      const SizedBox(height: 30),
                      _buildProfileHeader(),
                      const SizedBox(height: 30),
                      _buildEditForm(),
                      const SizedBox(height: 40),
                      _buildLogoutButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const Text(
          "Mon Profil",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: (_base64Image != null && _base64Image!.isNotEmpty)
                      ? MemoryImage(base64Decode(_base64Image!)) 
                      : null,
                  child: (_base64Image == null || _base64Image!.isEmpty)
                      ? const Icon(Icons.person, size: 80, color: Colors.teal)
                      : null,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          CurrentUser.role.toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.teal.shade700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Card(
        elevation: 8,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Informations Personnelles",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _nameController,
                label: "Nom Complet",
                icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? "Champ requis" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: "Email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? "Champ requis" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: "Changer le Mot de passe",
                hint: "Saisissez pour changer",
                icon: Icons.lock_outline,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v!.isNotEmpty && v.length < 6) return "Min 6 caractères";
                  return null;
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "Note: Pour des raisons de sécurité, l'ancien mot de passe n'est pas affiché.",
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isUpdating ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "ENREGISTRER LES MODIFICATIONS",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.teal),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text(
          "DÉCONNEXION",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}