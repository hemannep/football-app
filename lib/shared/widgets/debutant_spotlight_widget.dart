// lib/shared/widgets/debutant_spotlight_widget.dart
//
// Spec — Debutant Spotlight for Format Guide screen.
// Shows the 2026 World Cup debutants (first-ever WC appearance) with their
// confederation and a short note. Reads from CountryPagesService.

import 'package:flutter/material.dart';
import '../../core/services/country_pages_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/team details/team_details_screen.dart';
import 'flag_widget.dart';

class DebutantSpotlightWidget extends StatelessWidget {
  const DebutantSpotlightWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final debutants = CountryPagesService.debutants();
    if (debutants.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.brand.withValues(alpha: 0.20),
            AppTheme.brand.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌟', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DEBUTANT SPOTLIGHT',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brand)),
                    const SizedBox(height: 2),
                    Text('First-ever World Cup appearances in 2026',
                        style: TextStyle(
                            fontSize: 12,
                            color: p.textMid,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.brand,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${debutants.length}',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...debutants.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openTeam(context, d),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        FlagWidget(tla: d.tla, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: p.textHi)),
                              const SizedBox(height: 2),
                              Text(d.confederation,
                                  style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                      color: p.textLow,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.textLow),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 6),
          Text(
              'Every debutant brings something new to the world stage — tap to learn about them.',
              style: TextStyle(
                  fontSize: 11, color: p.textLow, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  void _openTeam(BuildContext context, CountryProfile profile) {
    // We don't have a team id from the static service, so we pass 0 — the
    // TeamDetailScreen will gracefully degrade (no fd.org squad fetch) and
    // still render the CountryProfileWidget for this TLA.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TeamDetailScreen(
        teamId: 0,
        fallbackName: profile.name,
        fallbackTla: profile.tla,
      ),
    ));
  }
}
