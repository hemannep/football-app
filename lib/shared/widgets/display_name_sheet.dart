// lib/shared/widgets/display_name_sheet.dart
//
// Profile setup sheet — lets user set:
//   • Display name (shown on leaderboard)
//   • Country flag (from all 195 countries via flagcdn.com)
// Saves to both Hive (instant) and Firestore (global leaderboard).
//
// Fixes vs previous version:
//   • RenderFlex overflowed by 26 pixels on the bottom — the inner Column
//     used mainAxisSize.min but its three sections (header, fixed-height
//     country list, save button) added up to more than the available height
//     when the keyboard was open. We now wrap the header in a Flexible +
//     SingleChildScrollView and make the country list shrink-friendly.
//   • Bottom safe-area padding added so the save button isn't clipped on
//     phones with on-screen nav bars.
//   • Removed `Icon(... )` const-promotable lints.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/user_profile_service.dart';
import '../../core/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final displayNameProvider = StateProvider<String>((ref) {
  return UserProfileService.instance.localName;
});

final displayCountryCodeProvider = StateProvider<String>((ref) {
  return UserProfileService.instance.localCountryCode;
});

final displayCountryNameProvider = StateProvider<String>((ref) {
  return UserProfileService.instance.localCountryName;
});

// ── Public helper ─────────────────────────────────────────────────────────────

Future<void> showDisplayNameSheet(
  BuildContext context,
  WidgetRef ref, {
  bool isFirstTime = false,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileSheet(
      isFirstTime: isFirstTime,
      onSaved: (name, code, cName) {
        ref.read(displayNameProvider.notifier).state = name;
        ref.read(displayCountryCodeProvider.notifier).state = code;
        ref.read(displayCountryNameProvider.notifier).state = cName;
      },
    ),
  );
}

// ── Profile sheet ─────────────────────────────────────────────────────────────

class _ProfileSheet extends StatefulWidget {
  final bool isFirstTime;
  final void Function(String name, String code, String cName) onSaved;
  const _ProfileSheet({required this.isFirstTime, required this.onSaved});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _searchCtrl;

  String _selectedCode = '';
  String _selectedName = '';
  String _searchQuery = '';
  bool _saving = false;
  String? _error;

  List<Map<String, String>> get _filtered {
    if (_searchQuery.isEmpty) return AllCountries.list;
    return AllCountries.list
        .where((c) =>
            c['name']!.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: UserProfileService.instance.localName);
    _searchCtrl = TextEditingController();
    _selectedCode = UserProfileService.instance.localCountryCode;
    _selectedName = UserProfileService.instance.localCountryName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters');
      return;
    }
    if (name.length > 20) {
      setState(() => _error = 'Name must be 20 characters or less');
      return;
    }
    if (_selectedCode.isEmpty) {
      setState(() => _error = 'Please select your country');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await UserProfileService.instance.saveProfile(
      name: name,
      countryCode: _selectedCode,
      countryName: _selectedName,
    );

    widget.onSaved(name, _selectedCode, _selectedName);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom; // keyboard
    final safeBottom = media.padding.bottom; // gesture / nav bar

    // Cap total sheet height — bottom sheets can request up to viewport
    // height, but we want some breathing room above so it visually feels
    // like a sheet, not a full screen.
    final maxHeight = media.size.height * 0.88;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          // Add bottom padding for keyboard + gesture bar so the button is
          // always tappable.
          padding: EdgeInsets.only(bottom: bottomInset + safeBottom),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.stroke),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header (scrollable so it never overflows) ───────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: p.stroke,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppTheme.brandGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: Colors.black, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.isFirstTime
                                      ? 'Set up your profile'
                                      : 'Edit your profile',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: p.textHi),
                                ),
                                Text('Name + flag shown on leaderboard',
                                    style: TextStyle(
                                        fontSize: 12, color: p.textLow)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Name field ─────────────────────────────────────
                      TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        maxLength: 20,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Your name',
                          hintText: 'e.g. John, FootballFan99',
                          errorText: _error,
                          prefixIcon: const Icon(Icons.badge_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppTheme.brand, width: 2),
                          ),
                          counterStyle:
                              TextStyle(fontSize: 11, color: p.textLow),
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Selected country preview ───────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: p.surfaceHi,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedCode.isEmpty
                                ? p.stroke
                                : AppTheme.brand.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedCode.isNotEmpty) ...[
                              ClipOval(
                                child: Image.network(
                                  UserProfileService.flagUrl(_selectedCode),
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.flag_rounded, size: 20),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_selectedName,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: p.textHi)),
                              ),
                              const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.brand, size: 18),
                            ] else ...[
                              Icon(Icons.flag_outlined,
                                  color: p.textLow, size: 22),
                              const SizedBox(width: 10),
                              Text('Select your country',
                                  style: TextStyle(color: p.textLow)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Country search ─────────────────────────────────
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search country…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Country list (fixed height, scrolls internally) ─────────
              SizedBox(
                height: 220,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    final code = c['code']!;
                    final cName = c['name']!;
                    final isSelected = code == _selectedCode;

                    return InkWell(
                      onTap: () => setState(() {
                        _selectedCode = code;
                        _selectedName = cName;
                        if (_error != null) _error = null;
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.brand.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.brand.withValues(alpha: 0.4))
                              : null,
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: Image.network(
                                UserProfileService.flagUrl(code),
                                width: 26,
                                height: 26,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.flag_rounded, size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppTheme.brand
                                      : AppTheme.of(context).textHi,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded,
                                  color: AppTheme.brand, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Save button ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brand,
                          foregroundColor: AppTheme.of(context).isDark
                              ? Colors.black
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                widget.isFirstTime
                                    ? 'Join the leaderboard'
                                    : 'Save profile',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                      ),
                    ),
                    if (widget.isFirstTime)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Skip for now',
                            style:
                                TextStyle(color: AppTheme.of(context).textLow)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
