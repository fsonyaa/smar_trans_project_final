// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Smart Trans';

  @override
  String get login => 'Connexion';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get language => 'Langue';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get logout => 'Déconnexion';

  @override
  String get noAccount => 'Pas de compte ? Créer un compte';

  @override
  String get resetPassword => 'Réinitialisation';

  @override
  String get enterEmailCode =>
      'Entrez votre email pour recevoir un code de vérification';

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get verifyCode => 'Vérifier le code';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get changePassword => 'Changer le mot de passe';
}
