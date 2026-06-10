import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  List<Map<String, dynamic>> performanceData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPerformance();
  }

  Future<void> fetchPerformance() async {
    try {
      final data = await FirestoreService.getChauffeurPerformance();
      if (mounted) {
        setState(() {
          performanceData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Performance des Chauffeurs"),
        backgroundColor: Colors.indigo,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: performanceData.length,
              itemBuilder: (context, index) {
                final p = performanceData[index];
                double rating = (p['Average_Note'] ?? 0.0).toDouble();
                int totalReviews = p['Total_Avis'] ?? 0;

                return Card(
                  margin: const EdgeInsets.all(10),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.indigo.withOpacity(0.1),
                          child: const Icon(Icons.person, size: 40, color: Colors.indigo),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['Nom_Chauffeur'] ?? "Inconnu",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${rating.toStringAsFixed(1)} / 5",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "($totalReviews avis)",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: rating / 5,
                                backgroundColor: Colors.grey[200],
                                color: rating >= 4 ? Colors.green : (rating >= 2.5 ? Colors.orange : Colors.red),
                                minHeight: 8,
                              ),
                            ],
                          ),
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