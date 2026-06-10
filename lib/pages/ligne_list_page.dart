import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class LigneListPage extends StatefulWidget {
  const LigneListPage({super.key});

  @override
  State<LigneListPage> createState() => _LigneListPageState();
}

class _LigneListPageState extends State<LigneListPage> {
  List<Map<String, dynamic>> lignesList = [];
  List<Map<String, dynamic>> busesList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final lignes = await FirestoreService.getAllLignes();
      final buses = await FirestoreService.getBuses();
      
      if (mounted) {
        setState(() {
          lignesList = lignes;
          busesList = buses;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur Fetch Data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteLigne(String id) async {
    try {
      await FirestoreService.deleteLigne(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ligne supprimée")));
      }
      fetchData();
    } catch (e) {
      debugPrint("Erreur Delete Ligne: $e");
    }
  }

  void _showLigneDialog({Map<String, dynamic>? ligne}) {
    TextEditingController libelleCtrl = TextEditingController(text: ligne?['libelle'] ?? '');
    TextEditingController descCtrl = TextEditingController(text: ligne?['description'] ?? '');
    
    String? selectedBusId = ligne?['code_bus']?.toString();
    if (selectedBusId != null && !busesList.any((b) => b['Code_bus'] == selectedBusId)) {
      selectedBusId = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(ligne == null ? "Ajouter Ligne" : "Modifier Ligne"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: libelleCtrl,
                    decoration: const InputDecoration(labelText: "Libelle (Nom)"),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: "Description"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedBusId,
                    hint: const Text("Choisir Bus"),
                    items: busesList.map<DropdownMenuItem<String>>((bus) {
                      return DropdownMenuItem<String>(
                        value: bus['Code_bus'].toString(),
                        child: Text("Bus N° ${bus['Numero_bus'] ?? bus['Code_bus']}"),
                      );
                    }).toList(),
                    onChanged: (value) => setStateDialog(() => selectedBusId = value),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                ElevatedButton(
                  onPressed: () async {
                    if (libelleCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le libellé est obligatoire !")));
                      return;
                    }

                    try {
                      if (ligne == null) {
                        await FirestoreService.addLigne(
                          libelle: libelleCtrl.text,
                          description: descCtrl.text,
                          codeBus: selectedBusId,
                        );
                      } else {
                        await FirestoreService.updateLigne(
                          ligneId: ligne['code_ligne'],
                          libelle: libelleCtrl.text,
                          description: descCtrl.text,
                          codeBus: selectedBusId,
                        );
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        fetchData();
                      }
                    } catch (e) {
                      debugPrint("Erreur save Ligne: $e");
                    }
                  },
                  child: const Text("Enregistrer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Lignes"),
        backgroundColor: Colors.green,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: lignesList.length,
              itemBuilder: (context, index) {
                final item = lignesList[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.directions_bus, color: Colors.green),
                    title: Text(item['libelle'] ?? 'Sans Nom', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Description: ${item['description'] ?? ''}"),
                        Text("Bus: ${item['code_bus'] ?? 'N/A'}", style: const TextStyle(color: Colors.blueGrey)),
                        Text(
                          "Chauffeur: ${item['nom_chauffeur'] ?? 'Non assigné'}",
                          style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showLigneDialog(ligne: item)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => deleteLigne(item['code_ligne'])),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLigneDialog(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}