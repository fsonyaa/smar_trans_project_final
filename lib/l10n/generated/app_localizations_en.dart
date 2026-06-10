// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Trans';

  @override
  String get login => 'Login';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get language => 'Language';

  @override
  String get welcome => 'Welcome';

  @override
  String get logout => 'Logout';

  @override
  String get noAccount => 'No account? Create one';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get enterEmailCode =>
      'Enter your email to receive a verification code';

  @override
  String get sendCode => 'Send Code';

  @override
  String get verifyCode => 'Verify Code';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get changePassword => 'Change Password';
}
