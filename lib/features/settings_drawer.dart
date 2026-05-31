// lib/features/settings_drawer.dart — complete drop-in replacement
//
// Updated: import path for AppL10n changed from package:flutter_gen/... to
// the new physical path at lib/l10n/generated/app_localizations.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers/locale_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/services/ad_service.dart';
import '../core/services/iap_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/iap_status_widget.dart';
import 'new fan mode/new_fan_mode_screen.dart';
import 'offline pack/offline_pack_screen.dart';
import 'settings/language_picker_screen.dart';
import 'news/news_screen.dart';
import 'format_guide/format_guide_screen.dart';
import 'team_comparison/team_comparison_screen.dart';
import 'qualification_simulator/qualification_simulator_screen.dart';

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final t = AppL10n.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    // Current language native name (e.g. "हिन्दी", "日本語"), so users see
    // which language is currently active without reading the label.
    final localeCode = ref.watch(localeProvider).languageCode;
    final localeNativeName = languageNativeNames[localeCode] ?? localeCode;

    return Drawer(
      backgroundColor: p.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header (fixed at top) ────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                gradient: p.heroGradient,
                border: Border(bottom: BorderSide(color: p.stroke, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sports_soccer,
                        color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.appName,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: p.textHi)),
                        const SizedBox(height: 2),
                        Text('Version 1.0',
                            style: TextStyle(fontSize: 11, color: p.textMid)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable menu items ────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // IAP status (only shown if not yet ads-removed; auto-hides
                  // post-purchase). Includes one-tap Restore button.
                  const IapStatusWidget(),
                  const _SectionLabel('APPEARANCE'),
                  _SwitchTile(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    label: t.settingsDarkMode,
                    value: isDark,
                    onChanged: (_) =>
                        ref.read(themeModeProvider.notifier).toggle(),
                  ),

                  _SectionLabel(t.settingsTitle.toUpperCase()),
                  _Tile(
                    icon: Icons.language_rounded,
                    label: t.settingsLanguage,
                    trailing: localeNativeName,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const LanguagePickerScreen()));
                    },
                  ),
                  _Tile(
                    icon: Icons.notifications_outlined,
                    label: t.settingsNotifications,
                    trailing: 'Soon',
                    onTap: () => _toast(context, 'Push notifications coming soon'),
                  ),

                  // ── Bonus features ──────────────────────────────────────
                  const _SectionLabel('FEATURES'),
                  _Tile(
                    icon: Icons.article_outlined,
                    label: 'Football News',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const NewsScreen()));
                    },
                  ),
                  _Tile(
                    icon: Icons.menu_book_rounded,
                    label: 'Format Guide',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const FormatGuideScreen()));
                    },
                  ),
                  _Tile(
                    icon: Icons.school_outlined,
                    label: t.newFanModeCta,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const NewFanModeScreen()));
                    },
                  ),
                  _Tile(
                    icon: Icons.compare_arrows_rounded,
                    label: t.compareTitle,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const TeamComparisonScreen()));
                    },
                  ),
                  _Tile(
                    icon: Icons.calculate_outlined,
                    label: t.qualSimTitle,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              const QualificationSimulatorScreen()));
                    },
                  ),
                  _Tile(
                    icon: Icons.cloud_download_outlined,
                    label: t.offlinePackTitle,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const OfflinePackScreen()));
                    },
                  ),

                  const _SectionLabel('SUPPORT'),
                  _Tile(
                    icon: Icons.mail_outline_rounded,
                    label: t.settingsFeedback,
                    onTap: () => _email(),
                  ),
                  _Tile(
                    icon: Icons.star_outline_rounded,
                    label: t.settingsRateUs,
                    onTap: () => _launch(
                        'https://play.google.com/store/apps/details?id=com.mangojuice.footballfanhub2026'),
                  ),
                  _Tile(
                    icon: Icons.share_outlined,
                    label: t.settingsShareApp,
                    onTap: () => Share.share(
                      'Check out ${t.appName} — free scores, predictor, trivia & bracket!\n\n'
                      'https://play.google.com/store/apps/details?id=com.mangojuice.footballfanhub2026',
                    ),
                  ),
                  _Tile(
                    icon: Icons.privacy_tip_outlined,
                    label: t.settingsPrivacyPolicy,
                    onTap: () => _toast(context, 'Coming soon'),
                  ),
                  _Tile(
                    icon: Icons.description_outlined,
                    label: t.settingsTerms,
                    onTap: () => _toast(context, 'Coming soon'),
                  ),

                  if (!AdService.adsRemoved) ...[
                    const _SectionLabel('SUPPORT THE APP'),
                    _Tile(
                      icon: Icons.block_rounded,
                      label: t.settingsRemoveAds,
                      trailing: '\$1.99',
                      onTap: () async {
                        await IapService.buyRemoveAds();
                        if (context.mounted) Navigator.pop(context);
                      },
                      accent: true,
                    ),
                    _Tile(
                      icon: Icons.restore_rounded,
                      label: t.settingsRestorePurchases,
                      onTap: () => IapService.restore(),
                    ),
                  ] else ...[
                    const _SectionLabel('SUPPORT THE APP'),
                    _Tile(
                      icon: Icons.verified_rounded,
                      label: t.settingsAdsRemoved,
                      onTap: () => _toast(context, t.settingsAdsRemovedThanks),
                      accent: true,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Footer (fixed at bottom) ─────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.stroke, width: 1)),
              ),
              child: Column(
                children: [
                  Text('${t.appName} v1.0',
                      style: TextStyle(fontSize: 11, color: p.textLow)),
                  const SizedBox(height: 2),
                  Text('© 2026 • Built with ❤️ in Nepal',
                      style: TextStyle(fontSize: 10, color: p.textLow)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'feedback@footballfanhub2026.app',
      query: 'subject=App%20Feedback',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.brand,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  final bool accent;
  const _Tile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: accent ? AppTheme.brand : p.textMid),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accent ? AppTheme.brand : p.textHi)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: TextStyle(
                      fontSize: 12,
                      color: p.textLow,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded, size: 18, color: p.textLow),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.textMid),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.textHi)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.brand,
          ),
        ],
      ),
    );
  }
}
