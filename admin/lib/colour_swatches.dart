import 'package:flutter/material.dart';

/// Swatches for "Colour" product variants, by lower-case colour name.
///
/// A variant option is just the word typed into the product form ("Navy"),
/// which the customer app turns into a dot on the product page. It has the
/// same map in `lib/data/colour_swatches.dart` — **add new colours to both
/// files**. An unknown name still works, it just shows as a neutral grey dot
/// next to its name, which is what the preview under the field warns about.
const colourSwatches = <String, Color>{
  'black': Color(0xFF1E1E22),
  'white': Color(0xFFF4F4F4),
  'ivory': Color(0xFFFFFFF0),
  'cream': Color(0xFFE3C9A8),
  'beige': Color(0xFFE8DCC8),
  'nude': Color(0xFFE3BC9A),
  'tan': Color(0xFFD2A26D),
  'khaki': Color(0xFFBDB183),
  'brown': Color(0xFF8B5E3C),
  'chocolate': Color(0xFF5C3A21),
  'grey': Color(0xFFB5B5B8),
  'gray': Color(0xFFB5B5B8),
  'silver': Color(0xFFCFD2D6),
  'charcoal': Color(0xFF4A4D52),
  'navy': Color(0xFF1F2A52),
  'blue': Color(0xFF3A6B87),
  'royal blue': Color(0xFF2B4FB5),
  'sky blue': Color(0xFF8FC6E8),
  'denim': Color(0xFF4A6B8A),
  'teal': Color(0xFF17776F),
  'turquoise': Color(0xFF3FBFB3),
  'green': Color(0xFF2E7D4F),
  'olive': Color(0xFF6B7A3F),
  'lime': Color(0xFFA8CF45),
  'mint': Color(0xFFB7E4C7),
  'yellow': Color(0xFFF2C94C),
  'mustard': Color(0xFFD4A017),
  'gold': Color(0xFFD4AF37),
  'orange': Color(0xFFE8803A),
  'peach': Color(0xFFFFC9A3),
  'coral': Color(0xFFF08080),
  'red': Color(0xFFC62828),
  'maroon': Color(0xFF6E1B1B),
  'burgundy': Color(0xFF6B1F3A),
  'wine': Color(0xFF722F45),
  'pink': Color(0xFFF2A1C0),
  'hot pink': Color(0xFFE8559B),
  'fuchsia': Color(0xFFD6338A),
  'rose': Color(0xFFD98BA0),
  'purple': Color(0xFF7A3FBF),
  'violet': Color(0xFF5B21D6),
  'lavender': Color(0xFFC7B4E8),
  'lilac': Color(0xFFB79CE0),
  'multicolour': Color(0xFF9E9E9E),
  'multicolor': Color(0xFF9E9E9E),
};

/// The swatch for a colour name, or null when it isn't one we know.
Color? colourSwatch(String name) => colourSwatches[name.trim().toLowerCase()];
