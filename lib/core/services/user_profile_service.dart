// lib/core/services/user_profile_service.dart
//
// Manages user profile: display name + country flag
//   • Written to Firestore leaderboard/{uid} immediately on save
//   • Cached in Hive for offline/instant reads
//   • syncFromFirestore() restores profile after reinstall

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anon';

  static const _nameKey = 'display_name';
  static const _countryCode = 'country_code'; // e.g. 'np', 'us', 'br'
  static const _countryName = 'country_name'; // e.g. 'Nepal'
  static const _nameSetKey = 'has_set_name';

  Box get _prefs => Hive.box('user_prefs');

  // ── Getters (synchronous — read from Hive) ────────────────────────────────

  String get localName => _prefs.get(_nameKey, defaultValue: '') as String;

  String get localCountryCode =>
      _prefs.get(_countryCode, defaultValue: '') as String;

  String get localCountryName =>
      _prefs.get(_countryName, defaultValue: '') as String;

  bool get hasSetName => _prefs.get(_nameSetKey, defaultValue: false) as bool;

  // ── Flag URL helper (flagcdn.com — free, no API key) ─────────────────────

  static String flagUrl(String isoCode) =>
      'https://flagcdn.com/w40/${isoCode.toLowerCase()}.png';

  // ── Save profile ──────────────────────────────────────────────────────────

  Future<void> saveProfile({
    required String name,
    required String countryCode, // 2-letter ISO e.g. 'np'
    required String countryName, // e.g. 'Nepal'
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // 1. Save to Hive immediately (works offline)
    await _prefs.put(_nameKey, trimmed);
    await _prefs.put(_countryCode, countryCode.toLowerCase());
    await _prefs.put(_countryName, countryName);
    await _prefs.put(_nameSetKey, true);

    // 2. Write full profile doc to Firestore leaderboard collection
    //    This creates the document even before any prediction is made,
    //    so the user appears on the leaderboard right away.
    try {
      await _db.collection('leaderboard').doc(_uid).set(
        {
          'uid': _uid,
          'displayName': trimmed,
          'countryCode': countryCode.toLowerCase(),
          'countryName': countryName,
          // Initialize stats fields if not present yet
          'totalPoints': FieldValue.increment(0),
          'predictionsCount': FieldValue.increment(0),
          'correctScores': FieldValue.increment(0),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('UserProfileService: profile saved — $trimmed ($countryName)');
    } catch (e) {
      debugPrint('UserProfileService: Firestore write failed — $e');
      // Hive save still succeeded, so app works offline
    }
  }

  // ── Sync from Firestore (call once at app start) ──────────────────────────

  Future<void> syncFromFirestore() async {
    try {
      final doc = await _db.collection('leaderboard').doc(_uid).get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;

      final name = data['displayName'] as String?;
      final code = data['countryCode'] as String?;
      final cName = data['countryName'] as String?;

      if (name != null && name.isNotEmpty) {
        await _prefs.put(_nameKey, name);
        await _prefs.put(_nameSetKey, true);
      }
      if (code != null && code.isNotEmpty) {
        await _prefs.put(_countryCode, code);
      }
      if (cName != null && cName.isNotEmpty) {
        await _prefs.put(_countryName, cName);
      }
    } catch (_) {
      // Offline — use local Hive values
    }
  }
}

// ─── All countries list ───────────────────────────────────────────────────────
// ISO 3166-1 alpha-2 codes, compatible with flagcdn.com

class AllCountries {
  static const List<Map<String, String>> list = [
    {'code': 'af', 'name': 'Afghanistan'},
    {'code': 'al', 'name': 'Albania'},
    {'code': 'dz', 'name': 'Algeria'},
    {'code': 'ad', 'name': 'Andorra'},
    {'code': 'ao', 'name': 'Angola'},
    {'code': 'ag', 'name': 'Antigua and Barbuda'},
    {'code': 'ar', 'name': 'Argentina'},
    {'code': 'am', 'name': 'Armenia'},
    {'code': 'au', 'name': 'Australia'},
    {'code': 'at', 'name': 'Austria'},
    {'code': 'az', 'name': 'Azerbaijan'},
    {'code': 'bs', 'name': 'Bahamas'},
    {'code': 'bh', 'name': 'Bahrain'},
    {'code': 'bd', 'name': 'Bangladesh'},
    {'code': 'bb', 'name': 'Barbados'},
    {'code': 'by', 'name': 'Belarus'},
    {'code': 'be', 'name': 'Belgium'},
    {'code': 'bz', 'name': 'Belize'},
    {'code': 'bj', 'name': 'Benin'},
    {'code': 'bt', 'name': 'Bhutan'},
    {'code': 'bo', 'name': 'Bolivia'},
    {'code': 'ba', 'name': 'Bosnia and Herzegovina'},
    {'code': 'bw', 'name': 'Botswana'},
    {'code': 'br', 'name': 'Brazil'},
    {'code': 'bn', 'name': 'Brunei'},
    {'code': 'bg', 'name': 'Bulgaria'},
    {'code': 'bf', 'name': 'Burkina Faso'},
    {'code': 'bi', 'name': 'Burundi'},
    {'code': 'cv', 'name': 'Cabo Verde'},
    {'code': 'kh', 'name': 'Cambodia'},
    {'code': 'cm', 'name': 'Cameroon'},
    {'code': 'ca', 'name': 'Canada'},
    {'code': 'cf', 'name': 'Central African Republic'},
    {'code': 'td', 'name': 'Chad'},
    {'code': 'cl', 'name': 'Chile'},
    {'code': 'cn', 'name': 'China'},
    {'code': 'co', 'name': 'Colombia'},
    {'code': 'km', 'name': 'Comoros'},
    {'code': 'cg', 'name': 'Congo'},
    {'code': 'cd', 'name': 'Congo (DRC)'},
    {'code': 'cr', 'name': 'Costa Rica'},
    {'code': 'hr', 'name': 'Croatia'},
    {'code': 'cu', 'name': 'Cuba'},
    {'code': 'cy', 'name': 'Cyprus'},
    {'code': 'cz', 'name': 'Czech Republic'},
    {'code': 'dk', 'name': 'Denmark'},
    {'code': 'dj', 'name': 'Djibouti'},
    {'code': 'dm', 'name': 'Dominica'},
    {'code': 'do', 'name': 'Dominican Republic'},
    {'code': 'ec', 'name': 'Ecuador'},
    {'code': 'eg', 'name': 'Egypt'},
    {'code': 'sv', 'name': 'El Salvador'},
    {'code': 'gq', 'name': 'Equatorial Guinea'},
    {'code': 'er', 'name': 'Eritrea'},
    {'code': 'ee', 'name': 'Estonia'},
    {'code': 'sz', 'name': 'Eswatini'},
    {'code': 'et', 'name': 'Ethiopia'},
    {'code': 'fj', 'name': 'Fiji'},
    {'code': 'fi', 'name': 'Finland'},
    {'code': 'fr', 'name': 'France'},
    {'code': 'ga', 'name': 'Gabon'},
    {'code': 'gm', 'name': 'Gambia'},
    {'code': 'ge', 'name': 'Georgia'},
    {'code': 'de', 'name': 'Germany'},
    {'code': 'gh', 'name': 'Ghana'},
    {'code': 'gr', 'name': 'Greece'},
    {'code': 'gd', 'name': 'Grenada'},
    {'code': 'gt', 'name': 'Guatemala'},
    {'code': 'gn', 'name': 'Guinea'},
    {'code': 'gw', 'name': 'Guinea-Bissau'},
    {'code': 'gy', 'name': 'Guyana'},
    {'code': 'ht', 'name': 'Haiti'},
    {'code': 'hn', 'name': 'Honduras'},
    {'code': 'hu', 'name': 'Hungary'},
    {'code': 'is', 'name': 'Iceland'},
    {'code': 'in', 'name': 'India'},
    {'code': 'id', 'name': 'Indonesia'},
    {'code': 'ir', 'name': 'Iran'},
    {'code': 'iq', 'name': 'Iraq'},
    {'code': 'ie', 'name': 'Ireland'},
    {'code': 'il', 'name': 'Israel'},
    {'code': 'it', 'name': 'Italy'},
    {'code': 'jm', 'name': 'Jamaica'},
    {'code': 'jp', 'name': 'Japan'},
    {'code': 'jo', 'name': 'Jordan'},
    {'code': 'kz', 'name': 'Kazakhstan'},
    {'code': 'ke', 'name': 'Kenya'},
    {'code': 'ki', 'name': 'Kiribati'},
    {'code': 'kw', 'name': 'Kuwait'},
    {'code': 'kg', 'name': 'Kyrgyzstan'},
    {'code': 'la', 'name': 'Laos'},
    {'code': 'lv', 'name': 'Latvia'},
    {'code': 'lb', 'name': 'Lebanon'},
    {'code': 'ls', 'name': 'Lesotho'},
    {'code': 'lr', 'name': 'Liberia'},
    {'code': 'ly', 'name': 'Libya'},
    {'code': 'li', 'name': 'Liechtenstein'},
    {'code': 'lt', 'name': 'Lithuania'},
    {'code': 'lu', 'name': 'Luxembourg'},
    {'code': 'mg', 'name': 'Madagascar'},
    {'code': 'mw', 'name': 'Malawi'},
    {'code': 'my', 'name': 'Malaysia'},
    {'code': 'mv', 'name': 'Maldives'},
    {'code': 'ml', 'name': 'Mali'},
    {'code': 'mt', 'name': 'Malta'},
    {'code': 'mh', 'name': 'Marshall Islands'},
    {'code': 'mr', 'name': 'Mauritania'},
    {'code': 'mu', 'name': 'Mauritius'},
    {'code': 'mx', 'name': 'Mexico'},
    {'code': 'fm', 'name': 'Micronesia'},
    {'code': 'md', 'name': 'Moldova'},
    {'code': 'mc', 'name': 'Monaco'},
    {'code': 'mn', 'name': 'Mongolia'},
    {'code': 'me', 'name': 'Montenegro'},
    {'code': 'ma', 'name': 'Morocco'},
    {'code': 'mz', 'name': 'Mozambique'},
    {'code': 'mm', 'name': 'Myanmar'},
    {'code': 'na', 'name': 'Namibia'},
    {'code': 'nr', 'name': 'Nauru'},
    {'code': 'np', 'name': 'Nepal'},
    {'code': 'nl', 'name': 'Netherlands'},
    {'code': 'nz', 'name': 'New Zealand'},
    {'code': 'ni', 'name': 'Nicaragua'},
    {'code': 'ne', 'name': 'Niger'},
    {'code': 'ng', 'name': 'Nigeria'},
    {'code': 'kp', 'name': 'North Korea'},
    {'code': 'mk', 'name': 'North Macedonia'},
    {'code': 'no', 'name': 'Norway'},
    {'code': 'om', 'name': 'Oman'},
    {'code': 'pk', 'name': 'Pakistan'},
    {'code': 'pw', 'name': 'Palau'},
    {'code': 'pa', 'name': 'Panama'},
    {'code': 'pg', 'name': 'Papua New Guinea'},
    {'code': 'py', 'name': 'Paraguay'},
    {'code': 'pe', 'name': 'Peru'},
    {'code': 'ph', 'name': 'Philippines'},
    {'code': 'pl', 'name': 'Poland'},
    {'code': 'pt', 'name': 'Portugal'},
    {'code': 'qa', 'name': 'Qatar'},
    {'code': 'ro', 'name': 'Romania'},
    {'code': 'ru', 'name': 'Russia'},
    {'code': 'rw', 'name': 'Rwanda'},
    {'code': 'kn', 'name': 'Saint Kitts and Nevis'},
    {'code': 'lc', 'name': 'Saint Lucia'},
    {'code': 'vc', 'name': 'Saint Vincent'},
    {'code': 'ws', 'name': 'Samoa'},
    {'code': 'sm', 'name': 'San Marino'},
    {'code': 'st', 'name': 'Sao Tome and Principe'},
    {'code': 'sa', 'name': 'Saudi Arabia'},
    {'code': 'sn', 'name': 'Senegal'},
    {'code': 'rs', 'name': 'Serbia'},
    {'code': 'sc', 'name': 'Seychelles'},
    {'code': 'sl', 'name': 'Sierra Leone'},
    {'code': 'sg', 'name': 'Singapore'},
    {'code': 'sk', 'name': 'Slovakia'},
    {'code': 'si', 'name': 'Slovenia'},
    {'code': 'sb', 'name': 'Solomon Islands'},
    {'code': 'so', 'name': 'Somalia'},
    {'code': 'za', 'name': 'South Africa'},
    {'code': 'ss', 'name': 'South Sudan'},
    {'code': 'es', 'name': 'Spain'},
    {'code': 'lk', 'name': 'Sri Lanka'},
    {'code': 'sd', 'name': 'Sudan'},
    {'code': 'sr', 'name': 'Suriname'},
    {'code': 'se', 'name': 'Sweden'},
    {'code': 'ch', 'name': 'Switzerland'},
    {'code': 'sy', 'name': 'Syria'},
    {'code': 'tw', 'name': 'Taiwan'},
    {'code': 'tj', 'name': 'Tajikistan'},
    {'code': 'tz', 'name': 'Tanzania'},
    {'code': 'th', 'name': 'Thailand'},
    {'code': 'tl', 'name': 'Timor-Leste'},
    {'code': 'tg', 'name': 'Togo'},
    {'code': 'to', 'name': 'Tonga'},
    {'code': 'tt', 'name': 'Trinidad and Tobago'},
    {'code': 'tn', 'name': 'Tunisia'},
    {'code': 'tr', 'name': 'Turkey'},
    {'code': 'tm', 'name': 'Turkmenistan'},
    {'code': 'tv', 'name': 'Tuvalu'},
    {'code': 'ug', 'name': 'Uganda'},
    {'code': 'ua', 'name': 'Ukraine'},
    {'code': 'ae', 'name': 'United Arab Emirates'},
    {'code': 'gb', 'name': 'United Kingdom'},
    {'code': 'us', 'name': 'United States'},
    {'code': 'uy', 'name': 'Uruguay'},
    {'code': 'uz', 'name': 'Uzbekistan'},
    {'code': 'vu', 'name': 'Vanuatu'},
    {'code': 've', 'name': 'Venezuela'},
    {'code': 'vn', 'name': 'Vietnam'},
    {'code': 'ye', 'name': 'Yemen'},
    {'code': 'zm', 'name': 'Zambia'},
    {'code': 'zw', 'name': 'Zimbabwe'},
  ];
}
