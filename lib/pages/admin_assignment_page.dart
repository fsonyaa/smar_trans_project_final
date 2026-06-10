import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/firebase_auth_service.dart';

/// Page d'assignation : Chauffeur ← Bus ← Ligne
/// L'admin peut voir et modifier qui conduit quel bus sur quelle ligne.
class AdminAssignmentPage extends StatefulWidget {
  const AdminAssignmentPage({super.key});

  @override
  State<AdminAssignmentPage> createState() => _AdminAssignmentPageState();
}

class _AdminAssignmentPageState extends State<AdminAssignmentPage> {
  List<Map<String, dynamic>> chauffeurs = [];
  List<Map<String, dynamic>> buses = [];
  List<Map<String, dynamic>> lignes = [];
  bool isLoading = true;

  // Résumé des assignations : chauffeurUid → { bus, ligne }
  List<Map<String, dynamic>> assignmentSummary = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final c = await FirebaseAuthService.getAllChauffeurs();
      final b = await FirestoreService.getBuses();
      final l = await FirestoreService.getLignes();

      // Construire le résumé d'assignations
      final List<Map<String, dynamic>> summary = [];
      for (var chauffeur in c) {
        final uid = chauffeur['uid'] ?? '';
        // Trouver le bus assigné à ce chauffeur
        final assignedBus = b.where((bus) => bus['Code_chauffeur'] == uid).toList();
        
        for (var bus in assignedBus) {
          final busId = bus['Code_bus'] ?? '';
          // Trouver la ligne associée à ce bus
          final assignedLigne = l.where((ligne) => ligne['code_bus'] == busId).toList();
          
          if (assignedLigne.isNotEmpty) {
            for (var ligne in assignedLigne) {
              summary.add({
                'chauffeur_uid': uid,
                'chauffeur_nom': chauffeur['nom'] ?? 'Inconnu',
                'chauffeur_email': chauffeur['email'] ?? '',
                'bus_id': busId,
                'bus_numero': bus['Numero_bus'] ?? 'N/A',
                'bus_etat': bus['Etat'] ?? '',
                'ligne_id': ligne['Code_Ligne'] ?? ligne['code_ligne'] ?? '',
                'ligne_libelle': ligne['Libelle'] ?? ligne['libelle'] ?? '',
              });
            }
          } else {
            // Chauffeur a un bus mais pas de ligne assignée
            summary.add({
              'chauffeur_uid': uid,
              'chauffeur_nom': chauffeur['nom'] ?? 'Inconnu',
              'chauffeur_email': chauffeur['email'] ?? '',
              'bus_id': busId,
              'bus_numero': bus['Numero_bus'] ?? 'N/A',
              'bus_etat': bus['Etat'] ?? '',
              'ligne_id': null,
              'ligne_libelle': null,
            });
          }
        }
        
        if (assignedBus.isEmpty) {
          // Chauffeur sans bus
          summary.add({
            'chauffeur_uid': uid,
            'chauffeur_nom': chauffeur['nom'] ?? 'Inconnu',
            'chauffeur_email': chauffeur['email'] ?? '',
            'bus_id': null,
            'bus_numero': null,
            'bus_etat': null,
            'ligne_id': null,
            'ligne_libelle': null,
          });
        }
      }

