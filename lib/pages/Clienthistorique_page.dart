import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class HistoriquePage extends StatefulWidget {
  final String clientUid; 

  const HistoriquePage({
    Key? key,
    required this.clientUid, 
  }) : super(key: key);

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  List<Map<String, dynamic>> avis = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAvis();
  }

  Future<void> fetchAvis() async {
    setState(() => isLoading = true);
    try {
      final data = await FirestoreService.getAvisByClient(widget.clientUid);
      if (mounted) {
        setState(() {
          avis = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur avis: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteAvis(String id) async {
    try {
      await FirestoreService.deleteAvis(id);
      fetchAvis();
    } catch (e) {
      debugPrint("Erreur delete: $e");
    }
  }

  void showEditDialog(Map<String, dynamic> avisItem) {
    TextEditingController ctrl = TextEditingController(
      text: avisItem['commentaire'] ?? avisItem['Commentaire'] ?? ""
    );
    int rating = (avisItem['note'] ?? avisItem['Note'] ?? 3) as int;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Modifier avis"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      icon: Icon(
                        Icons.star,
                        color: i < rating ? Colors.orange : Colors.grey,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          rating = i + 1;
                        });
                      },
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await FirestoreService.updateAvis(
                    avisId: avisItem['ID_avis'],
                    commentaire: ctrl.text,
                    note: rating,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    fetchAvis();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("Modifier"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des avis"),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : avis.isEmpty
              ? const Center(
                  child: Text("Aucun avis", style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: avis.length,
                  itemBuilder: (context, index) {
                    final a = avis[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        title: Text(
                          "Avis - Historique", 
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text(a['commentaire'] ?? a['Commentaire'] ?? ""),
                            const SizedBox(height: 5),
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  Icons.star,
                                  size: 18,
                                  color: i < ((a['note'] ?? a['Note'] ?? 0) as int)
                                      ? Colors.orange
                                      : Colors.grey,
                                );
                              }),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                showEditDialog(a);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                deleteAvis(a['ID_avis']);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}