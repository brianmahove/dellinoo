/// App identity and credits, shown on the About page, Profile and splash.
abstract final class AppInfo {
  static const name = 'Dellinoo';
  static const version = '1.0.0';
  static const tagline = 'Shop the world, delivered in Zim';

  /// Studio that designed and built the app.
  static const developer = 'vizion';
  static const developerUrl = 'https://viziontechnologies.vercel.app/';
  static const copyright = '© 2026 Dellinoo. All rights reserved.';

  /// Legal pages on Firebase Hosting (also what Play Store / Facebook App
  /// Review point at — keep in sync with hosting/).
  static const privacyUrl = 'https://mobile-billing-system-d2bfb.web.app/privacy.html';
  static const dataDeletionUrl = 'https://mobile-billing-system-d2bfb.web.app/data-deletion.html';
}
