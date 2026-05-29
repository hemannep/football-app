// lib/core/services/fan_xp_service.dart
//
// Lightweight XP/level system, stored locally in Hive (no Firebase).
//
// Sources of XP:
//   • Daily login: 10 XP
//   • Correct trivia answer: 5 XP
//   • Perfect trivia round: +50 XP
//   • Submit prediction: 5 XP
//   • Exact prediction (after settlement): +25 XP
//   • Win prediction (winner correct): +15 XP
//
// Level formula: level = floor(sqrt(xp / 50))
// Examples: 50 XP → L1, 200 XP → L2, 450 XP → L3, 800 XP → L4, 1250 XP → L5
//
// Persistence: Hive box 'fan_xp' (caller must open this in main.dart).

import 'dart:math' as math;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class FanXpService {
  static const _boxName = 'fan_xp';
  static const _xpKey = 'xp';
  static const _lastLoginKey = 'last_login';
  static const _streakKey = 'streak';

  static Box get _box => Hive.box(_boxName);

  static int get xp => _box.get(_xpKey, defaultValue: 0) as int;
  static int get level => _levelForXp(xp);
  static int get streak => _box.get(_streakKey, defaultValue: 0) as int;

  /// XP required to reach the *next* level from the current XP total.
  static int get xpToNextLevel {
    final l = level;
    final next = ((l + 1) * (l + 1)) * 50;
    return next - xp;
  }

  /// Progress 0..1 toward the next level.
  static double get progressToNextLevel {
    final l = level;
    final lo = l * l * 50;
    final hi = (l + 1) * (l + 1) * 50;
    final span = hi - lo;
    if (span <= 0) return 0;
    return ((xp - lo) / span).clamp(0.0, 1.0);
  }

  static int _levelForXp(int xp) {
    return math.sqrt(xp / 50).floor();
  }

  /// Adds XP and returns whether the user just levelled up.
  static Future<bool> addXp(int amount, {String? reason}) async {
    final oldLevel = level;
    final newTotal = xp + amount;
    await _box.put(_xpKey, newTotal);
    return _levelForXp(newTotal) > oldLevel;
  }

  /// Call this every time the app opens — increments daily login streak and
  /// awards 10 XP if first open of the calendar day.
  /// Returns true if XP was awarded (i.e. first login today).
  static Future<bool> awardDailyLoginIfNeeded() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastLogin = _box.get(_lastLoginKey) as String?;
    if (lastLogin == today) return false;

    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
    int newStreak;
    if (lastLogin == yesterday) {
      newStreak = streak + 1;
    } else {
      newStreak = 1;
    }
    await _box.putAll({
      _lastLoginKey: today,
      _streakKey: newStreak,
    });
    await addXp(10, reason: 'Daily login');
    return true;
  }

  /// Useful when developing.
  static Future<void> reset() async {
    await _box.clear();
  }
}
