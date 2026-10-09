import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/dash_themes.dart';
import 'custom_theme_screen.dart';
import 'dash_ui.dart';
import 'pro_screen.dart';
import '../services/iap_service.dart';

/// Theme picker (12 arenas) + dasher style picker (8 toy runners) +
/// entry to the Pro custom theme creator.
class ThemesScreen extends StatelessWidget {
  final TapDashAudio audio;
  final TapDashSettings settings;
  const ThemesScreen({super.key, required this.audio, required this.settings});

  DashThemeDef get _t => DashThemes.byId(
        settings.themeId,
        custom: settings.customTheme,
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) => Scaffold(
        backgroundColor: t.idleBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.onCard),
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Themes & Dashers',
              style: DashKit.display(24, t)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashKit.sectionTitle(
                  'Arena theme (${DashThemes.visible(isPro: settings.isPro, custom: settings.customTheme).length} available)',
                  t),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemCount: DashThemes.visible(
                        isPro: settings.isPro, custom: settings.customTheme)
                    .length,
                itemBuilder: (_, i) {
                  final theme = DashThemes.visible(
                      isPro: settings.isPro,
                      custom: settings.customTheme)[i];
                  return _themeTile(context, t, theme);
                },
              ),
              const SizedBox(height: 8),
              if (!settings.isPro)
                _proTeaser(context, t,
                    '${DashThemes.all.length - DashThemes.freeThemeIds.length} more arenas in PRO'),
              const SizedBox(height: 14),
              DashKit.sectionTitle('My custom arena (PRO)', t),
              _customTile(context, t),
              const SizedBox(height: 14),
              DashKit.sectionTitle(
                  'Dasher style (${DasherStyles.visible(isPro: settings.isPro).length} available)',
                  t),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemCount:
                    DasherStyles.visible(isPro: settings.isPro).length,
                itemBuilder: (_, i) {
                  final s =
                      DasherStyles.visible(isPro: settings.isPro)[i];
                  final selected = settings.styleId == s.id;
                  return GestureDetector(
                    onTap: () {
                      audio.click();
                      settings.setStyle(s.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? t.accentDark
                              : Colors.black.withValues(alpha: 0.12),
                          width: selected ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            offset: const Offset(0, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Dasher(style: s, size: 52),
                          const SizedBox(height: 4),
                          Text(s.name,
                              textAlign: TextAlign.center,
                              style: DashKit.label(11, t)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (!settings.isPro)
                _proTeaser(context, t, '4 more dashers in PRO'),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeTile(BuildContext context, DashThemeDef t, DashThemeDef theme) {
    final selected = settings.themeId == theme.id;
    return GestureDetector(
      onTap: () {
        audio.click();
        settings.setTheme(theme.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected ? t.accentDark : Colors.black.withValues(alpha: 0.15),
            width: selected ? 4 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Container(color: theme.waitingBg)),
                  Expanded(child: Container(color: theme.armedBg)),
                  Expanded(child: Container(color: theme.resultBg)),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: t.cardBg,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                theme.name,
                textAlign: TextAlign.center,
                style: DashKit.label(11, t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customTile(BuildContext context, DashThemeDef t) {
    final isCustom = settings.themeId == 'custom';
    return GestureDetector(
      onTap: () {
        audio.click();
        if (!settings.isPro) {
          _goPro(context);
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CustomThemeScreen(
                audio: audio, settings: settings)));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCustom
                ? t.accentDark
                : Colors.black.withValues(alpha: 0.12),
            width: isCustom ? 3 : 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [
                  settings.customTheme.waitingBg,
                  settings.customTheme.armedBg,
                  settings.customTheme.resultBg,
                ]),
                border: Border.all(
                    color: Colors.black.withValues(alpha: 0.2)),
              ),
              child: settings.isPro
                  ? null
                  : const Icon(Icons.lock, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Creation', style: DashKit.display(18, t)),
                  Text(
                      settings.isPro
                          ? 'Paint your own arena colors.'
                          : 'PRO feature — design your own arena.',
                      style: DashKit.label(13, t)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.onCard),
          ],
        ),
      ),
    );
  }

  Widget _proTeaser(BuildContext context, DashThemeDef t, String text) {
    return GestureDetector(
      onTap: () {
        audio.click();
        _goPro(context);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: t.accentDark.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(text,
                style: DashKit.label(13, t)
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  void _goPro(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProScreen(
            audio: audio,
            settings: settings,
            store: StoreService()..init())));
  }
}
