import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// The admin's profile picture (e.g. their Google photo), or their initial if
/// there isn't one or it fails to load.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, required this.radius});

  final User user;
  final double radius;

  /// `User.photoURL` is often null for accounts that also have a password
  /// login even when Google supplied a picture, so fall back to the linked
  /// providers' own photos.
  static String? photoOf(User user) {
    final direct = user.photoURL;
    if (direct != null && direct.isNotEmpty) return direct;
    for (final p in user.providerData) {
      if (p.photoURL != null && p.photoURL!.isNotEmpty) return p.photoURL;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final photo = photoOf(user);
    final initial = (user.email ?? user.displayName ?? '?').substring(0, 1).toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: radius * 0.75),
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      child: photo == null
          ? fallback
          : ClipOval(
              child: Image.network(
                photo,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                // Google's image host doesn't send CORS headers, which breaks
                // canvas-drawn images on web; an <img> element doesn't care.
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
              ),
            ),
    );
  }
}
