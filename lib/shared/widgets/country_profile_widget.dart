// lib/shared/widgets/country_profile_widget.dart
//
// Drop-in widget for the team details screen. Renders the "Country Fan Page"
// content from CountryPagesService when the team's TLA matches a known
// national side. Returns SizedBox.shrink() otherwise.

import 'package:flutter/material.dart';
import '../../core/services/country_pages_service.dart';
import '../../core/theme/app_theme.dart';

class CountryProfileWidget extends StatelessWidget {
  final String tla;
  const CountryProfileWidget({super.key, required this.tla});

  @override
  Widget build(BuildContext context) {
    final profile = CountryPagesService.find(tla);
    if (profile == null) return const SizedBox.shrink();
    final p = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Debutant badge ────────────────────────────────────────────
        if (profile.isDebutant)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.brand,
                  AppTheme.brand.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.r),
            ),
            child: Row(
              children: [
                const Text('🌟', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('2026 DEBUTANT',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(
                          '${profile.name} is making their first-ever global tournament appearance in 2026.',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ─── Achievements ──────────────────────────────────────────────
        const _SectionHeader(text: 'ACHIEVEMENTS'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppTheme.r),
            border: Border.all(color: p.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: profile.achievements
                .map((a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.emoji_events_rounded,
                                size: 14, color: AppTheme.warn),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(a,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: p.textMid,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),

        // ─── Star players ──────────────────────────────────────────────
        if (profile.starPlayers.isNotEmpty) ...[
          const _SectionHeader(text: 'STAR PLAYERS'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppTheme.r),
              border: Border.all(color: p.stroke),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.starPlayers
                  .map((n) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.brand.withValues(alpha: 0.3)),
                        ),
                        child: Text(n,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brand)),
                      ))
                  .toList(),
            ),
          ),
        ],

        // ─── Legend + journey ─────────────────────────────────────────
        if (profile.legendaryPlayer != null ||
            profile.qualificationJourney.isNotEmpty ||
            profile.bestWcFinish != null ||
            profile.funFact != null) ...[
          const _SectionHeader(text: 'COUNTRY PROFILE'),
          if (profile.legendaryPlayer != null)
            _InfoCard(
                p: p,
                icon: '👑',
                title: 'All-time legend',
                value: profile.legendaryPlayer!),
          if (profile.bestWcFinish != null)
            _InfoCard(
                p: p,
                icon: '🏆',
                title: 'Best WC finish',
                value: _ordinal(profile.bestWcFinish!) +
                    (profile.bestWcYear != null
                        ? ' (${profile.bestWcYear})'
                        : '')),
          if (profile.qualificationJourney.isNotEmpty)
            _InfoCard(
                p: p,
                icon: '🛣️',
                title: 'Qualification journey',
                value: profile.qualificationJourney),
          if (profile.coach != null && profile.coach!.isNotEmpty)
            _InfoCard(
                p: p, icon: '🧠', title: 'Head coach', value: profile.coach!),
          if (profile.confederation.isNotEmpty)
            _InfoCard(
                p: p,
                icon: '🌍',
                title: 'Confederation',
                value: profile.confederation),
          if (profile.funFact != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warn.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(profile.funFact!,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: p.textMid,
                            fontWeight: FontWeight.w700,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
              color: p.textLow)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Palette p;
  final String icon;
  final String title;
  final String value;
  const _InfoCard({
    required this.p,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: p.textLow)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        color: p.textHi,
                        fontWeight: FontWeight.w700,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
