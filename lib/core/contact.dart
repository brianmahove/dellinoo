import 'package:url_launcher/url_launcher.dart';

/// Dellinoo's WhatsApp number in international format, digits only.
const kWhatsAppNumber = '8613162952997';

/// Opens a WhatsApp chat with Dellinoo, pre-filled with [message].
/// Returns false if nothing could handle the link.
Future<bool> openWhatsApp(String message) {
  final uri = Uri.https('wa.me', '/$kWhatsAppNumber', {'text': message});
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens WhatsApp's own contact/group picker with [message] pre-filled, so
/// the customer can share to whoever they like — no recipient, unlike
/// [openWhatsApp] which always messages Dellinoo. Returns false if nothing
/// could handle the link.
Future<bool> shareToWhatsApp(String message) {
  final uri = Uri.https('wa.me', '/', {'text': message});
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens [url] in the phone's browser. Returns false if nothing could handle it.
Future<bool> openLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
