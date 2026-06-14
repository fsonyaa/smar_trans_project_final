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
const String _realDeviceIp = '192.168.1.103';     // ✅ Ton IP WiFi actuelle

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

  // ── Mots positifs (français) ─────────────────────────────────
  static const List<String> _posWords = [
    'bien', 'bon', 'bonne', 'bons', 'bonnes',
    'super', 'excellent', 'excellente', 'excellents',
    'parfait', 'parfaite', 'parfaitement',
    'merci', 'bravo', 'félicitations',
    'rapide', 'rapides', 'ponctuel', 'ponctuelle', 'ponctuels',
    'propre', 'propres', 'confortable', 'confortables',
    'gentil', 'gentille', 'gentils', 'gentilles',
    'respectueux', 'respectueuse', 'agréable', 'agréables',
    'sympa', 'sympathique', 'souriant', 'souriante',
    'professionnel', 'professionnelle', 'sérieux', 'sérieuse',
    'satisfait', 'satisfaite', 'content', 'contente',
    'recommande', 'recommandé', 'top', 'super bien',
    'très bien', 'très bon', 'très propre', 'très rapide',
  ];

  // ── Mots négatifs (français) ─────────────────────────────────
  static const List<String> _negWords = [
    'mauvais', 'mauvaise', 'mauvaises',
    'nul', 'nulle', 'nuls',
    'horrible', 'horribles', 'affreux', 'affreuse',
    'retard', 'retardé', 'retards', 'en retard',
    'problème', 'problèmes', 'probleme', 'problemes',
    'mal', 'malaise',
    'sale', 'sales', 'dégoûtant', 'dégoûtante',
    'lent', 'lente', 'lents',
    'dangereux', 'dangereuse', 'danger', 'risque',
    'impoli', 'impolie', 'impolis', 'irrespectueux',
    'agressif', 'agressive', 'agressifs',
    'panne', 'pannes', 'accident', 'accidents',
    'insupportable', 'inadmissible', 'inacceptable',
    'déçu', 'déçue', 'déception', 'décevant', 'décevante',
    'jamais', 'évite', 'éviter', 'à éviter',
    'honte', 'scandale', 'catastrophe',
    'trop lent', 'trop mauvais', 'très mauvais', 'très sale',
  ];

  // ── Mots de négation ─────────────────────────────────────────
  static const List<String> _negationWords = [
    'pas', 'non', 'aucun', 'aucune', 'jamais', 'plus',
    'ni', 'sans', 'rien', 'nullement',
  ];

  // ── Mots par catégorie ───────────────────────────────────────
  static const List<String> _driverWords = [
    'chauffeur', 'conducteur', 'conduite', 'impoli', 'poli',
    'agressif', 'respectueux', 'pilote',
  ];
  static const List<String> _comfortWords = [
    'confort', 'siege', 'siège', 'clim', 'climatisation',
    'propre', 'sale', 'bruit', 'chaud', 'froid',
  ];
  static const List<String> _vehicleWords = [
    'bus', 'vehicule', 'véhicule', 'panne', 'moteur',
    'vieux', 'neuf', 'nouvelle',
  ];
  static const List<String> _serviceWords = [
    'retard', 'heure', 'attente', 'horaire', 'trajet',
    'ponctuel', 'service', 'ligne',
  ];

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

  /// Analyse locale avancée (fonctionne toujours sans serveur).
  /// Gère : mots positifs/négatifs étendus, négations, contradiction note/texte.
  static Map<String, dynamic> _localAnalysis(String commentaire, int note) {
    final text = commentaire.toLowerCase().trim();

    // ── Tokenisation simple par espaces/ponctuation ───────────────
    final tokens = text.split(RegExp(r'[\s,\.!?;:()\-]+'));

    // ── Détection des négations (ex: "pas bon" → annule "bon") ───
    double posScore = 0.0;
    double negScore = 0.0;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // Vérifier si le mot précédent (ou avant-précédent) est une négation
      final bool hasNegation = (i > 0 && _negationWords.contains(tokens[i - 1])) ||
          (i > 1 && _negationWords.contains(tokens[i - 2]));

      // Vérifier si mot positif
      final bool isPos = _posWords.any((w) => token == w || text.contains(w));
      // Vérifier si mot négatif
      final bool isNeg = _negWords.any((w) => token == w || text.contains(w));

      if (isPos) {
        if (hasNegation) {
          negScore += 1.0; // "pas bon" → négatif
        } else {
          posScore += 1.0;
        }
      }
      if (isNeg) {
        if (hasNegation) {
          posScore += 0.5; // "pas mauvais" → légèrement positif
        } else {
          negScore += 1.0;
        }
      }
    }

    // ── Score brut texte ─────────────────────────────────────────
    //    Normalisé entre -1.0 et +1.0
    final double total = posScore + negScore;
    double rawScore = total == 0 ? 0.0 : (posScore - negScore) / total;

    // ── Label textuel ────────────────────────────────────────────
    String textLabel;
    if (rawScore > 0.2) {
      textLabel = 'Positif';
    } else if (rawScore < -0.2) {
      textLabel = 'Négatif';
    } else if (total == 0) {
      textLabel = 'Neutre'; // Aucun mot-clé trouvé
    } else {
      textLabel = 'Neutre'; // Trop mitigé
    }

    // ── Label note ───────────────────────────────────────────────
    String noteLabel;
    if (note >= 4) {
      noteLabel = 'Positif';
    } else if (note <= 2) {
      noteLabel = 'Négatif';
    } else {
      noteLabel = 'Neutre'; // note == 3
    }

    // ── Combinaison intelligente texte + note ────────────────────
    //
    //  Règles :
    //  1. Si aucun mot-clé dans le texte → la note seule décide
    //  2. Si note == 3 (neutre) → le texte seul décide
    //  3. Si accord texte & note → résultat concordant
    //  4. Si contradiction (ex: texte positif + 1★) → Neutre
    //
    String label;
    if (total == 0) {
      // Aucun mot-clé : la note est la seule information
      label = noteLabel;
    } else if (noteLabel == 'Neutre') {
      // Note neutre (3★) : le texte décide
      label = textLabel;
    } else if (textLabel == 'Neutre') {
      // Texte ambigu, trop mitigé : la note vient compléter
      label = noteLabel;
    } else if (textLabel == noteLabel) {
      // Texte et note sont d'accord → résultat clair
      label = textLabel;
    } else {
      // Contradiction franche (ex: "bon chauffeur" + 1★) → Neutre
      label = 'Neutre';
    }

    // ── Catégorie ─────────────────────────────────────────────────
    String category = 'General';
    if (_driverWords.any((w) => text.contains(w))) {
      category = 'Chauffeur';
    } else if (_serviceWords.any((w) => text.contains(w))) {
      category = 'Service';
    } else if (_vehicleWords.any((w) => text.contains(w))) {
      category = 'Vehicule';
    } else if (_comfortWords.any((w) => text.contains(w))) {
      category = 'Confort';
    }

    // ── Mots-clés détectés ────────────────────────────────────────
    final allCategoryWords = [
      ..._driverWords, ..._comfortWords, ..._vehicleWords, ..._serviceWords,
    ];
    final detectedKeywords = allCategoryWords
        .where((w) => text.contains(w))
        .toSet()
        .join(', ');

    debugPrint(
      '📱 NLP Local → texte=$textLabel, note=$noteLabel, final=$label / $category'
      ' (pos=$posScore, neg=$negScore)',
    );

    return {
      'label': label,
      'score': rawScore,
      'keywords': detectedKeywords.isEmpty ? null : detectedKeywords,
      'category': category,
      'source': 'local_fallback',
    };
  }
}
