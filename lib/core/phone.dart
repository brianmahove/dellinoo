/// Zimbabwe-only phone numbers. The app is limited to Zimbabwe, so every phone
/// the customer types (sign-up, addresses, wallet number) goes through here.
///
/// Mobile prefixes accepted: 71 and 72 NetOne, 73 Telecel, 77/78/79 Econet. Landlines and foreign
/// numbers are rejected. This is a format check, not proof the person owns the
/// number (that would need SMS verification).
library;

final _mobile = RegExp(r'^7[123789]\d{7}$');

/// The 9 national digits (`771234567`) from `0771234567`, `771234567`,
/// `+263 77 123 4567` or `00263771234567`; null if it isn't a Zimbabwe mobile.
String? zimNationalDigits(String input) {
  var d = input.replaceAll(RegExp(r'[\s\-()]'), '');
  if (d.startsWith('+')) d = d.substring(1);
  if (d.startsWith('00263')) {
    d = d.substring(5);
  } else if (d.startsWith('263')) {
    d = d.substring(3);
  } else if (d.startsWith('0')) {
    d = d.substring(1);
  }
  return _mobile.hasMatch(d) ? d : null;
}

bool isZimMobile(String input) => zimNationalDigits(input) != null;

/// `+263 77 123 4567`, or null when [input] isn't valid.
String? formatZimPhone(String input) {
  final d = zimNationalDigits(input);
  if (d == null) return null;
  return '+263 ${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5)}';
}

/// Econet (77/78/79) is the only network EcoCash runs on.
bool isEconet(String input) {
  final d = zimNationalDigits(input);
  return d != null && (d.startsWith('77') || d.startsWith('78') || d.startsWith('79'));
}

const zimPhoneHint = 'Enter a Zimbabwe mobile number, e.g. 077 123 4567';
