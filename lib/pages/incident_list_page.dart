import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class IncidentListPage extends StatefulWidget {
  const IncidentListPage({super.key});

  @override
  State<IncidentListPage> createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  List<Map<String, dynamic>> incidents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchIncidents();
  }

  Future<void> fetchIncidents() async {
    setState(() => isLoading = true);
    try {
      final data = await FirestoreService.getAllIncidents();
      if (mounted) {
        setState(() {
          incidents = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur incidents: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> updateIncidentStatus(String id, String newStatus, int isCritique) async {
    try {
      await FirestoreService.updateIncidentStatus(
        incidentId: id,
        statut: newStatus,
        critique: isCritique,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action enregistrée ✅")));
        fetchIncidents();
      }
    } catch (e) {
      debugPrint("Erreur update: $e");
    }
  }

  void _showActionMenu(Map<String, dynamic> incident) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              Text("Actions - Incident", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text("Consulter les détails"),
                onTap: () {
                  Navigator.pop(context);
                  _showDetailsDialog(incident);
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: const Text("Marquer comme Résolu"),
                onTap: () {
                  Navigator.pop(context);
                  updateIncidentStatus(incident['ID_incident'], "Résolu", 0);
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text("Marquer comme CRITIQUE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  updateIncidentStatus(incident['ID_incident'], "En cours", 1);
                },
              ),

              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Supprimer l'alerte", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletion(incident['ID_incident']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletion(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Voulez-vous vraiment supprimer cette alerte ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteIncident(id);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> deleteIncident(String id) async {
    try {
      await FirestoreService.deleteIncident(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alerte supprimée 🗑️")));
        fetchIncidents();
      }
    } catch (e) {
      debugPrint("Erreur delete: $e");
    }
  }

  void _showDetailsDialog(Map<String, dynamic> incident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Détails de l'incident"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📍 Parcours: ${incident['Nom_Ligne'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("🚌 Bus Numero: ${incident['Numero_bus'] ?? 'Non assigné'}"),
            Text("🕒 Date: ${incident['Date']}"),
            Text("📝 Description: ${incident['Description']}"),
            const SizedBox(height: 10),
            Text(
              "Statut actuel: ${incident['Statut'] ?? 'Nouveau'}", 
              style: const TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Incidents", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        elevation: 0,
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: fetchIncidents,
              child: incidents.isEmpty 
                  ? const Center(child: Text("Aucun incident à traiter"))
                  : ListView.builder(
                      itemCount: incidents.length,
                      itemBuilder: (context, index) {
                        final incident = incidents[index];
                        bool isCritique = incident['Critique'] == 1 || incident['Performance_IA'] == 1;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isCritique ? Colors.red : Colors.transparent, width: 2),
                          ),
                          child: ListTile(
                            onTap: () => _showActionMenu(incident),
                            leading: CircleAvatar(
                              backgroundColor: isCritique ? Colors.red : Colors.orange[100],
                              child: Icon(isCritique ? Icons.priority_high : Icons.warning, color: isCritique ? Colors.white : Colors.orange[900]),
                            ),
                            title: Text("Bus N°: ${incident['Numero_bus'] ?? 'Non assigné'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(incident['Description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.more_vert),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}