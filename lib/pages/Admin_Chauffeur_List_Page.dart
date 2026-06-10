import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

class AdminChauffeurListPage extends StatefulWidget {
  const AdminChauffeurListPage({super.key});

  @override
  State<AdminChauffeurListPage> createState() => _AdminChauffeurListPageState();
}

class _AdminChauffeurListPageState extends State<AdminChauffeurListPage> {
  List<Map<String, dynamic>> allChauffeurs = [];
  List<Map<String, dynamic>> filteredChauffeurs = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  TextEditingController nomController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchChauffeurs();
  }

  Future<void> fetchChauffeurs() async {
    setState(() => isLoading = true);
    try {
      final data = await FirebaseAuthService.getAllChauffeurs();
      if (mounted) {
        setState(() {
          allChauffeurs = data;
          filteredChauffeurs = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("Erreur fetch chauffeurs: $e");
    }
  }

  Future<void> addChauffeur() async {
    try {
      await FirebaseAuthService.addChauffeur(
        nomController.text,
        emailController.text,
        passwordController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chauffeur ajouté ✅"), backgroundColor: Colors.green));
        fetchChauffeurs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> updateChauffeur(String uid) async {
    try {
      await FirebaseAuthService.updateChauffeurData(
        uid: uid,
        nom: nomController.text,
        email: emailController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mis à jour réussi ✅"), backgroundColor: Colors.green));
        fetchChauffeurs();
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de mise à jour"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> deleteChauffeur(String uid) async {
    try {
      await FirebaseAuthService.deleteUserDoc(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chauffeur supprimé ✅"), backgroundColor: Colors.red));
        fetchChauffeurs();
      }
    } catch (e) {
       debugPrint("Erreur delete: $e");
    }
  }

  void showFormDialog({Map<String, dynamic>? chauffeur}) {
    if (chauffeur != null) {
      nomController.text = chauffeur['nom'] ?? "";
      emailController.text = chauffeur['email'] ?? "";
      passwordController.clear();
    } else {
      nomController.clear();
      emailController.clear();
      passwordController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chauffeur == null ? "Ajouter Chauffeur" : "Modifier Chauffeur"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomController, decoration: const InputDecoration(labelText: "Nom")),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
              if (chauffeur == null) 
                TextField(
                  controller: passwordController, 
                  decoration: const InputDecoration(labelText: "Mot de passe"), 
                  obscureText: true
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              if (chauffeur == null) {
                addChauffeur();
              } else {
                updateChauffeur(chauffeur['uid']);
              }
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestion des Chauffeurs"), backgroundColor: Colors.teal),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: searchController,
              onChanged: (v) => setState(() {
                filteredChauffeurs = allChauffeurs.where((c) => 
                  (c['nom'] ?? '').toString().toLowerCase().contains(v.toLowerCase())
                ).toList();
              }),
              decoration: InputDecoration(
                hintText: "Rechercher...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredChauffeurs.isEmpty
                    ? const Center(child: Text("Aucun chauffeur trouvé"))
                    : ListView.builder(
                        itemCount: filteredChauffeurs.length,
                        itemBuilder: (context, index) {
                          final c = filteredChauffeurs[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                              title: Text(c['nom'] ?? ""),
                              subtitle: Text(c['email'] ?? "Pas d'email"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue), 
                                    onPressed: () => showFormDialog(chauffeur: c)
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red), 
                                    onPressed: () => deleteChauffeur(c['uid'])
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showFormDialog(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}