import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../widgets/brand.dart';

/// Pale lavender fill for the auth inputs (the dark-mode field grey otherwise).
Color get authFieldFill => AppColors.dark ? AppColors.field : const Color(0xFFF1F0FB);

const _fieldRadius = 16.0;

/// Top of the sign up / log in screens: back arrow on the left, the full logo
/// centred, and an optional [trailing] widget on the right.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.showBack = true, this.trailing});

  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const BrandLogo(width: 200),
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                icon: Icon(IconlyLight.arrow_left_2, color: AppColors.ink),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            ),
          if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

/// Input shared by the sign up / log in screens: a lavender rounded field with
/// a leading icon and — for passwords — a show/hide toggle. With a [label] it
/// sits above the field (log in); without one the [hint] is the caption (sign up).
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.errorText,
    this.spacing = 14,
  });

  final String? label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final double spacing;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_fieldRadius);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscure && _hidden,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            fillColor: authFieldFill,
            border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(widget.icon, size: 20, color: AppColors.muted),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(_hidden ? IconlyLight.hide : IconlyLight.show, size: 20, color: AppColors.muted),
                  )
                : null,
          ),
        ),
        SizedBox(height: widget.spacing),
      ],
    );
  }
}

/// Phone input for Zimbabwe numbers: a "Phone Number" caption, then the flag
/// and +263 prefix, a divider and the 9-digit number.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({super.key, required this.controller, this.onChanged, this.spacing = 14});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          decoration: BoxDecoration(color: authFieldFill, borderRadius: BorderRadius.circular(_fieldRadius)),
          child: Row(
            children: [
              Icon(IconlyLight.call, size: 20, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone Number', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    Row(
                      children: [
                        const Text('🇿🇼', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        const Text('+263', style: TextStyle(fontWeight: FontWeight.w600)),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.muted),
                        Container(
                          width: 1,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: AppColors.line,
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            onChanged: onChanged,
                            decoration: InputDecoration(
                              hintText: 'Enter your phone number',
                              isDense: true,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing),
      ],
    );
  }
}

/// Violet gradient pill button used for "Sign Up" / "Log In".
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.buttonGradient),
          borderRadius: BorderRadius.circular(30),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 54,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                      )
                    : Text(
                        label,
                        style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "―――  OR  ―――" divider between the form and the social buttons.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}

enum SocialProvider { google, apple, facebook }

/// White outlined "Continue with …" pill with the provider's own colours.
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({super.key, required this.provider, required this.onTap});

  final SocialProvider provider;
  final VoidCallback onTap;

  static const _googleBlue = Color(0xFF4285F4);
  static const _googleGreen = Color(0xFF34A853);
  static const _googleYellow = Color(0xFFFBBC05);
  static const _googleRed = Color(0xFFEA4335);

  Widget _icon() {
    return switch (provider) {
      // The "G" is a single-colour glyph, so a hard-stop sweep paints the four brand colours onto it.
      SocialProvider.google => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const SweepGradient(
          colors: [
            _googleBlue,
            _googleBlue,
            _googleGreen,
            _googleGreen,
            _googleYellow,
            _googleYellow,
            _googleRed,
            _googleRed,
            _googleBlue,
          ],
          stops: [0, 0.12, 0.12, 0.36, 0.36, 0.6, 0.6, 0.88, 0.88],
        ).createShader(bounds),
        child: const FaIcon(FontAwesomeIcons.google, size: 20, color: Colors.white),
      ),
      SocialProvider.apple => FaIcon(FontAwesomeIcons.apple, size: 24, color: AppColors.ink),
      SocialProvider.facebook => const FaIcon(FontAwesomeIcons.facebook, size: 24, color: Color(0xFF1877F2)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (provider) {
      SocialProvider.google => 'Continue with Google',
      SocialProvider.apple => 'Continue with Apple',
      SocialProvider.facebook => 'Continue with Facebook',
    };
    return Material(
      color: AppColors.background,
      shape: StadiumBorder(side: BorderSide(color: AppColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 26, child: Center(child: _icon())),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
