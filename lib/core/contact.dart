import 'package:url_launcher/url_launcher.dart';

/// Dellinoo's WhatsApp number in international format, digits only.
/// TODO: replace with the client's real business number before release.
const kWhatsAppNumber = '263771234567';

/// Opens a WhatsApp chat with Dellinoo, pre-filled with [message].
/// Returns false if nothing could handle the link.
Future<bool> openWhatsApp(String message) {
  final uri = Uri.https('wa.me', '/$kWhatsAppNumber', {'text': message});
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
