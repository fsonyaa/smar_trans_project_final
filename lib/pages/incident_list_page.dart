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


  /// Affiche le menu d'actions pour un incident (Détails, Résolu, Critique, Supprimer)
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
    final bool isCritique = incident['Critique'] == 1 || incident['Performance_IA'] == 1;
    final String? aiLabel = incident['AI_Label'];
    final String? aiKeywords = incident['AI_Keywords'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isCritique ? Icons.priority_high : Icons.info_outline,
                color: isCritique ? Colors.red : Colors.orange),
            const SizedBox(width: 8),
            const Text("Détails de l'incident"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow("📍 Parcours", incident['Nom_Ligne'] ?? 'N/A'),
            _detailRow("🚌 Bus Numero", incident['Numero_bus'] ?? 'Non assigné'),
            _detailRow("🕒 Date", incident['Date'] ?? 'N/A'),
            _detailRow("📝 Description", incident['Description'] ?? ''),
            _detailRow("📊 Statut", incident['Statut'] ?? 'Nouveau'),
            if (aiLabel != null) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.psychology, size: 16, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  Text("IA : $aiLabel", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            if (aiKeywords != null && aiKeywords.isNotEmpty)
              Text("🔑 Mots-clés : $aiKeywords", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (isCritique)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Text("⚠️ Incident critique", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: "$label : ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = incidents.where((i) => i['Statut'] == 'Nouveau' || i['Statut'] == 'Signale' || i['Statut'] == 'Signalé').length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Gestion des Incidents", style: TextStyle(fontWeight: FontWeight.bold)),
            if (pendingCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("$pendingCount", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.orange[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchIncidents),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: fetchIncidents,
              child: incidents.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 70, color: Colors.green[300]),
                          const SizedBox(height: 16),
                          Text("Aucun incident à traiter 🎉", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: incidents.length,
                      itemBuilder: (context, index) {
                        final incident = incidents[index];
                        bool isCritique = incident['Critique'] == 1 || incident['Performance_IA'] == 1;
                        bool isResolved = incident['Statut'] == 'Résolu';
                        final String? aiLabel = incident['AI_Label'];

                        Color cardBorderColor = isCritique
                            ? Colors.red
                            : isResolved
                                ? Colors.green
                                : Colors.orange[300]!;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: cardBorderColor, width: isCritique ? 2 : 1),
                          ),
                          elevation: isCritique ? 4 : 1,
                          child: ListTile(
                            onTap: () => _showActionMenu(incident),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isCritique 
                                  ? Colors.red 
                                  : isResolved 
                                      ? Colors.green[100] 
                                      : Colors.orange[100],
                              child: Icon(
                                isCritique ? Icons.priority_high : isResolved ? Icons.check : Icons.warning,
                                color: isCritique ? Colors.white : isResolved ? Colors.green : Colors.orange[900],
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Bus N°: ${incident['Numero_bus'] ?? 'Non assigné'}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // Badge statut
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isResolved ? Colors.green[50] : isCritique ? Colors.red[50] : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isResolved ? Colors.green : isCritique ? Colors.red : Colors.orange),
                                  ),
                                  child: Text(
                                    incident['Statut'] ?? 'Nouveau',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isResolved ? Colors.green : isCritique ? Colors.red : Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(incident['Description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (aiLabel != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.psychology, size: 11, color: Colors.deepPurple),
                                      const SizedBox(width: 3),
                                      Text(
                                        "IA : $aiLabel",
                                        style: const TextStyle(fontSize: 10, color: Colors.deepPurple),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.more_vert),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}