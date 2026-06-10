import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AdminHistoriquePage extends StatefulWidget {
  const AdminHistoriquePage({super.key});

  @override
  State<AdminHistoriquePage> createState() => _AdminHistoriquePageState();
}

class _AdminHistoriquePageState extends State<AdminHistoriquePage> {
  List<Map<String, dynamic>> historique = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHistorique();
  }

  Future<void> fetchHistorique() async {
    try {
      final data = await FirestoreService.getAllHistorique();
      if (mounted) {
        setState(() {
          historique = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur historique: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Historique des Parcours", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchHistorique),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : historique.isEmpty
              ? Center(child: Text("Aucun historique disponible", style: TextStyle(color: Colors.grey[600], fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: historique.length,
                  itemBuilder: (context, index) {
                    final h = historique[index];
                    return _buildHistoriqueCard(h);
                  },
                ),
    );
  }

  Widget _buildHistoriqueCard(Map<String, dynamic> h) {
    String statut = h['Statut'] ?? 'Inconnu';
    Color statusColor = Colors.grey;
    if (statut == 'Terminé' || statut == 'Fin') statusColor = Colors.green;
    if (statut == 'En cours' || statut == 'Début') statusColor = Colors.blue;
    if (statut == 'Annulé') statusColor = Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.teal[700]),
                    const SizedBox(width: 5),
                    Text(h['Date'] ?? "---", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[900])),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statut,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Ligne: ${h['Nom_Ligne'] ?? 'Non spécifiée'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Chauffeur: ${h['Nom_Chauffeur'] ?? 'Inconnu'}", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildLocationPoint(h['Depart'] ?? "---", Icons.radio_button_checked, Colors.green),
                Expanded(child: Container(height: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 10))),
                _buildLocationPoint(h['Arrivee'] ?? "---", Icons.location_on, Colors.red),
              ],
            ),
            if (h['Performance_IA'] != null) ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.purple, size: 18),
                  const SizedBox(width: 5),
                  Text("Score IA: ", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Text("${h['Performance_IA']}%", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPoint(String name, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
