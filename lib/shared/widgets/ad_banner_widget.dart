// lib/shared/widgets/ad_banner_widget.dart
//
// IMPORTANT: As of the ad-frequency revamp, the app shows ONE persistent
// banner ad — the one pinned above the bottom nav in app.dart. Sub-screens
// must NOT add a second banner (double-banner stacks were the #1 user
// complaint in pre-launch testing).
//
// This widget therefore renders nothing. It's kept as a no-op so existing
// sub-screens that call `const AdBannerWidget()` still compile. If you ever
// want a sub-screen-specific banner (e.g. on a long content page where the
// nav-bar banner is far off-screen), build it inline rather than reviving
// this widget.

import 'package:flutter/material.dart';

class AdBannerWidget extends StatelessWidget {
  // ignore: unused_element_parameter
  final double bottomMargin;
  const AdBannerWidget({super.key, this.bottomMargin = 8});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Kept for source compatibility with older screens. Now a no-op.
class FloatingBannerOverlay extends StatelessWidget {
  const FloatingBannerOverlay({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
