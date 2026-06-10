import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/firebase_auth_service.dart';

class BusListPage extends StatefulWidget {
  const BusListPage({super.key});

  @override
  State<BusListPage> createState() => _BusListPageState();
}

class _BusListPageState extends State<BusListPage> {
  List<Map<String, dynamic>> busList = [];
  List<Map<String, dynamic>> chauffeursList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final buses = await FirestoreService.getBuses();
      final chauffeurs = await FirebaseAuthService.getAllChauffeurs();

      if (mounted) {
        setState(() {
          busList = buses;
          chauffeursList = chauffeurs;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur Fetch Data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteBus(String id) async {
    try {
      await FirestoreService.deleteBus(id);
      fetchData();
    } catch (e) {
      debugPrint("Erreur Delete: $e");
    }
  }

  void _showBusDialog({Map<String, dynamic>? bus}) {
    TextEditingController numCtrl = TextEditingController(text: bus?['Numero_bus']?.toString() ?? '');
    TextEditingController etatCtrl = TextEditingController(text: bus?['Etat']?.toString() ?? '');
    
    String? selectedChauffeurId = bus?['Code_chauffeur']?.toString();
    if (selectedChauffeurId != null && !chauffeursList.any((c) => c['uid'] == selectedChauffeurId)) {
      selectedChauffeurId = null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(bus == null ? "Ajouter un Bus" : "Modifier le Bus"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: numCtrl, decoration: const InputDecoration(labelText: "Numéro du Bus")),
                TextField(controller: etatCtrl, decoration: const InputDecoration(labelText: "Etat")),
                const SizedBox(height: 20),

                chauffeursList.isEmpty
                    ? const Text("⚠️ Aucun chauffeur. Ajoutez-en un d'abord!", style: TextStyle(color: Colors.red, fontSize: 12))
                    : DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Assigner à un Chauffeur", border: OutlineInputBorder()),
                        value: selectedChauffeurId,
                        items: chauffeursList.map((c) => DropdownMenuItem<String>(
                          value: c['uid'].toString(),
                          child: Text(c['nom']?.toString() ?? 'Inconnu'),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedChauffeurId = val),
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                if (numCtrl.text.isEmpty) return;
                
                try {
                  if (bus == null) {
                    await FirestoreService.addBus(
                      numeroBus: numCtrl.text,
                      etat: etatCtrl.text,
                      codeChauffeur: selectedChauffeurId,
                    );
                  } else {
                    await FirestoreService.updateBus(
                      busId: bus['Code_bus'],
                      numeroBus: numCtrl.text,
                      etat: etatCtrl.text,
                      codeChauffeur: selectedChauffeurId,
                    );
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    fetchData();
                  }
                } catch (e) {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur"), backgroundColor: Colors.red));
                   }
                }
              },
              child: Text(bus == null ? "Ajouter" : "Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestion du Parc Bus"), backgroundColor: Colors.orange[800]),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : busList.isEmpty
              ? const Center(child: Text("Aucun bus trouvé"))
              : ListView.builder(
                  itemCount: busList.length,
                  itemBuilder: (context, index) {
                    final bus = busList[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.directions_bus, color: Colors.orange),
                        title: Text("Bus N°: ${bus['Numero_bus']}"),
                        subtitle: Text("Etat: ${bus['Etat']} | ID Chauffeur: ${bus['Code_chauffeur'] ?? 'Pas assigné'}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showBusDialog(bus: bus)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => deleteBus(bus['Code_bus'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBusDialog(),
        backgroundColor: Colors.orange[800],
        child: const Icon(Icons.add),
      ),
    );
  }
}