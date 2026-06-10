import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ╔══════════════════════════════════════════════════════════════╗
// ║        CONFIGURATION FLASK NLP — MODIFIER ICI SEULEMENT     ║
// ╚══════════════════════════════════════════════════════════════╝
//
// CAS 1 — Émulateur Android (défaut) :
//   _useEmulator = true  → utilise 10.0.2.2 automatiquement
//
// CAS 2 — Vrai téléphone Android/iOS :
//   _useEmulator = false  ET  colle ton IP locale dans _realDeviceIp
//   Pour trouver ton IP : ouvre cmd → tape "ipconfig" → cherche "Adresse IPv4"
//   Exemple : 192.168.1.45
//
// CAS 3 — Web (flutter run -d chrome) :
//   Utilise localhost automatiquement (détecté via kIsWeb)
//
// ⚠️ Si Flask n'est PAS lancé → fallback local automatique, rien ne casse.

const bool _useEmulator = false;                  // ✅ Vrai téléphone
const String _realDeviceIp = '10.100.224.55';     // ✅ Ton IP WiFi actuelle

String get _flaskBase {
  if (kIsWeb) return 'http://localhost:8000';
  if (_useEmulator) return 'http://10.0.2.2:8000';
  return 'http://$_realDeviceIp:8000';
}

// ═══════════════════════════════════════════════════════════════

/// Service NLP : appelle Flask (app.py) pour une vraie analyse TextBlob.
/// Fallback automatique vers analyse locale si Flask n'est pas lancé.
class NlpService {
  static const Duration _timeout = Duration(seconds: 3);

  /// Analyse le sentiment d'un commentaire.
  ///
  /// Retourne une Map avec :
  ///   - 'label'    : "Positif" | "Négatif" | "Neutre"
  ///   - 'score'    : double entre -1.0 et 1.0 (null si fallback local)
  ///   - 'keywords' : String mots-clés détectés (null si fallback local)
  ///   - 'category' : "Chauffeur" | "Confort" | "Vehicule" | "Service" | "General"
  ///   - 'source'   : "flask_nlp" | "local_fallback"
  static Future<Map<String, dynamic>> analyze(
      String commentaire, int note) async {
    // 1. Essayer Flask en priorité
    try {
      final response = await http
          .post(
            Uri.parse('$_flaskBase/analyze_sentiment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'commentaire': commentaire, 'note': note}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ NLP Flask: ${data['label']} (score: ${data['score']})');
        return {
          'label': data['label'] ?? 'Neutre',
          'score': (data['score'] as num?)?.toDouble(),
          'keywords': data['keywords'],
          'category': data['category'] ?? 'General',
          'source': 'flask_nlp',
        };
      }
    } catch (e) {
      // Flask non lancé → fallback silencieux, rien ne casse
      debugPrint('⚠️ Flask NLP non disponible, fallback local: $e');
    }

    // 2. Fallback local si Flask non disponible
    return _localAnalysis(commentaire, note);
  }

  /// Analyse locale simple (fonctionne toujours sans serveur)
  static Map<String, dynamic> _localAnalysis(String commentaire, int note) {
    final text = commentaire.toLowerCase();

    const posWords = [
      'bien', 'super', 'excellent', 'parfait', 'merci', 'bon', 'rapide',
      'propre', 'ponctuel', 'bravo', 'confortable', 'gentil', 'respectueux'
    ];
    const negWords = [
      'mauvais', 'nul', 'horrible', 'retard', 'problème', 'mal', 'sale',
      'lent', 'dangereux', 'impoli', 'agressif', 'panne', 'danger'
    ];

    String label = 'Neutre';
    if (posWords.any((w) => text.contains(w))) label = 'Positif';
    if (negWords.any((w) => text.contains(w))) label = 'Négatif';

    // La note prime toujours
    if (note >= 4) label = 'Positif';
    if (note <= 2) label = 'Négatif';

    // Catégorie simple
    String category = 'General';
    if (['chauffeur', 'conducteur', 'impoli', 'conduite', 'agressif']
        .any((w) => text.contains(w))) {
      category = 'Chauffeur';
    } else if (['retard', 'heure', 'attente', 'horaire', 'ponctuel']
        .any((w) => text.contains(w))) {
      category = 'Service';
    } else if (['bus', 'vehicule', 'panne', 'moteur', 'vieux']
        .any((w) => text.contains(w))) {
      category = 'Vehicule';
    } else if (['confort', 'siege', 'clim', 'propre', 'sale', 'bruit']
        .any((w) => text.contains(w))) {
      category = 'Confort';
    }

    debugPrint('📱 NLP Local fallback: $label / $category');
    return {
      'label': label,
      'score': null,
      'keywords': null,
      'category': category,
      'source': 'local_fallback',
    };
  }
}
