import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/contact.dart';
import '../../core/iconly.dart';
import '../../core/theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'About'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Center(child: BrandMark(size: 84)),
          const SizedBox(height: 16),
          const Center(
            child: Text(AppInfo.name, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          ),
          Center(
            child: Text('Version ${AppInfo.version}', style: TextStyle(color: AppColors.muted, fontSize: 14)),
          ),
          const SizedBox(height: 22),
          SurfaceCard(
            margin: EdgeInsets.zero,
            child: Text(
              '${AppInfo.name} brings fashion, shoes, phones, laptops and electronics to Zimbabwe — '
              'in stock for fast delivery, or ordered for you straight from China. '
              'Pay with EcoCash, OneMoney, InnBucks or card.',
              style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 14.5),
            ),
          ),
          const SizedBox(height: 14),
          // Developer credit.
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openLink(AppInfo.developerUrl),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Designed & developed by',
                          style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // The logo has white lettering for dark surfaces; the light version is recoloured navy.
                    Image.asset(
                      AppColors.dark ? 'assets/images/vizion_logo_dark.png' : 'assets/images/vizion_logo_light.png',
                      height: 8,
                      semanticLabel: AppInfo.developer,
                    ),
                    const Spacer(),
                    const _NudgingIcon(Icons.open_in_new),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(IconlyLight.document, color: AppColors.ink),
              title: const Text('Open-source licences', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Libraries and icons used in this app', style: TextStyle(color: AppColors.muted)),
              trailing: Icon(IconlyLight.arrow_right_2, color: AppColors.muted),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppInfo.name,
                applicationVersion: AppInfo.version,
                applicationIcon: const Padding(padding: EdgeInsets.all(12), child: BrandMark(size: 48)),
                applicationLegalese: '${AppInfo.copyright}\nDesigned & developed by ${AppInfo.developer}.',
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              AppInfo.copyright,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon that gently drifts up and right, hinting that the card opens a link.
class _NudgingIcon extends StatefulWidget {
  const _NudgingIcon(this.icon);

  final IconData icon;

  @override
  State<_NudgingIcon> createState() => _NudgingIconState();
}

class _NudgingIconState extends State<_NudgingIcon> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: AppColors.muted, size: 20);
    if (reduceMotion(context)) return icon;
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      child: icon,
      builder: (_, child) => Transform.translate(offset: Offset(3 * curve.value, -3 * curve.value), child: child),
    );
  }
}
