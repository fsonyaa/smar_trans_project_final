import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'AdminAddParcoursPage.dart';

class AdminParcoursListPage extends StatefulWidget {
  const AdminParcoursListPage({super.key});

  @override
  State<AdminParcoursListPage> createState() => _AdminParcoursListPageState();
}

class _AdminParcoursListPageState extends State<AdminParcoursListPage> {
  List<Map<String, dynamic>> parcoursList = [];
  List<Map<String, dynamic>> lignes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final pList = await FirestoreService.getAllParcours();
      final lList = await FirestoreService.getAllLignes();
      if (mounted) {
        setState(() {
          parcoursList = pList;
          lignes = lList;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur fetch: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteParcours(String id) async {
    try {
      await FirestoreService.deleteParcours(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Parcours supprimé ✅"), backgroundColor: Colors.green),
        );
        fetchData();
      }
    } catch (e) {
      debugPrint("Erreur delete: $e");
    }
  }

  void _showEditDialog(Map<String, dynamic> p) {
    TextEditingController departCtrl = TextEditingController(text: p['Depart'] ?? '');
    TextEditingController arriveeCtrl = TextEditingController(text: p['Arrivee'] ?? '');
    TextEditingController hDepartCtrl = TextEditingController(text: p['Heure_depart'] ?? '');
    TextEditingController hArriveeCtrl = TextEditingController(text: p['Heure_arrivee'] ?? '');
    String? selectedLigne = p['Code_Ligne']?.toString();
    
    if (selectedLigne != null && !lignes.any((l) => l['code_ligne'] == selectedLigne)) {
      selectedLigne = null;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text("Modifier le Parcours", style: TextStyle(color: Colors.teal[800])),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedLigne,
                  decoration: const InputDecoration(labelText: "Ligne"),
                  items: lignes.map((l) => DropdownMenuItem<String>(
                    value: l['code_ligne'].toString(),
                    child: Text(l['libelle'] ?? "Ligne"),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedLigne = val),
                ),
                TextField(controller: departCtrl, decoration: const InputDecoration(labelText: "Départ")),
                TextField(controller: arriveeCtrl, decoration: const InputDecoration(labelText: "Arrivée")),
                TextField(
                  controller: hDepartCtrl, 
                  decoration: const InputDecoration(labelText: "Heure Départ (HH:mm)"),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (picked != null) {
                      hDepartCtrl.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                    }
                  },
                ),
                TextField(
                  controller: hArriveeCtrl, 
                  decoration: const InputDecoration(labelText: "Heure Arrivée (HH:mm)"),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (picked != null) {
                      hArriveeCtrl.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                try {
                  await FirestoreService.updateParcours(
                    parcoursId: p['ID_parcours'],
                    depart: departCtrl.text,
                    arrivee: arriveeCtrl.text,
                    heureDepart: hDepartCtrl.text,
                    heureArrivee: hArriveeCtrl.text,
                    codeLigne: selectedLigne ?? '',
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    fetchData();
                  }
                } catch (e) {
                   debugPrint("Error updating parcours: $e");
                }
              },
              child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Parcours"),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : parcoursList.isEmpty
              ? const Center(child: Text("Aucun parcours programmé"))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: parcoursList.length,
                  itemBuilder: (context, index) {
                    final p = parcoursList[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal[50],
                          child: const Icon(Icons.route, color: Colors.teal),
                        ),
                        title: Text("${p['Depart']} ➔ ${p['Arrivee']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Ligne: ${p['Nom_Ligne']}\nHeure: ${p['Heure_depart']} - ${p['Heure_arrivee']}"),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditDialog(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Supprimer ?"),
                                    content: const Text("Voulez-vous vraiment supprimer ce parcours ?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Non")),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          deleteParcours(p['ID_parcours']);
                                        },
                                        child: const Text("Oui", style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAddParcoursPage())).then((_) => fetchData());
        },
        backgroundColor: Colors.teal[700],
        child: const Icon(Icons.add),
      ),
    );
  }
}
