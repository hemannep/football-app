import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/selected_leagues_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/iap_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/leagues.dart';
import '../../shared/models/standing.dart';
import '../../shared/widgets/flag_widget.dart';
import '../../shared/widgets/debutant_spotlight_widget.dart';
import '../league picker/league_picker.dart';

class FormatGuideScreen extends ConsumerStatefulWidget {
  const FormatGuideScreen({super.key});
  @override
  ConsumerState<FormatGuideScreen> createState() => _FormatGuideScreenState();
}

class _FormatGuideScreenState extends ConsumerState<FormatGuideScreen> {
  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final league = ref.watch(selectedLeagueProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Format Guide',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: p.textHi)),
                    ),
                    const LeaguePickerChip(),
                  ],
                ),
              ),
            ),
            if (league.code == Leagues.wc.code) ...[
              SliverToBoxAdapter(child: _wcHero(p)),
              SliverToBoxAdapter(child: _thirdPlaceExplainer(p)),
              SliverToBoxAdapter(child: _calcCta(p)),
              const SliverToBoxAdapter(child: DebutantSpotlightWidget()),
            ] else ...[
              SliverToBoxAdapter(child: _leagueHero(p, league)),
            ],
            const SliverToBoxAdapter(child: SectionLabel('SUPPORT THE APP')),
            SliverToBoxAdapter(child: _removeAdsCard(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _wcHero(Palette p) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: p.heroGradient,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('48-TEAM FORMAT',
                style: TextStyle(
                    color: AppTheme.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3)),
            const SizedBox(height: 12),
            _flow('48 teams', '12 groups of 4', 48, p),
            _arrow(p),
            _flow('Group stage', 'Top 2 + 8 best 3rds', 32, p),
            _arrow(p),
            _flow('Round of 32', 'Knockout begins', 16, p),
            _arrow(p),
            _flow('Round of 16', '', 8, p),
            _arrow(p),
            _flow('Quarter-Finals', '', 4, p),
            _arrow(p),
            _flow('Semi-Finals', '', 2, p),
            _arrow(p),
            _flow('Final', 'July 19, 2026', 1, p, last: true),
          ],
        ),
      );

  Widget _leagueHero(Palette p, League l) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: p.heroGradient,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(l.icon, color: AppTheme.brand, size: 18),
                const SizedBox(width: 8),
                Text(l.name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.textHi)),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.country, style: TextStyle(color: p.textMid, fontSize: 12)),
            const SizedBox(height: 16),
            if (l.isKnockout)
              Text(
                'A knockout competition. Top teams from group stage advance to single-leg / two-leg knockouts until one champion remains.',
                style: TextStyle(color: p.textMid, fontSize: 13, height: 1.5),
              )
            else
              Text(
                'A round-robin domestic league. Teams play home & away. Standings decide the champion, European spots, and relegation.',
                style: TextStyle(color: p.textMid, fontSize: 13, height: 1.5),
              ),
            const SizedBox(height: 12),
            Text(
              'Switch the competition above to see other formats.',
              style: TextStyle(
                  color: p.textLow, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );

  Widget _flow(String label, String sub, int n, Palette p,
      {bool last = false}) {
    return Row(
      children: [
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: last
                ? const LinearGradient(
                    colors: [Color(0xFFFFD600), Color(0xFFFF6E40)])
                : AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$n',
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.textHi)),
              if (sub.isNotEmpty)
                Text(sub, style: TextStyle(color: p.textLow, fontSize: 12)),
            ],
          ),
        ),
        if (last) const Text('🏆', style: TextStyle(fontSize: 22)),
      ],
    );
  }

  Widget _arrow(Palette p) => Padding(
        padding: const EdgeInsets.only(left: 18, top: 2, bottom: 2),
        child: Icon(Icons.arrow_downward_rounded, color: p.textLow, size: 14),
      );

  Widget _thirdPlaceExplainer(Palette p) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(16),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.warn.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help_outline_rounded,
                      color: AppTheme.warn, size: 18),
                ),
                const SizedBox(width: 8),
                Text('How 3rd-place teams qualify',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: p.textHi)),
              ],
            ),
            const SizedBox(height: 12),
            Text('All 12 third-placed teams are ranked. The top 8 advance:',
                style: TextStyle(color: p.textMid, fontSize: 13, height: 1.5)),
            const SizedBox(height: 10),
            _bullet('1', 'Points', p),
            _bullet('2', 'Goal difference', p),
            _bullet('3', 'Goals scored', p),
            _bullet('4', 'World ranking (tiebreaker)', p),
          ],
        ),
      );

  Widget _bullet(String n, String text, Palette p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(n,
                  style: const TextStyle(
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textHi)),
          ],
        ),
      );

  Widget _calcCta(Palette p) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: p.heroGradient,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: AppTheme.brand.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calculate_rounded,
                  color: Colors.black, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('3rd-Place Calculator',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: p.textHi)),
                  Text('Auto-loads real standings — tweak to see who qualifies',
                      style: TextStyle(color: p.textMid, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded,
                  color: AppTheme.brand),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _ThirdPlaceCalcScreen())),
            ),
          ],
        ),
      );

  Widget _removeAdsCard(Palette p) {
    final removed = AdService.adsRemoved;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(
            color: removed ? AppTheme.brand.withValues(alpha: 0.4) : p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    removed ? Icons.verified_rounded : Icons.block_rounded,
                    color: AppTheme.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(removed ? 'Ads removed' : 'Remove ads monthly',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                    Text(
                        removed
                            ? 'Thanks for supporting!'
                            : '\$1.99/month subscription',
                        style: TextStyle(fontSize: 12, color: p.textMid)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: removed
                      ? null
                      : () async {
                          final started = await IapService.buyRemoveAds();
                          if (!started && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Subscription is not available yet. Try again soon.'),
                              ),
                            );
                          }
                          if (mounted) setState(() {});
                        },
                  child: Text(removed ? 'Active subscription ✓' : 'Subscribe'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await IapService.restore();
                  if (mounted) setState(() {});
                },
                child: const Text('Restore'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 3rd-Place calculator — auto-loads real standings ───────────────────────

class _ThirdPlaceCalcScreen extends ConsumerStatefulWidget {
  const _ThirdPlaceCalcScreen();
  @override
  ConsumerState<_ThirdPlaceCalcScreen> createState() =>
      _ThirdPlaceCalcScreenState();
}

class _ThirdPlaceCalcScreenState extends ConsumerState<_ThirdPlaceCalcScreen> {
  /// Editable rows: group → (teamName, tla, points, GD, GF)
  final Map<String, _Row> _rows = {};
  bool _initialised = false;

  void _seedFromApi(List<GroupTable> groups) {
    if (_initialised) return;
    for (final g in groups) {
      if (g.teams.length >= 3) {
        final t = g.teams[2];
        _rows[g.groupName] = _Row(
          name: t.teamName,
          tla: t.tla,
          points: t.points,
          gd: t.goalDifference,
          gf: t.goalsFor,
        );
      }
    }
    if (_rows.isEmpty) {
      // No API data → seed 12 empty groups for hypothetical play.
      for (var i = 0; i < 12; i++) {
        final letter = String.fromCharCode(65 + i);
        _rows['Group $letter'] =
            _Row(name: '3rd place', tla: '???', points: 3, gd: 0, gf: 0);
      }
    }
    _initialised = true;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final async = ref.watch(standingsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('3rd-Place Calculator')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          _seedFromApi(const []);
          return _content(p);
        },
        data: (groups) {
          _seedFromApi(groups);
          return _content(p);
        },
      ),
    );
  }

  Widget _content(Palette p) {
    final keys = _rows.keys.toList();
    final ranked = [...keys]..sort((a, b) {
        final ra = _rows[a]!;
        final rb = _rows[b]!;
        if (rb.points != ra.points) return rb.points.compareTo(ra.points);
        if (rb.gd != ra.gd) return rb.gd.compareTo(ra.gd);
        return rb.gf.compareTo(ra.gf);
      });

    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Real standings auto-loaded. Tweak any numbers to model scenarios.',
            style: TextStyle(color: p.textMid, fontSize: 12),
          ),
        ),
        const SectionLabel('INPUTS'),
        ...keys.map((k) => _editRow(k, _rows[k]!, p)),
        const SectionLabel('QUALIFICATION ORDER'),
        ...ranked.asMap().entries.map((e) {
          final pos = e.key + 1;
          final k = e.value;
          final r = _rows[k]!;
          final qual = pos <= 8;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      qual ? AppTheme.good.withValues(alpha: 0.4) : p.stroke),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: qual ? AppTheme.good : AppTheme.bad,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('$pos',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12)),
                ),
                const SizedBox(width: 10),
                FlagWidget(tla: r.tla, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${r.name} • $k',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: p.textHi)),
                ),
                Text('${r.points}p • GD ${r.gd} • GF ${r.gf}',
                    style: TextStyle(fontSize: 11, color: p.textMid)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _editRow(String group, _Row r, Palette p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group, style: TextStyle(fontSize: 11, color: p.textLow)),
                Text(r.tla,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: p.textHi)),
              ],
            ),
          ),
          Expanded(
              child:
                  _num('Pts', r.points, (v) => setState(() => r.points = v))),
          Expanded(child: _num('GD', r.gd, (v) => setState(() => r.gd = v))),
          Expanded(child: _num('GF', r.gf, (v) => setState(() => r.gf = v))),
        ],
      ),
    );
  }

  Widget _num(String label, int v, ValueChanged<int> on) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextFormField(
          initialValue: '$v',
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: (s) => on(int.tryParse(s) ?? 0),
        ),
      );
}

class _Row {
  String name, tla;
  int points, gd, gf;
  _Row(
      {required this.name,
      required this.tla,
      required this.points,
      required this.gd,
      required this.gf});
}
