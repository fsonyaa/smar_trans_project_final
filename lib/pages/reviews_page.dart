import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'current_user.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  List<Map<String, dynamic>> reviews = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReviews();
  }

  Future<void> fetchReviews() async {
    try {
      final uid = CurrentUser.uid;
      if (uid.isEmpty) {
        setState(() => isLoading = false);
        return;
      }
      final data = await FirestoreService.getDriverReviews(uid);
      if (mounted) {
        setState(() {
          reviews = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Notes & Avis"), 
        backgroundColor: Colors.teal
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : reviews.isEmpty 
          ? const Center(child: Text("Aucun avis trouvé"))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                var review = reviews[index];
                int note = review['note'] ?? review['Note'] ?? 0;
                String sentiment = review['sentiment'] ?? review['Sentiment_label'] ?? "Neutre";
                String commentaire = review['commentaire'] ?? review['Commentaire'] ?? "";

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 15),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStars(note),
                            _buildSentimentBadge(sentiment),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          commentaire,
                          style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                        ),
                        const Divider(),
                        Text(
                          "Date: ${review['date'] ?? 'Récent'}", 
                          style: const TextStyle(color: Colors.grey, fontSize: 12)
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStars(int note) {
    return Row(
      children: List.generate(5, (i) => Icon(
        Icons.star, 
        color: i < note ? Colors.amber : Colors.grey[300], 
        size: 20
      )),
    );
  }

  Widget _buildSentimentBadge(String sentiment) {
    Color col = sentiment == "Positif" ? Colors.green : (sentiment == "Négatif" ? Colors.red : Colors.blueGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: col.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: col)
      ),
      child: Text(
        sentiment, 
        style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12)
      ),
    );
  }
}