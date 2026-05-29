// lib/shared/widgets/team_crest_widget.dart
//
// Universal team badge.
//
// Strategy:
//   1. If `crestUrl` is provided (fd.org `crest`) → render it
//      • .svg → flutter_svg
//      • .png/.jpg → Image.network
//   2. If crest fails OR is absent:
//      • If TLA is a known national-team code → FlagWidget country flag
//      • Otherwise (club without crest) → generated initials badge with
//        a deterministic colour derived from the TLA
//
// Works for every team on football-data.org — Premier League clubs, La Liga
// clubs, national sides, Bundesliga, Serie A, MLS, Brazil Série A.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'flag_widget.dart';

/// Same TLA → ISO2 keys that FlagWidget knows. Used to decide whether a TLA
/// represents a nation (flag fallback OK) or a club (need badge fallback).
const _nationalTlas = <String>{
  'BRA',
  'ARG',
  'FRA',
  'GER',
  'ENG',
  'ESP',
  'POR',
  'NED',
  'BEL',
  'ITA',
  'CRO',
  'URU',
  'MEX',
  'USA',
  'CAN',
  'JPN',
  'KOR',
  'AUS',
  'SEN',
  'MAR',
  'GHA',
  'NGA',
  'EGY',
  'TUN',
  'CMR',
  'CIV',
  'SUI',
  'DEN',
  'POL',
  'SRB',
  'WAL',
  'SCO',
  'IRL',
  'NIR',
  'ECU',
  'COL',
  'PER',
  'CHI',
  'PAR',
  'VEN',
  'BOL',
  'CRC',
  'PAN',
  'JAM',
  'HON',
  'IRN',
  'KSA',
  'QAT',
  'UAE',
  'JOR',
  'UZB',
  'CPV',
  'CUW',
  'NZL',
  'TUR',
  'AUT',
  'CZE',
  'HUN',
  'SWE',
  'NOR',
  'FIN',
  'GRE',
  'RUS',
  'UKR',
  'RSA',
  'ALG',
  'NMA',
};

class TeamCrestWidget extends StatefulWidget {
  final String? crestUrl;
  final String tla;
  final String? name; // for initials fallback when TLA is generic
  final double size;
  final bool circular;
  const TeamCrestWidget({
    super.key,
    required this.crestUrl,
    required this.tla,
    this.name,
    this.size = 40,
    this.circular = false,
  });

  @override
  State<TeamCrestWidget> createState() => _TeamCrestWidgetState();
}

class _TeamCrestWidgetState extends State<TeamCrestWidget> {
  bool _failed = false;

  bool get _hasUrl =>
      widget.crestUrl != null && widget.crestUrl!.trim().isNotEmpty;
  bool get _isSvg => _hasUrl && widget.crestUrl!.toLowerCase().endsWith('.svg');
  bool get _canTryCrest => _hasUrl && !_failed;
  bool get _isNation => _nationalTlas.contains(widget.tla.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    Widget child;
    if (_canTryCrest && _isSvg) {
      child = SvgPicture.network(
        widget.crestUrl!,
        width: s,
        height: s,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => _placeholderBox(s),
      );
    } else if (_canTryCrest) {
      child = Image.network(
        widget.crestUrl!,
        width: s,
        height: s,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _failed = true);
          });
          return _fallback(s);
        },
      );
    } else {
      child = _fallback(s);
    }

    final radius = widget.circular ? s / 2 : s * 0.18;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: s,
        height: s,
        child: Center(child: child),
      ),
    );
  }

  Widget _placeholderBox(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              widget.circular ? null : BorderRadius.circular(s * 0.18),
        ),
      );

  Widget _fallback(double s) {
    if (_isNation) {
      return FlagWidget(tla: widget.tla, size: s, circular: widget.circular);
    }
    return _ClubInitialsBadge(
      tla: widget.tla,
      name: widget.name,
      size: s,
      circular: widget.circular,
    );
  }
}

/// Generated club badge — used when fd.org has no crest URL for a club.
class _ClubInitialsBadge extends StatelessWidget {
  final String tla;
  final String? name;
  final double size;
  final bool circular;
  const _ClubInitialsBadge({
    required this.tla,
    required this.name,
    required this.size,
    required this.circular,
  });

  static const _palette = <Color>[
    Color(0xFFC8102E),
    Color(0xFF034694),
    Color(0xFF0E7A0D),
    Color(0xFF6F1D1B),
    Color(0xFFFFB81C),
    Color(0xFF132257),
    Color(0xFF1B5E20),
    Color(0xFF5E2750),
    Color(0xFF1C1C1C),
    Color(0xFFF1BE48),
    Color(0xFF6CABDD),
    Color(0xFFE53935),
  ];

  Color get _bgColor {
    final src = (name?.isNotEmpty == true ? name! : tla).toUpperCase();
    var hash = 0;
    for (final cu in src.codeUnits) {
      hash = (hash * 31 + cu) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  String get _initials {
    if (tla.length >= 2 && tla != '???') {
      return tla.length > 3 ? tla.substring(0, 3) : tla;
    }
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].length > 3 ? parts[0].substring(0, 3) : parts[0];
    }
    return parts.take(2).map((s) => s[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _bgColor,
            Color.lerp(_bgColor, Colors.black, 0.25) ?? _bgColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.18),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: FittedBox(
          child: Text(
            _initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                    color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
