import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AvisAdminPage extends StatefulWidget {
  const AvisAdminPage({super.key});

  @override
  State<AvisAdminPage> createState() => _AvisAdminPageState();
}

class _AvisAdminPageState extends State<AvisAdminPage> {
  List<Map<String, dynamic>> avisList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAvis();
  }

  Future<void> fetchAvis() async {
    setState(() => isLoading = true);
    try {
      final data = await FirestoreService.getAllAvis();
      if (mounted) {
        setState(() {
          avisList = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur Fetch: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteAvis(String idAvis) async {
    try {
      await FirestoreService.deleteAvis(idAvis);
      if (mounted) {
        fetchAvis(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avis supprimé"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Erreur Delete: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analyse des Avis AI", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple[700],
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: fetchAvis)],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : avisList.isEmpty
              ? const Center(child: Text("Aucun avis trouvé", style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: avisList.length,
                  itemBuilder: (context, index) {
                    final item = avisList[index];
                    String sentiment = item['Sentiment_label'] ?? "Neutre";
                    String keywords = item['Keywords'] ?? "";
                    
                    Color sentimentColor = sentiment == "Positif" ? Colors.green 
                                        : (sentiment == "Négatif" ? Colors.red : Colors.orange);
                    
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: CircleAvatar(
                          backgroundColor: sentimentColor.withOpacity(0.1),
                          child: Icon(
                            sentiment == "Positif" ? Icons.sentiment_very_satisfied 
                            : (sentiment == "Négatif" ? Icons.sentiment_very_dissatisfied : Icons.sentiment_neutral),
                            color: sentimentColor,
                          ),
                        ),
                        title: Text(item['commentaire'] ?? item['Commentaire'] ?? "...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: sentimentColor, borderRadius: BorderRadius.circular(8)),
                                  child: Text(sentiment, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                if (item['Category'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.indigo[100], borderRadius: BorderRadius.circular(8)),
                                    child: Text(item['Category'], style: const TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                const SizedBox(width: 10),
                                Text("⭐ ${item['Note']}/5", style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 10),
                                Text("👤 ${item['Nom_Client'] ?? 'Inconnu'}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            if (keywords.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text("IA Mots-clés: $keywords", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.indigo)),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                          onPressed: () {
                            deleteAvis(item['ID_avis']);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}