      if (mounted) {
        setState(() {
          chauffeurs = c;
          buses = b;
          lignes = l;
          assignmentSummary = summary;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur fetchData assignation: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Dialogue pour modifier l'assignation : choisir bus + ligne pour un chauffeur
  void _showAssignDialog(Map<String, dynamic> assignment) {
    String? selectedBusId = assignment['bus_id'];
    String? selectedLigneId = assignment['ligne_id'];
    final chauffeurUid = assignment['chauffeur_uid'];
    final chauffeurNom = assignment['chauffeur_nom'];

    // Valider que les IDs existent encore
    if (selectedBusId != null && !buses.any((b) => b['Code_bus'] == selectedBusId)) {
      selectedBusId = null;
    }
    if (selectedLigneId != null && !lignes.any((l) => (l['Code_Ligne'] ?? l['code_ligne']) == selectedLigneId)) {
      selectedLigneId = null;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.teal[100],
                child: Icon(Icons.person, color: Colors.teal[800]),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Assignation\n$chauffeurNom', style: TextStyle(fontSize: 15, color: Colors.teal[900]))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Assigner un Bus :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedBusId,
                hint: const Text('Aucun bus'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.directions_bus, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('— Aucun bus —')),
                  ...buses.map((b) => DropdownMenuItem<String>(
                    value: b['Code_bus'].toString(),
                    child: Text('Bus N°${b['Numero_bus']} (${b['Etat']})'),
                  )),
                ],
                onChanged: (val) => setStateDialog(() {
                  selectedBusId = val;
                  selectedLigneId = null; // Reset ligne quand bus change
                }),
              ),
              const SizedBox(height: 16),
              const Text('2. Assigner une Ligne :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedLigneId,
                hint: const Text('Aucune ligne'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.map, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('— Aucune ligne —')),
                  ...lignes.map((l) => DropdownMenuItem<String>(
                    value: (l['Code_Ligne'] ?? l['code_ligne']).toString(),
                    child: Text(l['Libelle'] ?? l['libelle'] ?? 'Ligne'),
                  )),
                ],
                onChanged: (val) => setStateDialog(() => selectedLigneId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
              onPressed: () async {
                try {
                  // 1. D'abord, retirer ce chauffeur de tous les bus
                  for (var bus in buses) {
                    if (bus['Code_chauffeur'] == chauffeurUid) {
                      await FirestoreService.updateBus(
                        busId: bus['Code_bus'],
                        numeroBus: bus['Numero_bus']?.toString() ?? '',
                        etat: bus['Etat']?.toString() ?? '',
                        codeChauffeur: null,
                      );
                    }
                  }

                  // 2. Assigner le nouveau bus au chauffeur
                  if (selectedBusId != null) {
                    final bus = buses.firstWhere((b) => b['Code_bus'] == selectedBusId);
                    await FirestoreService.updateBus(
                      busId: selectedBusId!,
                      numeroBus: bus['Numero_bus']?.toString() ?? '',
                      etat: bus['Etat']?.toString() ?? '',
                      codeChauffeur: chauffeurUid,
                    );

                    // 3. Retirer le bus de toutes les lignes d'abord
                    for (var ligne in lignes) {
                      if (ligne['code_bus'] == selectedBusId) {
                        await FirestoreService.updateLigne(
                          ligneId: ligne['Code_Ligne'] ?? ligne['code_ligne'],
                          libelle: ligne['Libelle'] ?? ligne['libelle'] ?? '',
                          description: ligne['description'] ?? '',
                          codeBus: null,
                        );
                      }
                    }

                    // 4. Assigner la ligne au bus (si sélectionnée)
                    if (selectedLigneId != null) {
                      final ligne = lignes.firstWhere(
                        (l) => (l['Code_Ligne'] ?? l['code_ligne']) == selectedLigneId,
                      );
                      await FirestoreService.updateLigne(
                        ligneId: selectedLigneId!,
                        libelle: ligne['Libelle'] ?? ligne['libelle'] ?? '',
                        description: ligne['description'] ?? '',
                        codeBus: selectedBusId,
                      );
                    }
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Assignation mise à jour ✅'), backgroundColor: Colors.green),
                    );
                    fetchData();
                  }
                } catch (e) {
                  debugPrint('Erreur assignation: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Assignations Chauffeur ↔ Bus ↔ Ligne'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : assignmentSummary.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      Text('Aucun chauffeur trouvé', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: fetchData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Légende
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: Colors.teal[50],
                      child: Row(
                        children: [
                          _buildLegendItem(Colors.green, 'Complet'),
                          const SizedBox(width: 16),
                          _buildLegendItem(Colors.orange, 'Bus sans ligne'),
                          const SizedBox(width: 16),
                          _buildLegendItem(Colors.red, 'Non assigné'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: assignmentSummary.length,
                        itemBuilder: (context, index) {
                          final item = assignmentSummary[index];
                          final bool hasbus = item['bus_id'] != null;
                          final bool hasLigne = item['ligne_id'] != null;

                          Color statusColor = hasbus && hasLigne
                              ? Colors.green
                              : hasbus
                                  ? Colors.orange
                                  : Colors.red;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withValues(alpha: 0.15),
                                child: Icon(Icons.person, color: statusColor),
                              ),
                              title: Text(
                                item['chauffeur_nom'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Icon(Icons.directions_bus, size: 14, color: hasbus ? Colors.orange : Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasbus ? 'Bus N°${item['bus_numero']}' : 'Aucun bus assigné',
                                      style: TextStyle(
                                        color: hasbus ? Colors.orange[700] : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: hasbus ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Icon(Icons.map, size: 14, color: hasLigne ? Colors.green : Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasLigne ? 'Ligne : ${item['ligne_libelle']}' : 'Aucune ligne assignée',
                                      style: TextStyle(
                                        color: hasLigne ? Colors.green[700] : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: hasLigne ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                              trailing: Container(
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_note, color: Colors.teal),
                                  tooltip: 'Modifier l\'assignation',
                                  onPressed: () => _showAssignDialog(item),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }
}
