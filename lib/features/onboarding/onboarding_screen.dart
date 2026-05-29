// lib/features/onboarding/onboarding_screen.dart
//
// First-launch onboarding flow. Three steps:
//   1. Pick app language       (writes to localeProvider + Hive)
//   2. Display name + country  (saves to UserProfileService)
//   3. Favourite teams         (writes to favoritesProvider)
//
// All steps are skippable — the only required step to dismiss is at least
// one tap. If the user does nothing meaningful we still mark onboarding
// done so we never block them from the app.
//
// Persistence flag: Hive box 'app_settings', key 'onboarding_done'.
// The app router (in app.dart) reads that flag on startup and decides
// whether to show this screen or jump straight to RootShell.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/theme/app_theme.dart';

const String kOnboardingDoneKey = 'onboarding_done';

/// Public helper — call before deciding which screen to show on startup.
bool isOnboardingDone() {
  try {
    return Hive.box('app_settings').get(kOnboardingDoneKey, defaultValue: false)
        as bool;
  } catch (_) {
    return false;
  }
}

Future<void> markOnboardingDone() async {
  try {
    await Hive.box('app_settings').put(kOnboardingDoneKey, true);
  } catch (_) {}
}

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  // Step 2 (profile) state
  final _nameCtrl = TextEditingController();
  _Country? _country;

  // Step 3 (favorite teams) state — track chosen TLAs
  final Set<String> _favTlas = {};

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Save profile if user filled anything in.
    if (_nameCtrl.text.trim().isNotEmpty || _country != null) {
      await UserProfileService.instance.saveProfile(
        name: _nameCtrl.text.trim().isEmpty ? 'Fan' : _nameCtrl.text.trim(),
        countryCode: _country?.code ?? '',
        countryName: _country?.name ?? '',
      );
    }
    if (_favTlas.isNotEmpty) {
      final fav = ref.read(favoritesProvider.notifier);
      for (final tla in _favTlas) {
        // Only add — toggle would remove if already present, but we want
        // onboarding to be purely additive.
        if (!fav.isFavorite(tla)) {
          fav.toggle(tla);
        }
      }
    }
    await markOnboardingDone();
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_page >= 2) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() => _finish();

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress + skip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(child: _stepDots(p)),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                          color: p.textLow, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _LanguageStep(onSelect: () => _next()),
                  _ProfileStep(
                    nameCtrl: _nameCtrl,
                    country: _country,
                    onCountry: (c) => setState(() => _country = c),
                  ),
                  _FavoritesStep(
                    selected: _favTlas,
                    onToggle: (tla) {
                      setState(() {
                        if (_favTlas.contains(tla)) {
                          _favTlas.remove(tla);
                        } else {
                          _favTlas.add(tla);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _next,
                  child: Text(
                    _page == 2 ? "Let's go" : 'Continue',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepDots(Palette p) {
    return Row(
      children: List.generate(3, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppTheme.brand : p.stroke,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Step 1: Language ───────────────────────────────────────────────────────

class _LanguageStep extends ConsumerWidget {
  final VoidCallback onSelect;
  const _LanguageStep({required this.onSelect});

  static const _langs = <_Lang>[
    _Lang('en', 'English', '🇺🇸'),
    _Lang('es', 'Español', '🇪🇸'),
    _Lang('hi', 'हिन्दी', '🇮🇳'),
    _Lang('ne', 'नेपाली', '🇳🇵'),
    _Lang('fr', 'Français', '🇫🇷'),
    _Lang('de', 'Deutsch', '🇩🇪'),
    _Lang('pt', 'Português', '🇧🇷'),
    _Lang('ru', 'Русский', '🇷🇺'),
    _Lang('ja', '日本語', '🇯🇵'),
    _Lang('ko', '한국어', '🇰🇷'),
    _Lang('zh', '中文', '🇨🇳'),
    _Lang('ar', 'العربية', '🇸🇦'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final current = ref.watch(localeProvider).languageCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Text('Choose your language',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: p.textHi,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text('You can change this any time in Settings.',
            style: TextStyle(fontSize: 14, color: p.textLow)),
        const SizedBox(height: 22),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: _langs.map((l) {
            final selected = l.code == current;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(Locale(l.code));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.brand.withValues(alpha: 0.15)
                      : p.surface,
                  border: Border.all(
                    color: selected ? AppTheme.brand : p.stroke,
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(l.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? AppTheme.brand : p.textHi,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          size: 18, color: AppTheme.brand),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Lang {
  final String code;
  final String name;
  final String flag;
  const _Lang(this.code, this.name, this.flag);
}

// ─── Step 2: Display name + country ─────────────────────────────────────────

class _ProfileStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final _Country? country;
  final ValueChanged<_Country> onCountry;

  const _ProfileStep({
    required this.nameCtrl,
    required this.country,
    required this.onCountry,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Text("What's your name?",
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: p.textHi,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text("We'll use this for the leaderboard. You can change it later.",
            style: TextStyle(fontSize: 14, color: p.textLow)),
        const SizedBox(height: 22),
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          maxLength: 20,
          style: TextStyle(
            color: p.textHi,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: p.textLow),
            filled: true,
            fillColor: p.surface,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.brand, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Your country',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.textMid,
              letterSpacing: 0.4,
            )),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _Country.popular.map((c) {
            final selected = country?.code == c.code;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onCountry(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.brand.withValues(alpha: 0.15)
                      : p.surface,
                  border: Border.all(
                    color: selected ? AppTheme.brand : p.stroke,
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(c.name,
                        style: TextStyle(
                          color: selected ? AppTheme.brand : p.textHi,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Country {
  final String code;
  final String name;
  final String flag;
  const _Country(this.code, this.name, this.flag);

  static const popular = <_Country>[
    _Country('np', 'Nepal', '🇳🇵'),
    _Country('in', 'India', '🇮🇳'),
    _Country('us', 'USA', '🇺🇸'),
    _Country('br', 'Brazil', '🇧🇷'),
    _Country('ar', 'Argentina', '🇦🇷'),
    _Country('gb', 'United Kingdom', '🇬🇧'),
    _Country('de', 'Germany', '🇩🇪'),
    _Country('es', 'Spain', '🇪🇸'),
    _Country('fr', 'France', '🇫🇷'),
    _Country('pt', 'Portugal', '🇵🇹'),
    _Country('it', 'Italy', '🇮🇹'),
    _Country('mx', 'Mexico', '🇲🇽'),
    _Country('jp', 'Japan', '🇯🇵'),
    _Country('kr', 'South Korea', '🇰🇷'),
    _Country('au', 'Australia', '🇦🇺'),
    _Country('ca', 'Canada', '🇨🇦'),
    _Country('ng', 'Nigeria', '🇳🇬'),
    _Country('eg', 'Egypt', '🇪🇬'),
    _Country('ma', 'Morocco', '🇲🇦'),
    _Country('sa', 'Saudi Arabia', '🇸🇦'),
  ];
}

// ─── Step 3: Favorite teams ─────────────────────────────────────────────────

class _FavoritesStep extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _FavoritesStep({required this.selected, required this.onToggle});

  // 24 popular teams — mix of national + top clubs.
  // TLAs match what fd.org returns so the favorites filter works on home.
  static const _teams = <_TeamChip>[
    _TeamChip('BRA', 'Brazil', '🇧🇷'),
    _TeamChip('ARG', 'Argentina', '🇦🇷'),
    _TeamChip('FRA', 'France', '🇫🇷'),
    _TeamChip('ENG', 'England', '🏴󠁧󠁢󠁥󠁮󠁧󠁿'),
    _TeamChip('GER', 'Germany', '🇩🇪'),
    _TeamChip('ESP', 'Spain', '🇪🇸'),
    _TeamChip('POR', 'Portugal', '🇵🇹'),
    _TeamChip('NED', 'Netherlands', '🇳🇱'),
    _TeamChip('BEL', 'Belgium', '🇧🇪'),
    _TeamChip('ITA', 'Italy', '🇮🇹'),
    _TeamChip('CRO', 'Croatia', '🇭🇷'),
    _TeamChip('USA', 'USA', '🇺🇸'),
    _TeamChip('MEX', 'Mexico', '🇲🇽'),
    _TeamChip('JPN', 'Japan', '🇯🇵'),
    _TeamChip('KOR', 'South Korea', '🇰🇷'),
    _TeamChip('MAR', 'Morocco', '🇲🇦'),
    _TeamChip('SEN', 'Senegal', '🇸🇳'),
    _TeamChip('AUS', 'Australia', '🇦🇺'),
    _TeamChip('LIV', 'Liverpool', '⚽'),
    _TeamChip('MCI', 'Man City', '⚽'),
    _TeamChip('MUN', 'Man United', '⚽'),
    _TeamChip('ARS', 'Arsenal', '⚽'),
    _TeamChip('FCB', 'Barcelona', '⚽'),
    _TeamChip('RMA', 'Real Madrid', '⚽'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Text('Pick your teams',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: p.textHi,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text(
          "Your favourites show up first on Home. Pick as many as you like.",
          style: TextStyle(fontSize: 14, color: p.textLow),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _teams.map((t) {
            final sel = selected.contains(t.tla);
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onToggle(t.tla),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      sel ? AppTheme.brand.withValues(alpha: 0.15) : p.surface,
                  border: Border.all(
                    color: sel ? AppTheme.brand : p.stroke,
                    width: sel ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(t.name,
                        style: TextStyle(
                          color: sel ? AppTheme.brand : p.textHi,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                    if (sel) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle,
                          size: 14, color: AppTheme.brand),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TeamChip {
  final String tla;
  final String name;
  final String flag;
  const _TeamChip(this.tla, this.name, this.flag);
}
