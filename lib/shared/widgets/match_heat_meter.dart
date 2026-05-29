// lib/shared/widgets/match_heat_meter.dart
//
// "Match Heat" gauge (spec #6). Reads from MatchInsightsService.heatFor().
//
// Designed to drop into the Summary tab of match details OR onto a match
// card. Compact (single row) or expanded (with gauge bar).

import 'package:flutter/material.dart';
import '../../core/services/extras_service.dart';
import '../../core/services/match_insights_service.dart';
import '../../core/theme/app_theme.dart';
import '../models/match.dart';

class MatchHeatMeter extends StatelessWidget {
  final Match match;
  final List<MatchIncident>? incidents;
  final bool compact;
  const MatchHeatMeter({
    super.key,
    required this.match,
    this.incidents,
    this.compact = false,
  });

  Color _color(int heat) {
    if (heat < 25) return Colors.blueAccent;
    if (heat < 50) return AppTheme.warn;
    if (heat < 75) return Colors.deepOrange;
    return AppTheme.live;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final heat = MatchInsightsService.heatFor(match, incidents: incidents);
    if (heat.heat <= 0) return const SizedBox.shrink();
    final color = _color(heat.heat);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heat.emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text('${heat.heat}%',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('MATCH HEAT',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
              const Spacer(),
              Text(heat.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('${heat.heat}%',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: p.surfaceHi,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: heat.heat / 100.0,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.7),
                          color,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(heat.label,
              style: TextStyle(
                  fontSize: 11, color: p.textLow, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
