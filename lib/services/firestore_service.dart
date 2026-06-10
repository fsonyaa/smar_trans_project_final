import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'nlp_service.dart';

/// Service centralisé pour toutes les opérations Firestore (CRUD)
/// Structure de la base : administrateurs, chauffeurs, clients, utilisateurs,
///                        bus, lignes, parcours, historique, incidents, avis
class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ════════════════════════════════════════════════════════════
  // AUTH / LOGIN — cherche l'utilisateur dans toutes les collections
  // ════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    // Cherche dans 'users' (collection principale)
    final userSnap = await _db.collection('users')
        .where('email', isEqualTo: email).limit(1).get();
    if (userSnap.docs.isNotEmpty) {
      return {'id': userSnap.docs.first.id, ...userSnap.docs.first.data()};
    }

    // Cherche dans 'chauffeurs'
    final chauffSnap = await _db.collection('chauffeurs')
        .where('email', isEqualTo: email).limit(1).get();
    if (chauffSnap.docs.isNotEmpty) {
      return {'id': chauffSnap.docs.first.id, 'role': 'chauffeur', ...chauffSnap.docs.first.data()};
    }

    // Cherche dans 'clients'
    final clientSnap = await _db.collection('clients')
        .where('email', isEqualTo: email).limit(1).get();
    if (clientSnap.docs.isNotEmpty) {
      return {'id': clientSnap.docs.first.id, 'role': 'client', ...clientSnap.docs.first.data()};
    }

    return null;
  }

  /// Cherche l'utilisateur par UID Firebase dans toutes les collections
  static Future<Map<String, dynamic>?> findUserByUid(String uid) async {
    // 1. Cherche dans 'users' (collection principale)
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) return {'id': doc.id, ...doc.data()!};

    // 2. Cherche dans 'chauffeurs' (fallback)
    final chauffSnap = await _db.collection('chauffeurs')
        .where('uid', isEqualTo: uid).limit(1).get();
    if (chauffSnap.docs.isNotEmpty) {
      return {'id': chauffSnap.docs.first.id, 'role': 'chauffeur', ...chauffSnap.docs.first.data()};
    }

    // 3. Cherche dans 'clients' (fallback)
    final clientSnap = await _db.collection('clients')
        .where('uid', isEqualTo: uid).limit(1).get();
    if (clientSnap.docs.isNotEmpty) {
      return {'id': clientSnap.docs.first.id, 'role': 'client', ...clientSnap.docs.first.data()};
    }

    return null;
  }

  /// Crée un nouvel utilisateur dans la bonne collection selon son rôle
  static Future<void> createUser({
    required String uid,
    required String nom,
    required String email,
    required String role,
    String? telephone,
    String? adresse,
  }) async {
    final data = {
      'uid': uid,
      'nom': nom,
      'email': email,
      'role': role,
      'telephone': telephone ?? '',
      'adresse': adresse ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Toujours sauvegarder dans 'users' (collection principale)
    await _db.collection('users').doc(uid).set(data);

    // Et dans la collection spécifique au rôle
    if (role == 'chauffeur') {
      await _db.collection('chauffeurs').doc(uid).set(data);
    } else if (role == 'client') {
      await _db.collection('clients').doc(uid).set(data);
    }
  }

  // ════════════════════════════════════════════════════════════
  // STATS (Admin Dashboard)
  // ════════════════════════════════════════════════════════════
  static Future<Map<String, int>> getCounts() async {
    try {
      final results = await Future.wait([
        _db.collection('bus').count().get(),
        _db.collection('lignes').count().get(),
        _db.collection('chauffeurs').count().get(),
        _db.collection('incidents').count().get(),
      ]);
      return {
        'bus': results[0].count ?? 0,
        'lignes': results[1].count ?? 0,
        'chauffeurs': results[2].count ?? 0,
        'incidents': results[3].count ?? 0,
      };
    } catch (e) {
      return {'bus': 0, 'lignes': 0, 'chauffeurs': 0, 'incidents': 0};
    }
  }

  // ════════════════════════════════════════════════════════════
  // BUS
  // ════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getBuses() async {
    final snap = await _db.collection('bus').get();
    return snap.docs.map((d) => {'Code_bus': d.id, ...d.data()}).toList();
  }

  static Future<void> addBus({
    required String numeroBus,
    required String etat,
    String? codeChauffeur,
  }) async {
    await _db.collection('bus').add({
      'Numero_bus': numeroBus,
      'Etat': etat,
      'Code_chauffeur': codeChauffeur,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateBus({
    required String busId,
    required String numeroBus,
    required String etat,
    String? codeChauffeur,
  }) async {
    await _db.collection('bus').doc(busId).update({
      'Numero_bus': numeroBus,
      'Etat': etat,
      'Code_chauffeur': codeChauffeur,
    });
  }

  static Future<void> deleteBus(String busId) async {
    await _db.collection('bus').doc(busId).delete();
  }

  // ════════════════════════════════════════════════════════════
  // CHAUFFEURS (Admin)
  // ════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getAllChauffeurs() async {
    final snap = await _db.collection('chauffeurs').get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  static Future<void> deleteChauffeur(String uid) async {
    await _db.collection('chauffeurs').doc(uid).delete();
    await _db.collection('users').doc(uid).delete();
  }

  static Future<void> updateChauffeur({
    required String uid,
    required String nom,
    required String email,
    String? telephone,
  }) async {
    final data = {'nom': nom, 'email': email, 'telephone': telephone ?? ''};
    await _db.collection('chauffeurs').doc(uid).update(data);
    try { await _db.collection('users').doc(uid).update(data); } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  // LIGNES
  // ════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getAllLignes() async {
    final snap = await _db.collection('lignes').get();
    final lignes = snap.docs.map((d) => {
      'code_ligne': d.id,
      'Code_Ligne': d.id,
      'Libelle': d.data()['libelle'] ?? d.data()['Libelle'] ?? '',
      ...d.data()
    }).toList();

    // Enrichir avec le nom du chauffeur via le bus
    final buses = await getBuses();
    final chauffeurs = await getAllChauffeurs();
    final chauffMap = {for (var c in chauffeurs) c['uid']: c['nom'] ?? ''};

    for (var ligne in lignes) {
      final codeBus = ligne['code_bus'] ?? ligne['Code_bus'];
      if (codeBus != null) {
        final bus = buses.firstWhere(
          (b) => b['Code_bus'] == codeBus,
          orElse: () => {},
        );
        final chauffId = bus['Code_chauffeur'];
        ligne['nom_chauffeur'] = chauffId != null ? (chauffMap[chauffId] ?? 'Non assigné') : 'Non assigné';
      } else {
        ligne['nom_chauffeur'] = 'Non assigné';
      }
    }
    return lignes;
  }

  static Future<List<Map<String, dynamic>>> getLignes() async {
    final snap = await _db.collection('lignes').get();
    return snap.docs.map((d) => {
      'Code_Ligne': d.id,
      'code_ligne': d.id,
      'Libelle': d.data()['libelle'] ?? d.data()['Libelle'] ?? '',
      ...d.data()
    }).toList();
  }

  static Future<void> addLigne({
    required String libelle,
    required String description,
    String? codeBus,
  }) async {
    await _db.collection('lignes').add({
      'libelle': libelle,
      'Libelle': libelle,
      'description': description,
      'code_bus': codeBus,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateLigne({
    required String ligneId,
    required String libelle,
    required String description,
    String? codeBus,
  }) async {
    await _db.collection('lignes').doc(ligneId).update({
      'libelle': libelle,
      'Libelle': libelle,
      'description': description,
      'code_bus': codeBus,
    });
  }

  static Future<void> deleteLigne(String ligneId) async {
    await _db.collection('lignes').doc(ligneId).delete();
  }

  // ════════════════════════════════════════════════════════════
  // PARCOURS
  // ════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getAllParcours() async {
    final snap = await _db.collection('parcours').get();
    final parcoursList = snap.docs.map((d) => {'ID_parcours': d.id, ...d.data()}).toList();

    final lignes = await getLignes();
    final lignesMap = {for (var l in lignes) l['Code_Ligne']: l['Libelle'] ?? ''};
    for (var p in parcoursList) {
      p['Nom_Ligne'] = lignesMap[p['Code_Ligne']] ?? '';
    }
    return parcoursList;
  }

  static Future<void> addParcours({
    required String depart,
    required String arrivee,
    required String heureDepart,
    required String heureArrivee,
    required String codeLigne,
    int etat = 0,
  }) async {
    await _db.collection('parcours').add({
      'Depart': depart,
      'Arrivee': arrivee,
      'Heure_depart': heureDepart,
      'Heure_arrivee': heureArrivee,
      'Code_Ligne': codeLigne,
      'Etat': etat,
      'Statut': 'Pas démarré',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateParcours({
    required String parcoursId,
    required String depart,
    required String arrivee,
    required String heureDepart,
    required String heureArrivee,
    required String codeLigne,
  }) async {
    await _db.collection('parcours').doc(parcoursId).update({
      'Depart': depart,
      'Arrivee': arrivee,
      'Heure_depart': heureDepart,
      'Heure_arrivee': heureArrivee,
      'Code_Ligne': codeLigne,
    });
  }

  static Future<void> deleteParcours(String parcoursId) async {
    await _db.collection('parcours').doc(parcoursId).delete();
  }

  // ════════════════════════════════════════════════════════════
  // ASSIGNATIONS CHAUFFEUR
  // ════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getMyAssignments(String chauffeurUid) async {
    try {
      // 1. Trouver le bus du chauffeur
      final busSnap = await _db.collection('bus')
          .where('Code_chauffeur', isEqualTo: chauffeurUid).get();
      if (busSnap.docs.isEmpty) return [];

      final busDoc = busSnap.docs.first;
      final busId = busDoc.id;

      // 2. Trouver les lignes avec ce bus
      final ligneSnap = await _db.collection('lignes')
          .where('code_bus', isEqualTo: busId).get();
      if (ligneSnap.docs.isEmpty) return [];

      // 3. Pour chaque ligne, chercher les parcours
      final List<Map<String, dynamic>> result = [];
      for (var ligneDoc in ligneSnap.docs) {
        final parcoursSnap = await _db.collection('parcours')
            .where('Code_Ligne', isEqualTo: ligneDoc.id).get();

        for (var p in parcoursSnap.docs) {
          final data = p.data();
          result.add({
            'ID_parcours': p.id,
            'Libelle': ligneDoc.data()['libelle'] ?? ligneDoc.data()['Libelle'] ?? '',
            'Depart': data['Depart'] ?? '',
            'Arrivee': data['Arrivee'] ?? '',
            'Heure_depart': data['Heure_depart'] ?? '',
            'Heure_arrivee': data['Heure_arrivee'] ?? '',
            'Statut': data['Statut'] ?? 'Pas démarré',
          });
        }
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════
  // HISTORIQUE
  // ════════════════════════════════════════════════════════════
  static Future<void> logHistorique({
    required String driverUid,
    required String parcoursId,
    required String action,
    String? depart,
    String? arrivee,
    required String timestamp,
  }) async {
    final statut = action == 'Début' ? 'En cours' : 'Terminé';
    await _db.collection('parcours').doc(parcoursId).update({'Statut': statut});

    final parcoursDoc = await _db.collection('parcours').doc(parcoursId).get();
    final codeLigne = parcoursDoc.data()?['Code_Ligne'] ?? '';
    String nomLigne = '';
    if (codeLigne.isNotEmpty) {
      final ligneDoc = await _db.collection('lignes').doc(codeLigne).get();
      nomLigne = ligneDoc.data()?['libelle'] ?? ligneDoc.data()?['Libelle'] ?? '';
    }

    // Chercher le nom du chauffeur (dans 'chauffeurs' ou 'users')
    String nomChauffeur = '';
    final chauffDoc = await _db.collection('chauffeurs').doc(driverUid).get();
    if (chauffDoc.exists) {
      nomChauffeur = chauffDoc.data()?['nom'] ?? '';
    } else {
      final userDoc = await _db.collection('users').doc(driverUid).get();
      nomChauffeur = userDoc.data()?['nom'] ?? '';
    }

    await _db.collection('historique').add({
      'driver_uid': driverUid,
      'Nom_Chauffeur': nomChauffeur,
      'parcours_id': parcoursId,
      'action': action,
      'Depart': depart ?? '',
      'Arrivee': arrivee ?? '',
      'timestamp': timestamp,
      'Date': timestamp.split(' ')[0],
      'Statut': statut,
      'Nom_Ligne': nomLigne,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAllHistorique() async {
    final snap = await _db.collection('historique')
        .orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<List<Map<String, dynamic>>> getDriverStats(String driverUid) async {
    final reviewsSnap = await _db.collection('avis')
        .where('driver_uid', isEqualTo: driverUid).get();
    final incidents = await _db.collection('incidents')
        .where('driver_uid', isEqualTo: driverUid).count().get();

    double totalNote = 0;
    for (var doc in reviewsSnap.docs) {
      totalNote += (doc.data()['note'] ?? doc.data()['Note'] ?? 0).toDouble();
    }
    final avgNote = reviewsSnap.docs.isEmpty ? 5.0 : totalNote / reviewsSnap.docs.length;

    return [{
      'performance_score': avgNote.toStringAsFixed(1),
      'incident_count': incidents.count ?? 0,
    }];
  }

  // ════════════════════════════════════════════════════════════
  // INCIDENTS
  // ════════════════════════════════════════════════════════════
  static Future<void> declareIncident({
    required String driverUid,
    required String description,
    required String timestamp,
  }) async {
    final busSnap = await _db.collection('bus')
        .where('Code_chauffeur', isEqualTo: driverUid).get();
    String numeroBus = 'Non assigné';
    String nomLigne = '';
    if (busSnap.docs.isNotEmpty) {
      numeroBus = busSnap.docs.first.data()['Numero_bus']?.toString() ?? 'N/A';
      final ligneSnap = await _db.collection('lignes')
          .where('code_bus', isEqualTo: busSnap.docs.first.id).get();
      if (ligneSnap.docs.isNotEmpty) {
        nomLigne = ligneSnap.docs.first.data()['libelle'] ?? ligneSnap.docs.first.data()['Libelle'] ?? '';
      }
    }

    await _db.collection('incidents').add({
      'driver_uid': driverUid,
      'Description': description,
      'timestamp': timestamp,
      'Date': timestamp.split(' ')[0],
      'Statut': 'Nouveau',
      'Numero_bus': numeroBus,
      'Nom_Ligne': nomLigne,
      'Performance_IA': 0,
      'Critique': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAllIncidents() async {
    final snap = await _db.collection('incidents')
        .orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => {'ID_incident': d.id, ...d.data()}).toList();
  }

  static Future<void> updateIncidentStatus({
    required String incidentId,
    required String statut,
    required int critique,
  }) async {
    await _db.collection('incidents').doc(incidentId).update({
      'Statut': statut,
      'Critique': critique,
      'Performance_IA': critique,
    });
  }

  static Future<void> deleteIncident(String incidentId) async {
    await _db.collection('incidents').doc(incidentId).delete();
  }

  // ════════════════════════════════════════════════════════════
  // AVIS (Reviews)
  // ════════════════════════════════════════════════════════════
  static Future<void> addAvis({
    required String clientUid,
    required int clientId,
    required String historiqueId,
    required String commentaire,
    required int note,
  }) async {
    // ─── Analyse NLP via Flask (avec fallback local automatique) ───
    final nlp = await NlpService.analyze(commentaire, note);
    final String sentiment = nlp['label'] as String;         // "Positif" / "Négatif" / "Neutre"
    final double? sentimentScore = nlp['score'] as double?;  // null si fallback local
    final String? keywords = nlp['keywords'] as String?;     // mots-clés Flask
    final String category = nlp['category'] as String? ?? 'General';
    final String nlpSource = nlp['source'] as String? ?? 'local_fallback';
    debugPrint('🤖 Avis NLP [$nlpSource] → $sentiment / $category');

    // Trouver le chauffeur via le parcours
    String driverUid = '';
    if (historiqueId.isNotEmpty) {
      try {
        // D'abord chercher dans 'historique'
        final histDoc = await _db.collection('historique').doc(historiqueId).get();
        if (histDoc.exists) {
          driverUid = histDoc.data()?['driver_uid'] ?? '';
        }
        // Si pas trouvé dans historique, chercher via parcours
        if (driverUid.isEmpty) {
          final parcoursDoc = await _db.collection('parcours').doc(historiqueId).get();
          if (parcoursDoc.exists) {
            final codeLigne = parcoursDoc.data()?['Code_Ligne'] ?? '';
            if (codeLigne.isNotEmpty) {
              final ligneDoc = await _db.collection('lignes').doc(codeLigne).get();
              final codeBus = ligneDoc.data()?['code_bus'] ?? '';
              if (codeBus.isNotEmpty) {
                final busDoc = await _db.collection('bus').doc(codeBus).get();
                driverUid = busDoc.data()?['Code_chauffeur'] ?? '';
              }
            }
          }
        }
      } catch (_) {}
    }

    // Chercher le nom du client
    String nomClient = '';
    final clientDoc = await _db.collection('clients').doc(clientUid).get();
    if (clientDoc.exists) {
      nomClient = clientDoc.data()?['nom'] ?? '';
    } else {
      final userDoc = await _db.collection('users').doc(clientUid).get();
      nomClient = userDoc.data()?['nom'] ?? '';
    }

    await _db.collection('avis').add({
      'client_uid': clientUid,
      'client_id': clientId,
      'id_historique': historiqueId,
      'driver_uid': driverUid,
      'Nom_Client': nomClient,
      'commentaire': commentaire,
      'Commentaire': commentaire,
      'note': note,
      'Note': note,
      'sentiment': sentiment,
      'Sentiment_label': sentiment,
      if (sentimentScore != null) 'Sentiment_score': sentimentScore,
      if (keywords != null) 'Keywords': keywords,
      'Category': category,
      'nlp_source': nlpSource,   // 'flask_nlp' ou 'local_fallback'
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAllAvis() async {
    final snap = await _db.collection('avis')
        .orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => {'ID_avis': d.id, ...d.data()}).toList();
  }

  static Future<List<Map<String, dynamic>>> getAvisByClient(String clientUid) async {
    try {
      // Sans orderBy pour éviter les index composites Firestore
      final snap = await _db.collection('avis')
          .where('client_uid', isEqualTo: clientUid)
          .get();
      final docs = snap.docs.map((d) => {'ID_avis': d.id, ...d.data()}).toList();
      // Trier côté client par date de création (plus récent d'abord)
      docs.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return docs;
    } catch (e) {
      debugPrint('Erreur getAvisByClient: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getDriverReviews(String driverUid) async {
    final snap = await _db.collection('avis')
        .where('driver_uid', isEqualTo: driverUid).get();
    return snap.docs.map((d) => {'ID_avis': d.id, ...d.data()}).toList();
  }

  static Future<void> updateAvis({
    required String avisId,
    required String commentaire,
    required int note,
  }) async {
    String sentiment = note >= 4 ? 'Positif' : (note <= 2 ? 'Négatif' : 'Neutre');
    await _db.collection('avis').doc(avisId).update({
      'commentaire': commentaire,
      'Commentaire': commentaire,
      'note': note,
      'Note': note,
      'sentiment': sentiment,
      'Sentiment_label': sentiment,
    });
  }

  static Future<void> deleteAvis(String avisId) async {
    await _db.collection('avis').doc(avisId).delete();
  }

  // ════════════════════════════════════════════════════════════
  // CLIENT TRIPS
  // ════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getClientTrips() async {
    final lignes = await getAllLignes();
    final List<Map<String, dynamic>> result = [];

    for (var ligne in lignes) {
      final parcoursSnap = await _db.collection('parcours')
          .where('Code_Ligne', isEqualTo: ligne['code_ligne']).get();

      final List<Map<String, dynamic>> rides = [];
      for (var p in parcoursSnap.docs) {
        rides.add({
          'ID_historique': p.id,
          'Depart': p.data()['Depart'] ?? '',
          'Arrivee': p.data()['Arrivee'] ?? '',
          'Heure_depart': p.data()['Heure_depart'] ?? '',
          'Heure_arrivee': p.data()['Heure_arrivee'] ?? '',
          'Statut': p.data()['Statut'] ?? 'Pas démarré',
        });
      }

      if (rides.isNotEmpty) {
        result.add({
          'libelle': ligne['libelle'] ?? ligne['Libelle'] ?? '',
          'description': ligne['description'] ?? '',
          'code_bus': ligne['code_bus'] ?? '',
          'nom_chauffeur': ligne['nom_chauffeur'] ?? 'Non assigné',
          'rides': rides,
        });
      }
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════
  // PERFORMANCE CHAUFFEURS
  // ════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getChauffeurPerformance() async {
    final chauffeurs = await getAllChauffeurs();

    final List<Map<String, dynamic>> result = [];
    for (var c in chauffeurs) {
      final uid = c['uid'] ?? c['id'] ?? '';
      final avisSnap = await _db.collection('avis')
          .where('driver_uid', isEqualTo: uid).get();

      double totalNote = 0;
      for (var a in avisSnap.docs) {
        totalNote += (a.data()['note'] ?? a.data()['Note'] ?? 0).toDouble();
      }
      final avg = avisSnap.docs.isEmpty ? 0.0 : totalNote / avisSnap.docs.length;

      result.add({
        'Nom_Chauffeur': c['nom'] ?? 'Inconnu',
        'Average_Note': avg,
        'Total_Avis': avisSnap.docs.length,
      });
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════
  // PROFILE
  // ════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> getProfileByUid(String uid) async {
    try {
      // Cherche dans 'users' en premier (collection principale)
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'Nom': data['nom'] ?? '',
          'Email': data['email'] ?? '',
          'Photo': data['photo'] ?? '',
          'telephone': data['telephone'] ?? '',
        };
      }
      // Cherche dans les collections spécifiques (fallback)
      for (String col in ['chauffeurs', 'clients']) {
        final colDoc = await _db.collection(col).doc(uid).get();
        if (colDoc.exists) {
          final data = colDoc.data()!;
          return {
            'Nom': data['nom'] ?? '',
            'Email': data['email'] ?? '',
            'Photo': data['photo'] ?? '',
            'telephone': data['telephone'] ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateProfile({
    required String uid,
    required String nom,
    required String telephone,
    String? photoUrl,
    String? role,
  }) async {
    final data = <String, dynamic>{
      'nom': nom,
      'telephone': telephone,
      'photo': photoUrl,
    }..removeWhere((k, v) => v == null);
    // Mettre à jour dans 'users' (collection principale)
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));

    // Mettre à jour dans la collection spécifique
    if (role == 'chauffeur') {
      await _db.collection('chauffeurs').doc(uid).set(data, SetOptions(merge: true));
    } else if (role == 'client') {
      await _db.collection('clients').doc(uid).set(data, SetOptions(merge: true));
    }
  }
}
