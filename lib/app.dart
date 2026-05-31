// lib/app.dart
//
// App root + boot flow.
//
// Boot sequence:
//   SplashScreen → (first launch? OnboardingScreen → RootShell) → RootShell
//
// We use a single _BootGate that toggles between three states. The splash is
// shown on every cold start (~2.7s); onboarding only when isOnboardingDone()
// is false. Both flows mark themselves done before transitioning.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/providers/locale_provider.dart';
import 'core/providers/selected_leagues_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/ad_service.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

import 'features/home/home_screen.dart';
import 'features/fixtures/fixtures_screen.dart';
import 'features/predictor/predictor_screen.dart';
import 'features/trivia/trivia_screen.dart';
import 'features/bracket/bracket_screen.dart';
import 'features/standings/standings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/splash_screen.dart';

class FootballFanHubApp extends ConsumerWidget {
  const FootballFanHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Football Fan Hub 2026',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: const _BootGate(),
    );
  }
}

// ─── Boot gate ──────────────────────────────────────────────────────────────

class _BootGate extends StatefulWidget {
  const _BootGate();
  @override
  State<_BootGate> createState() => _BootGateState();
}

enum _Phase { splash, onboarding, root }

class _BootGateState extends State<_BootGate> {
  _Phase _phase = _Phase.splash;

  void _onSplashDone() {
    setState(() {
      _phase = isOnboardingDone() ? _Phase.root : _Phase.onboarding;
    });
  }

  void _onOnboardingDone() {
    setState(() => _phase = _Phase.root);
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (_phase) {
      case _Phase.splash:
        child = SplashScreen(onDone: _onSplashDone);
        break;
      case _Phase.onboarding:
        child = OnboardingScreen(onDone: _onOnboardingDone);
        break;
      case _Phase.root:
        child = const RootShell();
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(key: ValueKey(_phase), child: child),
    );
  }
}

// ─── Root shell ─────────────────────────────────────────────────────────────

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});
  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WidgetsBindingObserver {
  int _index = 0;
  int _navTapCount = 0;
  BannerAd? _banner;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdService.markForeground();
    AdService.loadInterstitial();
    _loadBanner();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdService.markForeground();
      AdService.loadInterstitial();
    }
  }

  void _loadBanner() {
    _banner = AdService.createBanner(onLoaded: () {
      if (mounted) setState(() => _bannerLoaded = true);
    });
  }

  void _onTab(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _navTapCount++;
    });
    if (_navTapCount % 4 == 0) {
      AdService.recordAction();
      AdService.showInterstitialIfReady();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _banner?.dispose();
    super.dispose();
  }

  static const _allScreens = [
    HomeScreen(),
    FixturesScreen(),
    PredictorScreen(),
    TriviaScreen(),
    BracketScreen(),
    StandingsScreen(),
  ];

  List<_NavTab> _buildTabs(AppL10n t) => [
        _NavTab(Icons.dashboard_rounded, t.navHome),
        _NavTab(Icons.calendar_month_rounded, t.navFixtures),
        _NavTab(Icons.online_prediction_rounded, t.navPredictor),
        _NavTab(Icons.psychology_rounded, t.navTrivia),
        _NavTab(Icons.account_tree_rounded, t.navBracket),
        _NavTab(Icons.leaderboard_rounded, t.navStandings),
      ];

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final t = AppL10n.of(context);
    final league = ref.watch(selectedLeagueProvider);

    final isKnockout = league.isKnockout;
    final allTabs = _buildTabs(t);

    final visibleScreens = <Widget>[];
    final visibleTabs = <_NavTab>[];
    final activeIndices = <int>[];
    for (var i = 0; i < _allScreens.length; i++) {
      if (i == 4 && !isKnockout) continue;
      visibleScreens.add(_allScreens[i]);
      visibleTabs.add(allTabs[i]);
      activeIndices.add(i);
    }

    final currentIdx =
        activeIndices.contains(_index) ? activeIndices.indexOf(_index) : 0;

    return Scaffold(
      body: IndexedStack(index: currentIdx, children: visibleScreens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!AdService.adsRemoved && _banner != null && _bannerLoaded)
            Container(
              color: p.bg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SizedBox(
                width: _banner!.size.width.toDouble(),
                height: _banner!.size.height.toDouble(),
                child: AdWidget(ad: _banner!),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.stroke)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: List.generate(visibleTabs.length, (i) {
                    final tab = visibleTabs[i];
                    final sel = i == currentIdx;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _onTab(activeIndices[i]),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.brand.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(tab.icon,
                                  size: 22,
                                  color: sel ? AppTheme.brand : p.textLow),
                            ),
                            const SizedBox(height: 3),
                            Text(tab.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? AppTheme.brand : p.textLow)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;
  const _NavTab(this.icon, this.label);
}
