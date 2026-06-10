import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ClientAiDashboardPage extends StatefulWidget {
  const ClientAiDashboardPage({super.key});

  @override
  State<ClientAiDashboardPage> createState() => _ClientAiDashboardPageState();
}

class _ClientAiDashboardPageState extends State<ClientAiDashboardPage> {
  Map<String, dynamic> driverReport = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final avisList = await FirestoreService.getAllAvis();
      
      int total = avisList.length;
      int pos = 0, neg = 0, neu = 0;
      double sumScore = 0;
      double sumNotes = 0;
      
      for (var a in avisList) {
        String sentiment = a['Sentiment_label'] ?? 'Neutre';
        if (sentiment == 'Positif') { pos++; sumScore += 1.0; }
        else if (sentiment == 'Négatif') { neg++; sumScore += -1.0; }
        else { neu++; }
        sumNotes += (a['Note'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          driverReport = {
            'total_avis_chauffeur': total,
            'satisfaction_chauffeur': total > 0 ? ((sumScore / total) + 1) * 50 : 0.0,
            'avg_note': total > 0 ? sumNotes / total : 0.0,
            'sentiment_distribution': {'Positif': pos, 'Négatif': neg, 'Neutre': neu},
            'top_keywords': [],
            'top_drivers': [],
            'avis_list': avisList,
          };
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement données IA: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'Analyse IA — Chauffeurs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: isLoading ? _buildLoader() : _buildDriverDashboard(),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 2)
              ],
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(
                    color: Color(0xFF6A11CB), strokeWidth: 3),
                const SizedBox(height: 16),
                const Text(
                  '🤖 NLP en cours d\'analyse...',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6A11CB)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Catégorisation des commentaires chauffeurs',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverDashboard() {
    final int total = driverReport['total_avis_chauffeur'] ?? 0;

    if (total == 0) {
      return _buildEmptyState();
    }

    final double satisfaction =
        (driverReport['satisfaction_chauffeur'] ?? 0.0).toDouble();
    final double avgNote = (driverReport['avg_note'] ?? 0.0).toDouble();
    final Map sentDist = driverReport['sentiment_distribution'] as Map? ?? {};
    final List avisList = driverReport['avis_list'] as List? ?? [];

    int pos = (sentDist['Positif'] ?? 0) as int;
    int neg = (sentDist['Négatif'] ?? 0) as int;
    int neu = (sentDist['Neutre'] ?? 0) as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNlpBanner(total),
          const SizedBox(height: 16),
          _buildScoreCard(satisfaction, avgNote),
          const SizedBox(height: 16),
          _sectionTitle('Distribution des Sentiments', Icons.mood),
          const SizedBox(height: 10),
          _buildSentimentBars(pos, neg, neu, total),
          const SizedBox(height: 20),
          _sectionTitle('Avis détectés — Chauffeurs ($total)', Icons.comment),
          const SizedBox(height: 10),
          ...avisList.map((a) => _buildAvisCard(a)),
        ],
      ),
    );
  }

  Widget _buildNlpBanner(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF6A11CB).withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          const Text('🤖', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NLP a analysé les commentaires',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                Text(
                  '$count commentaire(s) concernent les chauffeurs',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count avis',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(double satisfaction, double avgNote) {
    Color scoreColor = satisfaction >= 60
        ? Colors.green
        : satisfaction >= 40
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 15,
              spreadRadius: 2)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '${satisfaction.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: scoreColor),
                ),
                const SizedBox(height: 4),
                const Text('Score IA Satisfaction',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: satisfaction / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 80,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 32),
                    const SizedBox(width: 4),
                    Text(
                      avgNote.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Note Moyenne /5',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avgNote.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentBars(int pos, int neg, int neu, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              spreadRadius: 1)
        ],
      ),
      child: Column(
        children: [
          _sentimentBar('😊 Positif', pos, total, Colors.green),
          const SizedBox(height: 12),
          _sentimentBar('😐 Neutre', neu, total, Colors.orange),
          const SizedBox(height: 12),
          _sentimentBar('😞 Négatif', neg, total, Colors.red),
        ],
      ),
    );
  }

  Widget _sentimentBar(String label, int count, int total, Color color) {
    double pct = total > 0 ? count / total : 0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count (${(pct * 100).toStringAsFixed(0)}%)',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAvisCard(dynamic avis) {
    final String sentiment = avis['Sentiment_label'] ?? 'Neutre';
    final Color sColor = sentiment == 'Positif'
        ? Colors.green
        : sentiment == 'Négatif'
            ? Colors.red
            : Colors.orange;
    final IconData sIcon = sentiment == 'Positif'
        ? Icons.sentiment_very_satisfied
        : sentiment == 'Négatif'
            ? Icons.sentiment_very_dissatisfied
            : Icons.sentiment_neutral;
    final double sentScore = sentiment == 'Positif' ? 1.0 : (sentiment == 'Négatif' ? -1.0 : 0.0);
    final double scoreDisplay = (sentScore + 1) / 2 * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1)
        ],
        border: Border(left: BorderSide(color: sColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: sColor.withOpacity(0.12),
                child: Icon(sIcon, color: sColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  avis['Commentaire'] ?? '...',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _badge(sentiment, sColor),
              _badge('⭐ ${avis['Note']}/5', Colors.amber),
              _badge('🤖 IA: ${scoreDisplay.toStringAsFixed(0)}%',
                  const Color(0xFF6A11CB)),
              if (avis['Nom_Client'] != null)
                _badge('👤 ${avis['Nom_Client']}', Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6A11CB), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off, size: 60, color: Colors.orange),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucun commentaire chauffeur détecté',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Le NLP n\'a trouvé aucun avis mentionnant le comportement ou le service des chauffeurs.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
