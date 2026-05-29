// lib/shared/widgets/rivalry_card_widget.dart
//
// Spec feature #13. Drop into the Summary tab of match details. Only renders
// when the two teams are a recognised rivalry (RivalriesService.find returns
// non-null) — otherwise it shrinks to zero.

import 'package:flutter/material.dart';
import '../../core/services/rivalries_service.dart';
import '../../core/theme/app_theme.dart';

class RivalryCardWidget extends StatelessWidget {
  final String homeTla;
  final String awayTla;
  const RivalryCardWidget(
      {super.key, required this.homeTla, required this.awayTla});

  @override
  Widget build(BuildContext context) {
    final r = RivalriesService.find(homeTla, awayTla);
    if (r == null) return const SizedBox.shrink();
    final p = AppTheme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.live.withValues(alpha: 0.20),
            AppTheme.brand.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.live.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              const Text('CLASSIC RIVALRY',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.live)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: p.surfaceHi,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(r.region.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: p.textLow,
                        letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.name,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: p.textHi)),
          if (r.nickname != null) ...[
            const SizedBox(height: 2),
            Text('"${r.nickname}"',
                style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.live,
                    fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          Text(r.origin,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: p.textMid,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text('MEMORABLE MOMENTS',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: p.textLow)),
          const SizedBox(height: 6),
          ...r.moments.take(5).map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(m,
                          style: TextStyle(
                              fontSize: 12, height: 1.4, color: p.textMid)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
