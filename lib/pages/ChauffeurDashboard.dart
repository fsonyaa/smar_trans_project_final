import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/firebase_auth_service.dart';
import 'current_user.dart';
import 'login_page.dart';

class ChauffeurDashboard extends StatefulWidget {
  final int driverId;
  final String userEmail;

  const ChauffeurDashboard({super.key, required this.driverId, required this.userEmail});

  @override
  State<ChauffeurDashboard> createState() => _ChauffeurDashboardState();
}

class _ChauffeurDashboardState extends State<ChauffeurDashboard> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> reviews = [];
  Map<String, dynamic> driverStats = {};
  bool isLoading = true;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    try {
      final uid = CurrentUser.uid;
      
      final asg = await FirestoreService.getMyAssignments(uid);
      final rev = await FirestoreService.getDriverReviews(uid);
      final stats = await FirestoreService.getDriverStats(uid);

      if (mounted) {
        setState(() {
          assignments = asg;
          reviews = rev;
          if (stats.isNotEmpty) {
            driverStats = stats.first;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur Chauffeur Data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleAction(String parcoursId, String action, {String? depart, String? arrivee}) async {
    try {
      await FirestoreService.logHistorique(
        driverUid: CurrentUser.uid,
        parcoursId: parcoursId,
        action: action,
        depart: depart,
        arrivee: arrivee,
        timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Parcours $action ✅"), backgroundColor: Colors.green)
        );
      }
      fetchAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'enregistrement ❌"), backgroundColor: Colors.red)
        );
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 512, 
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        String base64 = base64Encode(bytes);
        setState(() {
          CurrentUser.photo = base64;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    } finally {
      _isPickingImage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildParcoursTab(),
      _buildIncidentTab(),
      _buildReviewsTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon Espace Chauffeur"),
        backgroundColor: Colors.teal[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            onPressed: () async {
              await CurrentUser.clearSession();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal[800],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: "Parcours"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Incident"),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "Avis"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }

  Widget _buildParcoursTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          width: double.infinity,
          color: Colors.teal[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Mes Lignes Assignées:", style: TextStyle(fontSize: 12, color: Colors.teal[700])),
              Text(
                assignments.isNotEmpty 
                  ? assignments.map((a) => a['Libelle']).toSet().join(" | ") 
                  : 'Aucune ligne assignée', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal[900])
              ),
            ],
          ),
        ),
        Expanded(
          child: assignments.isEmpty
            ? const Center(child: Text("Aucun parcours programmé"))
            : ListView.builder(
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                var p = assignments[index];
                bool hasTrip = p['ID_parcours'] != null;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.location_on, color: hasTrip ? Colors.teal : Colors.grey),
                    title: Text(
                      hasTrip ? "${p['Depart']} ➔ ${p['Arrivee']}" : "Aucun trajet programmé", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: hasTrip ? Colors.black : Colors.grey)
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ligne: ${p['Libelle']}", style: const TextStyle(fontSize: 12, color: Colors.teal)),
                        if (hasTrip) Text("Horaire: ${p['Heure_depart']} - ${p['Heure_arrivee']}"),
                      ],
                    ),
                    trailing: !hasTrip ? null : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p['Statut'] == 'Pas démarré')
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: Colors.green), 
                            onPressed: () => handleAction(p['ID_parcours'], "Début", depart: p['Depart'], arrivee: p['Arrivee'])
                          ),
                        if (p['Statut'] == 'En cours')
                          IconButton(
                            icon: const Icon(Icons.stop_circle, color: Colors.red), 
                            onPressed: () => handleAction(p['ID_parcours'], "Fin")
                          ),
                        if (p['Statut'] == 'Terminé')
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.blue),
                              Text("Terminé", style: TextStyle(color: Colors.blue, fontSize: 10)),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ),
      ],
    );
  }

  Widget _buildIncidentTab() {
    TextEditingController desc = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: desc, decoration: const InputDecoration(labelText: "Description de l'incident"), maxLines: 3),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (desc.text.isEmpty) return;
              try {
                await FirestoreService.declareIncident(
                  driverUid: CurrentUser.uid,
                  description: desc.text,
                  timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                );
                desc.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signalé au central 🚨")));
                }
              } catch (e) {
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur ❌")));
                 }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
            child: const Text("Déclarer l'incident"),
          )
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return reviews.isEmpty 
    ? const Center(child: Text("Pas encore d'avis clients"))
    : ListView.builder(
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          var r = reviews[index];
          String sentiment = r['sentiment'] ?? "Neutre";
          Color sColor = sentiment == "Positif" ? Colors.green : (sentiment == "Négatif" ? Colors.red : Colors.orange);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(r['commentaire'] ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Note: ${r['note']}/5"),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: sColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                        child: Text(sentiment, style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      if (r['category'] != null) ...[
                        const SizedBox(width: 8),
                        Text("📌 ${r['category']}", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      );
  }

  Widget _buildProfileTab() {
    final TextEditingController nameCtrl = TextEditingController(text: CurrentUser.nom);
    final TextEditingController emailCtrl = TextEditingController(text: widget.userEmail);
    final TextEditingController passCtrl = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.teal[800],
                  backgroundImage: CurrentUser.photo.isNotEmpty 
                      ? MemoryImage(base64Decode(CurrentUser.photo)) 
                      : null,
                  child: CurrentUser.photo.isEmpty 
                      ? const Icon(Icons.person, color: Colors.white, size: 50) 
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (driverStats.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.teal[800]!, Colors.teal[600]!]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Column(
                children: [
                  const Text("Score de Performance", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    "${driverStats['performance_score'] ?? 5.0} / 5",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat("Incidents", "${driverStats['incident_count'] ?? 0}"),
                      _buildMiniStat("Avis", "${reviews.length}"),
                    ],
                  )
                ],
              ),
            ),
          ],
          const SizedBox(height: 25),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Paramètres du compte", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: "Nom",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Nouveau mot de passe",
                      hintText: "Laisser vide si inchangé",
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await FirebaseAuthService.updateProfile(
                            uid: CurrentUser.uid,
                            nom: nameCtrl.text,
                            email: emailCtrl.text,
                            password: passCtrl.text.isEmpty ? null : passCtrl.text,
                            photo: CurrentUser.photo,
                          );
                          
                          await CurrentUser.saveSession(
                            emailCtrl.text, CurrentUser.role, CurrentUser.id, 
                            userNom: nameCtrl.text, userPhoto: CurrentUser.photo, userUid: CurrentUser.uid
                          );
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour ✅"), backgroundColor: Colors.green));
                            passCtrl.clear();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la mise à jour"), backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("METTRE À JOUR"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () async {
              await CurrentUser.clearSession();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
              }
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text("DÉCONNEXION", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}