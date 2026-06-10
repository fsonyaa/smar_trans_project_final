import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AdminNlpReportPage extends StatefulWidget {
  const AdminNlpReportPage({super.key});

  @override
  State<AdminNlpReportPage> createState() => _AdminNlpReportPageState();
}

class _AdminNlpReportPageState extends State<AdminNlpReportPage> {
  Map<String, dynamic> reportData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  Future<void> fetchReport() async {
    setState(() => isLoading = true);
    try {
      final avisList = await FirestoreService.getAllAvis();
      final parcoursList = await FirestoreService.getAllParcours();
      final chauffeurs = await FirestoreService.getAllChauffeurs();
      
      final chauffMap = {for (var c in chauffeurs) c['uid'] ?? c['id'] ?? '': c['nom'] ?? 'Inconnu'};
      
      int total = avisList.length;
      int pos = 0, neg = 0, neu = 0;
      double sumScore = 0;
      
      Map<String, int> wordCounts = {};
      Map<String, Map<String, dynamic>> driverStats = {};
      
      for (var a in avisList) {
        String sentiment = a['Sentiment_label'] ?? 'Neutre';
        if (sentiment == 'Positif') { pos++; sumScore += 1.0; }
        else if (sentiment == 'Négatif') { neg++; sumScore += -1.0; }
        else { neu++; }

        // Words
        final words = (a['Commentaire'] ?? '').toString().toLowerCase().split(RegExp(r'\W+'));
        for (var w in words) {
          if (w.length > 4 && !['pour', 'avec', 'dans', 'très', 'plus', 'cette', 'nous'].contains(w)) {
            wordCounts[w] = (wordCounts[w] ?? 0) + 1;
          }
        }

        // Driver stats - only if category is Chauffeur
        final isChauffeur = (a['Category'] ?? '').toString().toLowerCase() == 'chauffeur';
        if (isChauffeur) {
          String dId = a['driver_uid'] ?? '';
          if (dId.isNotEmpty) {
            if (!driverStats.containsKey(dId)) {
              driverStats[dId] = {'nb_avis': 0, 'sum_score': 0.0};
            }
            driverStats[dId]!['nb_avis'] += 1;
            driverStats[dId]!['sum_score'] += (sentiment == 'Positif' ? 1.0 : (sentiment == 'Négatif' ? -1.0 : 0.0));
          }
        }
      }

      var sortedWords = wordCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      List topKeywords = sortedWords.take(10).map((e) => [e.key, e.value]).toList();

      List topDrivers = driverStats.entries.map((e) {
        return {
          'Nom': chauffMap[e.key] ?? 'Chauffeur', 
          'nb_avis': e.value['nb_avis'],
          'avg_sentiment': e.value['sum_score'] / e.value['nb_avis']
        };
      }).toList()..sort((a, b) => (b['avg_sentiment'] as double).compareTo(a['avg_sentiment'] as double));

      // Group reviews by parcours for reviews that do NOT concern the chauffeur
      List<Map<String, dynamic>> parcoursStats = [];
      for (var p in parcoursList) {
        final pId = p['ID_parcours'] ?? p['id'] ?? '';
        if (pId.isEmpty) continue;
        
        final pAvis = avisList.where((a) {
          final histId = a['id_historique'] ?? '';
          final isChauffeur = (a['Category'] ?? '').toString().toLowerCase() == 'chauffeur';
          return histId == pId && !isChauffeur;
        }).toList();
        
        if (pAvis.isNotEmpty) {
          double pSumScore = 0;
          for (var a in pAvis) {
            String sentiment = a['Sentiment_label'] ?? 'Neutre';
            if (sentiment == 'Positif') { pSumScore += 1.0; }
            else if (sentiment == 'Négatif') { pSumScore += -1.0; }
          }
          double avgSentiment = pSumScore / pAvis.length;
          double iaScore = (avgSentiment + 1) * 50;
          
          parcoursStats.add({
            'ID_parcours': pId,
            'Depart': p['Depart'] ?? 'Inconnu',
            'Arrivee': p['Arrivee'] ?? 'Inconnu',
            'total_avis': pAvis.length,
            'ia_score': iaScore,
            'avis_list': pAvis,
          });
        }
      }

      if (mounted) {
        setState(() {
          reportData = {
            'total_avis': total,
            'average_sentiment_score': total > 0 ? sumScore / total : 0.0,
            'sentiment_distribution': {'Positif': pos, 'Négatif': neg, 'Neutre': neu},
            'parcours_stats': parcoursStats,
            'top_keywords': topKeywords,
            'top_drivers': topDrivers,
          };
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur fetch report: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Rapport d'Analyse IA NLP", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchReport,
          )
        ],
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlobalBanner(),
                  const SizedBox(height: 24),
                  
                  _sectionHeader("Analyse des Sentiments", Icons.analytics_outlined),
                  const SizedBox(height: 12),
                  _buildSentimentCard(),
                  
                  const SizedBox(height: 24),
                  _sectionHeader("Satisfaction par Parcours", Icons.alt_route),
                  const SizedBox(height: 12),
                  _buildParcoursList(),
                  
                  const SizedBox(height: 24),
                  _sectionHeader("Mots-clés IA Détectés", Icons.psychology_outlined),
                  const SizedBox(height: 12),
                  _buildKeywordCloud(),
                  
                  const SizedBox(height: 24),
                  _sectionHeader("Top score de chauffeurs", Icons.star_outline),
                  const SizedBox(height: 12),
                  _buildTopDriversList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A237E), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
        ),
      ],
    );
  }

  Widget _buildGlobalBanner() {
    double score = (( (reportData['average_sentiment_score'] ?? 0) + 1) * 50);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          const Text("Satisfaction Globale du Réseau", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            "${score.toStringAsFixed(1)}%",
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -1),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 15,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.comment_outlined, color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Basé sur ${reportData['total_avis'] ?? 0} avis analysés",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentCard() {
    Map<String, dynamic> dist = reportData['sentiment_distribution'] ?? {};
    int total = reportData['total_avis'] ?? 1;
    if (total == 0) total = 1;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(child: _sentimentIndicator("Positifs", dist['Positif'] ?? 0, total, Colors.green)),
          Expanded(child: _sentimentIndicator("Neutres", dist['Neutre'] ?? 0, total, Colors.orange)),
          Expanded(child: _sentimentIndicator("Négatifs", dist['Négatif'] ?? 0, total, Colors.red)),
        ],
      ),
    );
  }

  Widget _sentimentIndicator(String label, int count, int total, Color color) {
    double percent = (count / total) * 100;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                value: count / total,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 6,
              ),
            ),
            Text("${percent.toStringAsFixed(0)}%", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        Text("$count avis", style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildKeywordCloud() {
    List keywords = reportData['top_keywords'] ?? [];
    if (keywords.isEmpty) return _emptyState("Aucun mot-clé");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: keywords.map<Widget>((kw) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
            ),
            child: Text(
              "${kw[0]} (${kw[1]})",
              style: TextStyle(fontSize: 12, color: Colors.indigo[800], fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopDriversList() {
    List drivers = reportData['top_drivers'] ?? [];
    if (drivers.isEmpty) return _emptyState("Aucun chauffeur classé");

    return Column(
      children: drivers.map<Widget>((d) {
        double score = (((d['avg_sentiment'] ?? 0) + 1) * 50);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withOpacity(0.1),
              child: const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
            ),
            title: Text(d['Nom'] ?? "Inconnu", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("${d['nb_avis'] ?? 0} avis", style: const TextStyle(fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(
                "IA: ${score.toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParcoursList() {
    List stats = reportData['parcours_stats'] ?? [];
    if (stats.isEmpty) return _emptyState("Aucun parcours évalué");

    return Column(
      children: stats.map<Widget>((p) {
        double score = (p['ia_score'] ?? 0.0).toDouble();
        Color scoreColor = score >= 60
            ? Colors.green
            : score >= 40
                ? Colors.orange
                : Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    child: const Icon(Icons.directions_bus, color: Colors.indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${p['Depart']} ➜ ${p['Arrivee']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${p['total_avis']} avis clients",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${score.toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Score IA",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showAvisDetailsDialog(p),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text(
                    "Détails des avis",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1A237E),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showAvisDetailsDialog(Map<String, dynamic> parcours) {
    List avisList = parcours['avis_list'] ?? [];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Avis pour ${parcours['Depart']} ➜ ${parcours['Arrivee']}",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: avisList.length,
              itemBuilder: (context, index) {
                final avis = avisList[index];
                String sentiment = avis['Sentiment_label'] ?? 'Neutre';
                Color sColor = sentiment == 'Positif'
                    ? Colors.green
                    : sentiment == 'Négatif'
                        ? Colors.red
                        : Colors.orange;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: sColor, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        avis['Commentaire'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "⭐ ${avis['Note']}/5",
                            style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Client: ${avis['Nom_Client'] ?? 'Anonyme'}",
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(message, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      ),
    );
  }
}
