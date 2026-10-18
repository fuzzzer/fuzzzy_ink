import 'package:url_launcher/url_launcher.dart';

/// The company pages the stores require the app to link to (T-0422).
///
/// The app itself never goes online: a link is handed to the system browser
/// ([LaunchMode.externalApplication]), never an in-app web view or a fetch.
class ExternalLinks {
  const ExternalLinks._();

  static final privacyPolicy = Uri.parse('https://fuzzzycore.com/privacy');
  static final terms = Uri.parse('https://fuzzzycore.com/terms');
  static final support = Uri.parse('https://fuzzzycore.com/support');
  static final dataDeletion =
      Uri.parse('https://fuzzzycore.com/account-deletion');

  /// Opens [uri] in the system browser; answers false when no app took it.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
