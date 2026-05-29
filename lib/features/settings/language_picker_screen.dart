// lib/features/settings/language_picker_screen.dart
//
// Language picker. Shows all 12 supported languages with their native names
// (so a Japanese user can find 日本語 immediately even when the app is in
// English). Tapping a row sets the locale and pops back to the previous
// screen — the whole app rebuilds instantly with the new translations.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/theme/app_theme.dart';

class LanguagePickerScreen extends ConsumerWidget {
  const LanguagePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final current = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('Language / भाषा / Idioma',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: supportedLanguageCodes.length,
                itemBuilder: (_, i) {
                  final code = supportedLanguageCodes[i];
                  final isSelected = current.languageCode == code;
                  final native = languageNativeNames[code] ?? code;
                  final english = languageEnglishNames[code] ?? code;
                  return InkWell(
                    onTap: () async {
                      await ref
                          .read(localeProvider.notifier)
                          .setLocale(Locale(code));
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.brand.withValues(alpha: 0.12)
                            : p.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.brand : p.stroke,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.brand : p.surfaceHi,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              code.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.black : p.textMid,
                                  letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(native,
                                    // Force native scripts to render in
                                    // their natural direction even when the
                                    // surrounding locale is LTR.
                                    textDirection:
                                        code == 'ar' ? TextDirection.rtl : null,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: p.textHi)),
                                const SizedBox(height: 2),
                                Text(english,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: p.textLow,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
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
            // Footer note
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                  'Translations cover the main app screens. Some labels and dynamic content may stay in English.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: p.textLow,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }
}
