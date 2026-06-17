import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/providers/selected_leagues_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/leagues.dart';

/// Compact chip showing the current league. Tap → opens league sheet.
class LeaguePickerChip extends ConsumerWidget {
  const LeaguePickerChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final league = ref.watch(selectedLeagueProvider);
    final liveCount =
        ref.watch(liveScoreProvider).matches.where((m) => m.isLive).length;
    return GestureDetector(
      onTap: () => showLeagueSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: liveCount > 0
                ? AppTheme.live.withValues(alpha: 0.5)
                : AppTheme.brand.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(league.icon, size: 16, color: AppTheme.brand),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                league.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: p.textHi,
                ),
              ),
            ),
            if (liveCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.live,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$liveCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: p.textMid),
          ],
        ),
      ),
    );
  }
}

void showLeagueSheet(BuildContext context, WidgetRef ref) {
  final p = AppTheme.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        child: Consumer(
          builder: (ctx, r, _) {
            final current = r.watch(selectedLeagueProvider);
            final allMatches = r.watch(liveScoreProvider).matches;
            // Count live + total matches per competition code
            Map<String, int> liveByCode = {};
            Map<String, int> totalByCode = {};
            for (final m in allMatches) {
              final code = m.competitionCode ?? '';
              totalByCode[code] = (totalByCode[code] ?? 0) + 1;
              if (m.isLive) liveByCode[code] = (liveByCode[code] ?? 0) + 1;
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Row(
                    children: [
                      Text('Select competition',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: p.textHi)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: Leagues.all.length,
                    itemBuilder: (_, i) {
                      final l = Leagues.all[i];
                      final isSelected = l.code == current.code;
                      final isPriority = l.sortPriority < 5;
                      return InkWell(
                        onTap: () {
                          r.read(selectedLeagueProvider.notifier).select(l);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.brand
                                      : AppTheme.brand.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(l.icon,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.black
                                        : AppTheme.brand),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(l.name,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: p.textHi)),
                                        if (isPriority) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent
                                                  .withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text('TOP',
                                                style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppTheme.accent,
                                                    letterSpacing: 0.8)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(l.country,
                                        style: TextStyle(
                                            fontSize: 11, color: p.textLow)),
                                  ],
                                ),
                              ),
                              if ((liveByCode[l.code] ?? 0) > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.live,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${liveByCode[l.code]} LIVE',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else if ((totalByCode[l.code] ?? 0) > 0) ...[
                                Text(
                                  '${totalByCode[l.code]}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: p.textLow),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.brand, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      );
    },
  );
}
