import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service centralisé pour Firebase Auth + Firestore (users)
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────
  /// Retourne un Map avec: uid, nom, email, role, photo, id (int index)
  /// Lance une Exception en cas d'erreur
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw Exception("Utilisateur introuvable dans la base de données");
      }

      final data = doc.data()!;

      // ── Vérifier si l'admin a défini un nouveau mot de passe ──
      final pending = data['pendingPassword'];
      if (pending != null && pending.toString().isNotEmpty) {
        try {
          // L'utilisateur vient de se connecter → on peut changer son propre mot de passe
          await credential.user!.updatePassword(pending.toString());
          // Supprimer le champ une fois appliqué
          await _db.collection('users').doc(uid).update({'pendingPassword': FieldValue.delete()});
          try { await _db.collection('chauffeurs').doc(uid).update({'pendingPassword': FieldValue.delete()}); } catch (_) {}
        } catch (_) {
          // En cas d'erreur silencieuse (session expirée), on ignore
        }
      }

      return {
        'uid': uid,
        'nom': data['nom'] ?? data['name'] ?? 'Utilisateur',
        'email': data['email'] ?? email,
        'role': data['role'] ?? '',
        'photo': data['photo'] ?? '',
        'id': data['id'] ?? 0,
      };
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception("Email ou mot de passe incorrect");
        case 'user-disabled':
          throw Exception("Compte désactivé");
        case 'too-many-requests':
          throw Exception("Trop de tentatives. Réessayez plus tard");
        default:
          throw Exception("Erreur de connexion: ${e.message}");
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // REGISTER CLIENT
  // ─────────────────────────────────────────────────────────
  static Future<void> register(String nom, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;
      final int numericId = DateTime.now().millisecondsSinceEpoch % 1000000;

      final data = {
        'uid': uid,
        'nom': nom.trim(),
        'email': email.trim().toLowerCase(),
        'role': 'client',
        'photo': '',
        'id': numericId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Écrire dans 'users' (principal) ET dans 'clients' (pour FirestoreService)
      await _db.collection('users').doc(uid).set(data);
      await _db.collection('clients').doc(uid).set(data);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception("Cet email est déjà utilisé");
        case 'weak-password':
          throw Exception("Mot de passe trop faible (min 6 caractères)");
        case 'invalid-email':
          throw Exception("Email invalide");
        default:
          throw Exception("Erreur d'inscription: ${e.message}");
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // ADD CHAUFFEUR (admin only)
  // ─────────────────────────────────────────────────────────
  static Future<void> addChauffeur(String nom, String email, String password) async {
    try {
      // Créer l'auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );
      final uid = credential.user!.uid;
      final int numericId = DateTime.now().millisecondsSinceEpoch % 1000000;

      final data = {
        'uid': uid,
        'nom': nom.trim(),
        'email': email.trim().toLowerCase(),
        'role': 'chauffeur',
        'photo': '',
        'id': numericId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Écrire dans 'users' (principal) ET dans 'chauffeurs' (pour FirestoreService stats/lignes/bus)
      await _db.collection('users').doc(uid).set(data);
      await _db.collection('chauffeurs').doc(uid).set(data);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("Cet email est déjà utilisé");
      }
      throw Exception("Erreur: ${e.message}");
    }
  }

  // ─────────────────────────────────────────────────────────
  // RESET PASSWORD
  // ─────────────────────────────────────────────────────────
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception("Aucun compte avec cet email");
      }
      throw Exception("Erreur: ${e.message}");
    }
  }

  // ─────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─────────────────────────────────────────────────────────
  // GET PROFILE
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE PROFILE
  // ─────────────────────────────────────────────────────────
  static Future<void> updateProfile({
    required String uid,
    required String nom,
    required String email,
    String? password,
    String? photo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Non connecté");

    final Map<String, dynamic> updates = {
      'nom': nom.trim(),
      'email': email.trim().toLowerCase(),
    };
    if (photo != null) updates['photo'] = photo;

    await _db.collection('users').doc(uid).update(updates);

    if (password != null && password.isNotEmpty) {
      await user.updatePassword(password.trim());
    }
  }

  // ─────────────────────────────────────────────────────────
  // UPDATE CHAUFFEUR (by admin)
  // ─────────────────────────────────────────────────────────
  static Future<void> updateChauffeurData({
    required String uid,
    required String nom,
    required String email,
    String? password,
  }) async {
    final data = {
      'nom': nom.trim(),
      'email': email.trim().toLowerCase(),
    };
    // Mettre à jour dans les deux collections
    await _db.collection('users').doc(uid).update(data);
    try { await _db.collection('chauffeurs').doc(uid).update(data); } catch (_) {}

    // Si un nouveau mot de passe est fourni, le stocker pour réinitialisation
    // (nécessite que l'admin soit connecté en tant que cet utilisateur via Firebase Admin SDK
    // ou Cloud Function – ici on stocke dans Firestore pour traitement serveur)
    if (password != null && password.trim().isNotEmpty) {
      await _db.collection('users').doc(uid).update({'pendingPassword': password.trim()});
      try { await _db.collection('chauffeurs').doc(uid).update({'pendingPassword': password.trim()}); } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────
  // DELETE USER DOC (chauffeur by admin)
  // ─────────────────────────────────────────────────────────
  static Future<void> deleteUserDoc(String uid) async {
    await _db.collection('users').doc(uid).delete();
    try { await _db.collection('chauffeurs').doc(uid).delete(); } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────
  // GET ALL CHAUFFEURS
  // ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAllChauffeurs() async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'chauffeur')
        .get();
    return snapshot.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  // ─────────────────────────────────────────────────────────
  // CURRENT USER UID
  // ─────────────────────────────────────────────────────────
  static String? get currentUid => _auth.currentUser?.uid;
}
