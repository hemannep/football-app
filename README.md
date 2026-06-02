# Football Fan Hub 2026

Zero-budget Flutter Android companion app for International Football 2026 — built solo from Nepal.

## What's inside

7 screens:
1. **Home** — today's matches, live scores (60s polling), countdown to next match, pulsing LIVE badge
2. **Fixtures** — full schedule, search by team, filter by stage, grouped by date, local timezone
3. **Predictor** — pick scores, lock-on-submit, interstitial ad after submit, WhatsApp share
4. **Trivia** — day-matched 10-question quiz, 15s timer, streak counter, rewarded-ad hints
5. **Bracket** — R32 → R16 → QF → SF → Final, tap to advance, reset button
6. **Standings** — 12 group tables + live best-8 third-place ranker (green = qualifies, red = out)
7. **Format Guide** — explainer + interactive 3rd-place calculator + debutant spotlight + Remove Ads IAP

All free infra:
- Firebase Spark plan (Firestore + Anonymous Auth + FCM + Analytics)
- football-data.org free tier (10 req/min)
- flagcdn.com for flags
- Hive for offline cache
- AdMob (banner + interstitial + rewarded)
- in_app_purchase ($1.99 remove-ads)

## To build it

```
flutter pub get
flutter run                 # debug on device
flutter build appbundle     # release for Play Store
```

The Android package name `com.mangojuice.footballfanhub2026` matches your `google-services.json` (already placed in `android/app/`).

## Trivia is day-matched

Each match day has its own JSON file in `assets/trivia/match_day_questions/` (e.g. `2026-06-11.json`). The trivia screen auto-loads today's file. If today's file doesn't exist yet, it falls back to `group_stage_questions.json`.

Categories per round (10 questions):
- `team_today` — 3 about the teams playing that day
- `stage_history` — 2 about this tournament stage historically
- `general_football` — 5 all-time football history

Currently shipped: opening-day quiz (2026-06-11), plus generic group/QF/SF/Final fallbacks. **Generate the other 38 day files using the same JSON schema before launch.**

## AdMob IDs are live

All 5 ad units are wired in `lib/core/constants/admob_ids.dart`. Banner sits at the bottom of every screen, interstitial fires after each prediction submit, rewarded gives trivia hints.

## Play Store safety

The app name says **Football Fan Hub 2026** — never use official tournament branding. App description in the docs uses "International Football / WC26 / 48-team tournament" wording only. Use country names + flagcdn.com flags only — no team crests, no official logos.

## What still needs hand-data

- More match-day trivia JSON files (one per day, 39 total)
- App icon @ 512x512 (drop into `assets/images/app_icon.png`)
- Play Store screenshots (use Canva, free)
- Privacy policy URL (privacypolicygenerator.info, free)

## Key dates

| Date | Action |
| --- | --- |
| June 3, 2026 | Submit to Play Store (latest) |
| June 11, 2026 | Tournament kicks off |
| July 19, 2026 | Final |
# football-app
