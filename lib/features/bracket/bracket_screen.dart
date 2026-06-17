import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/providers/selected_leagues_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/team_crest_widget.dart';
import '../league picker/league_picker.dart';

class BracketScreen extends ConsumerStatefulWidget {
  const BracketScreen({super.key});
  @override
  ConsumerState<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends ConsumerState<BracketScreen> {
  late List<_BT> _r32;
  late List<_BT?> _r16, _qf, _sf, _f;
  _BT? _champion;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _r32 = List.generate(32, (i) => _BT('Team ${i + 1}', 'T${i + 1}'));
    _r16 = List.filled(16, null);
    _qf = List.filled(8, null);
    _sf = List.filled(4, null);
    _f = List.filled(2, null);
    _champion = null;
  }

  void _autoFill() {
    final s = ref.read(liveScoreProvider);
    final league = ref.read(selectedLeagueProvider);
    final teams = <_BT>{};
    for (final m in s.matches) {
      if (m.competitionCode != league.code) continue;
      teams.add(_BT(m.homeTeam.name, m.homeTeam.tla, m.homeTeam.crest));
      teams.add(_BT(m.awayTeam.name, m.awayTeam.tla, m.awayTeam.crest));
      if (teams.length >= 32) break;
    }
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No ${league.name} matches loaded yet.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    setState(() {
      _r32 = teams.take(32).toList();
      while (_r32.length < 32) {
        _r32.add(_BT('Team ${_r32.length + 1}', 'T${_r32.length + 1}'));
      }
      // Clear downstream rounds when teams change.
      _r16 = List.filled(16, null);
      _qf = List.filled(8, null);
      _sf = List.filled(4, null);
      _f = List.filled(2, null);
      _champion = null;
    });
  }

  void _pick(int round, int slot, _BT pick) {
    HapticFeedback.lightImpact();
    setState(() {
      if (round == 0) {
        _r16[slot ~/ 2] = pick;
        _qf[slot ~/ 4] = null;
        _sf[slot ~/ 8] = null;
        _f[slot ~/ 16] = null;
        _champion = null;
      } else if (round == 1) {
        _qf[slot ~/ 2] = pick;
        _sf[slot ~/ 4] = null;
        _f[slot ~/ 8] = null;
        _champion = null;
      } else if (round == 2) {
        _sf[slot ~/ 2] = pick;
        _f[slot ~/ 4] = null;
        _champion = null;
      } else if (round == 3) {
        _f[slot ~/ 2] = pick;
        _champion = null;
      } else if (round == 4) {
        _champion = pick;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final league = ref.watch(selectedLeagueProvider);

    // Should not even be reachable for non-knockout leagues (hidden in nav), but guard anyway.
    if (!league.isKnockout) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_tree_outlined, size: 56, color: p.textLow),
                  const SizedBox(height: 12),
                  Text('${league.name} has no knockout bracket',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: p.textMid)),
                  const SizedBox(height: 6),
                  Text(
                      'Switch to International Football 2026, Champions League, or Euros to use the bracket.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textLow, fontSize: 12)),
                  const SizedBox(height: 16),
                  const LeaguePickerChip(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: "Bracket" + action buttons
                  Row(
                    children: [
                      Text('Bracket',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: p.textHi)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded),
                        onPressed: _autoFill,
                        color: AppTheme.brand,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => setState(_reset),
                      ),
                    ],
                  ),
                  // Subtitle row: label + league picker
                  Row(
                    children: [
                      Text('Pick winners',
                          style: TextStyle(color: p.textMid, fontSize: 12)),
                      const Spacer(),
                      const LeaguePickerChip(),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
            if (_champion != null) _ChampionCard(team: _champion!),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _col('R32', _r32.map((e) => e as _BT?).toList(), 0),
                        _col('R16', _r16, 1),
                        _col('QF', _qf, 2),
                        _col('SF', _sf, 3),
                        _col('FINAL', _f, 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _col(String title, List<_BT?> teams, int round) {
    final pairs = teams.length ~/ 2;
    final pad = 6.0 + round * 12.0;
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(title,
                style: const TextStyle(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.5)),
          ),
          ...List.generate(pairs, (i) => _pair(teams, round, i, pad)),
        ],
      ),
    );
  }

  Widget _pair(List<_BT?> teams, int round, int p, double pad) {
    final pal = AppTheme.of(context);
    final a = teams[p * 2];
    final b = teams[p * 2 + 1];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: pad),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: pal.stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slot(a, round, p * 2),
            const SizedBox(height: 4),
            _slot(b, round, p * 2 + 1),
          ],
        ),
      ),
    );
  }

  Widget _slot(_BT? team, int round, int slot) {
    final pal = AppTheme.of(context);
    if (team == null) {
      return Container(
        height: 36,
        decoration: BoxDecoration(
          color: pal.surfaceHi.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text('—', style: TextStyle(color: pal.textLow, fontSize: 12)),
      );
    }
    final winner = _isWinner(team, round, slot);
    return InkWell(
      onTap: () => _pick(round, slot, team),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color:
              winner ? AppTheme.brand.withValues(alpha: 0.15) : pal.surfaceHi,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: winner ? AppTheme.brand : pal.stroke,
              width: winner ? 1.2 : 1),
        ),
        child: Row(
          children: [
            TeamCrestWidget(crestUrl: team.crest, tla: team.tla, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: winner ? AppTheme.brand : pal.textHi)),
            ),
          ],
        ),
      ),
    );
  }

  bool _isWinner(_BT t, int round, int slot) {
    final n = slot ~/ 2;
    if (round == 0 && n < _r16.length) return _r16[n]?.tla == t.tla;
    if (round == 1 && n < _qf.length) return _qf[n]?.tla == t.tla;
    if (round == 2 && n < _sf.length) return _sf[n]?.tla == t.tla;
    if (round == 3 && n < _f.length) return _f[n]?.tla == t.tla;
    if (round == 4) return _champion?.tla == t.tla;
    return false;
  }
}

class _BT {
  final String name, tla;
  final String? crest;
  _BT(this.name, this.tla, [this.crest]);
  @override
  bool operator ==(Object o) => o is _BT && o.tla == tla;
  @override
  int get hashCode => tla.hashCode;
}

class _ChampionCard extends StatelessWidget {
  final _BT team;
  const _ChampionCard({required this.team});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4D3A00), Color(0xFF1A1305)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR CHAMPION',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    TeamCrestWidget(
                        crestUrl: team.crest, tla: team.tla, size: 24),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(team.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Share.share('🏆 My champion: ${team.name}!'),
            icon: const Icon(Icons.share_rounded, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}
