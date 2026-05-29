// lib/shared/widgets/flag_widget.dart
//
// Renders a country flag from flagcdn.com given a 3-letter team code (TLA).
// For unknown TLAs (e.g. a club's TLA like "ARS"), falls back to a styled
// box showing the TLA text instead of a broken-image icon.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

// All 48 WC26 qualifying nations + key non-WC nations league teams represent.
const Map<String, String> _tlaToIso2 = {
  // ── WC26 qualified / likely ──────────────────────────────────────────────
  'BRA': 'br', 'ARG': 'ar', 'FRA': 'fr', 'GER': 'de', 'ENG': 'gb-eng',
  'ESP': 'es', 'POR': 'pt', 'NED': 'nl', 'BEL': 'be', 'ITA': 'it',
  'CRO': 'hr', 'URU': 'uy', 'MEX': 'mx', 'USA': 'us', 'CAN': 'ca',
  'JPN': 'jp', 'KOR': 'kr', 'AUS': 'au', 'SEN': 'sn', 'MAR': 'ma',
  'GHA': 'gh', 'NGA': 'ng', 'EGY': 'eg', 'TUN': 'tn', 'CMR': 'cm',
  'CIV': 'ci', 'SUI': 'ch', 'DEN': 'dk', 'POL': 'pl', 'SRB': 'rs',
  'WAL': 'gb-wls', 'SCO': 'gb-sct', 'IRL': 'ie', 'NIR': 'gb-nir',
  'ECU': 'ec', 'COL': 'co', 'PER': 'pe', 'CHI': 'cl', 'PAR': 'py',
  'VEN': 've', 'BOL': 'bo', 'CRC': 'cr', 'PAN': 'pa', 'JAM': 'jm',
  'HON': 'hn', 'IRN': 'ir', 'KSA': 'sa', 'QAT': 'qa', 'UAE': 'ae',
  'JOR': 'jo', 'UZB': 'uz', 'CPV': 'cv', 'CUW': 'cw', 'NZL': 'nz',
  'TUR': 'tr', 'AUT': 'at', 'CZE': 'cz', 'HUN': 'hu', 'SWE': 'se',
  'NOR': 'no', 'FIN': 'fi', 'GRE': 'gr', 'RUS': 'ru', 'UKR': 'ua',
  'RSA': 'za', 'ALG': 'dz', 'NMA': 'mk',

  // ── Additional FIFA member nations (clubs sometimes use these codes) ────
  'ROU': 'ro', 'BUL': 'bg', 'SVK': 'sk', 'SVN': 'si', 'ALB': 'al',
  'BIH': 'ba', 'MNE': 'me', 'KOS': 'xk', 'LUX': 'lu', 'ISL': 'is',
  'ISR': 'il', 'CYP': 'cy', 'MLT': 'mt', 'EST': 'ee', 'LVA': 'lv',
  'LTU': 'lt', 'BLR': 'by', 'MDA': 'md', 'AND': 'ad', 'GIB': 'gi',
  'FRO': 'fo', 'ARM': 'am', 'AZE': 'az', 'GEO': 'ge', 'KAZ': 'kz',
  'KGZ': 'kg', 'TJK': 'tj', 'TKM': 'tm', 'AFG': 'af', 'PAK': 'pk',
  'IND': 'in', 'BAN': 'bd', 'NEP': 'np', 'SRI': 'lk', 'MDV': 'mv',
  'BHU': 'bt', 'MYA': 'mm', 'THA': 'th', 'SIN': 'sg', 'MAS': 'my',
  'IDN': 'id', 'PHI': 'ph', 'VIE': 'vn', 'CAM': 'kh', 'LAO': 'la',
  'TPE': 'tw', 'HKG': 'hk', 'MAC': 'mo', 'PRK': 'kp', 'MGL': 'mn',
  'CHN': 'cn', 'PLE': 'ps', 'LBN': 'lb', 'SYR': 'sy', 'IRQ': 'iq',
  'YEM': 'ye', 'OMA': 'om', 'BHR': 'bh', 'KUW': 'kw', 'TUR_2': 'tr',
  'AGO': 'ao', 'ANG': 'ao', 'BFA': 'bf', 'BDI': 'bi', 'COD': 'cd',
  'COG': 'cg', 'BEN': 'bj', 'BOT': 'bw', 'CAF': 'cf', 'COM': 'km',
  'DJI': 'dj', 'EQG': 'gq', 'ERI': 'er', 'ETH': 'et', 'GAB': 'ga',
  'GAM': 'gm', 'GNB': 'gw', 'GUI': 'gn', 'KEN': 'ke', 'LBR': 'lr',
  'LBY': 'ly', 'LES': 'ls', 'MAD': 'mg', 'MWI': 'mw', 'MLI': 'ml',
  'MTN': 'mr', 'MRI': 'mu', 'MOZ': 'mz', 'NAM': 'na', 'NIG': 'ne',
  'RWA': 'rw', 'STP': 'st', 'SLE': 'sl', 'SOM': 'so', 'SSD': 'ss',
  'SUD': 'sd', 'SWZ': 'sz', 'TAN': 'tz', 'TOG': 'tg', 'UGA': 'ug',
  'ZAM': 'zm', 'ZIM': 'zw', 'SEY': 'sc',
};

class FlagWidget extends StatelessWidget {
  final String tla;
  final double size;
  final bool circular;
  const FlagWidget({
    super.key,
    required this.tla,
    this.size = 32,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final iso = _tlaToIso2[tla.toUpperCase()];
    final w = circular ? size : size * 1.4;
    final h = size;
    final radius = circular ? size / 2 : 5.0;

    Widget content;
    if (iso == null) {
      // Unknown TLA → styled letter badge (avoids broken-image look)
      content = Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.surfaceHi,
              AppTheme.surfaceHi.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          tla.length > 3 ? tla.substring(0, 3) : tla,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMid,
            letterSpacing: 0.3,
          ),
        ),
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: '${ApiConstants.flagBase}/$iso.png',
        width: w,
        height: h,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(width: w, height: h, color: AppTheme.surfaceHi),
        errorWidget: (_, __, ___) => Container(
          width: w,
          height: h,
          color: AppTheme.surfaceHi,
          alignment: Alignment.center,
          child: Text(tla,
              style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
        child: content,
      ),
    );
  }
}
