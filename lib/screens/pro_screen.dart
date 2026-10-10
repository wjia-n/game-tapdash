import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/dash_themes.dart';
import 'dash_ui.dart';

/// Tap Dash PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final TapDashAudio audio;
  final TapDashSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  DashThemeDef get _t => DashThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.lastThanks.addListener(_onThanks);
  }

  @override
  void dispose() {
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  
  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: DashKit.label(15, _t).copyWith(color: Colors.white)),
        backgroundColor: _t.accentDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final store = widget.store;
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => Scaffold(
        backgroundColor: t.idleBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.onCard),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Tap Dash PRO', style: DashKit.display(24, t)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero.
              DashKit.card(
                t: t,
                child: Row(
                  children: [
                    Dasher(
                        style: DasherStyles.byId(widget.settings.styleId),
                        size: 84),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              widget.settings.isPro
                                  ? 'You are PRO!'
                                  : 'Unlock the full arcade',
                              style: DashKit.display(22, t)),
                          const SizedBox(height: 4),
                          Text(
                              widget.settings.isPro
                                  ? 'Every arena, dasher and trick is yours.'
                                  : 'One purchase. Yours forever. No subscriptions.',
                              style: DashKit.label(14, t)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DashKit.sectionTitle('Free vs Pro', t),
              DashKit.card(
                t: t,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _tableHeader(t),
                    _tableRow(t, 'Game modes', 'All 3 modes', 'All 3 modes'),
                    _tableRow(t, 'Speed tiers', 'Chill + Swift',
                        'Chill + Swift + Lightning'),
                    _tableRow(t, 'Arena themes', '4 arenas', '12 arenas'),
                    _tableRow(
                        t, 'Dasher styles', '4 dashers', '8 dashers'),
                    _tableRow(t, 'Custom arena creator', '—', 'Yes'),
                    _tableRow(t, 'Trick flashes', '—', 'Yes (Lightning)'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!widget.settings.isPro) ...[
                DashKit.sectionTitle('Go Pro', t),
                if (!store.storeReady)
                  _storeNote(t,
                      store.error ?? 'Store not ready yet.'),
                if (store.proProduct != null)
                  _buyCard(
                    t,
                    title: 'Tap Dash PRO',
                    subtitle:
                        'Unlocks Lightning tier, 8 extra arenas, 4 extra dashers, the custom arena creator. One-time purchase.',
                    price: store.proProduct!.price,
                    onBuy: () {
                      widget.audio.click();
                      store.buyPro();
                    },
                  ),
                const SizedBox(height: 14),
                DashKit.sectionTitle('Tip jar', t),
                Text(
                    'Tap Dash is free forever. If it made you smile, a tip keeps the arcade lights on.',
                    style: DashKit.label(14, t)),
                const SizedBox(height: 10),
                if (!store.storeReady && store.coffeeProduct == null)
                  _storeNote(t, store.error ?? 'Store not ready yet.'),
                if (store.coffeeProduct != null)
                  _buyCard(
                    t,
                    title: 'Coffee',
                    subtitle: 'A warm thank-you for the maker.',
                    price: store.coffeeProduct!.price,
                    onBuy: () {
                      widget.audio.click();
                      store.buyTip(store.coffeeProduct!);
                    },
                  ),
                if (store.chocolateProduct != null) ...[
                  const SizedBox(height: 10),
                  _buyCard(
                    t,
                    title: 'Chocolate',
                    subtitle: 'The sweetest thank-you there is.',
                    price: store.chocolateProduct!.price,
                    onBuy: () {
                      widget.audio.click();
                      store.buyTip(store.chocolateProduct!);
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () {
                      widget.audio.click();
                      store.restore();
                    },
                    child: Text('Restore purchases',
                        style: DashKit.label(15, t).copyWith(
                            decoration: TextDecoration.underline)),
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: store.purchaseError,
                  builder: (_, err, __) => err == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: Text(err,
                                style: DashKit.label(13, t).copyWith(
                                    color: const Color(0xFFB03024))),
                          ),
                        ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: store.purchaseInProgress,
                  builder: (_, busy, __) => busy
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Center(
                              child: CircularProgressIndicator()),
                        )
                      : const SizedBox.shrink(),
                ),
              ] else ...[
                DashKit.card(
                  t: t,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Color(0xFF2FA35C), size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            'PRO is active on this device. Enjoy every arena and dasher!',
                            style: DashKit.label(15, t)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () {
                      widget.audio.click();
                      store.restore();
                    },
                    child: Text('Restore purchases',
                        style: DashKit.label(15, t).copyWith(
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(DashThemeDef t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.25),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Feature', style: DashKit.label(13, t))),
          Expanded(
              flex: 2,
              child: Text('Free',
                  textAlign: TextAlign.center,
                  style: DashKit.label(13, t)
                      .copyWith(fontWeight: FontWeight.w900))),
          Expanded(
              flex: 2,
              child: Text('PRO',
                  textAlign: TextAlign.center,
                  style: DashKit.label(13, t)
                      .copyWith(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Widget _tableRow(
      DashThemeDef t, String feature, String free, String pro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: Colors.black.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(feature, style: DashKit.label(14, t))),
          Expanded(
              flex: 2,
              child: Text(free,
                  textAlign: TextAlign.center,
                  style: DashKit.label(13, t))),
          Expanded(
            flex: 2,
            child: Text(pro,
                textAlign: TextAlign.center,
                style: DashKit.label(13, t).copyWith(
                    fontWeight: FontWeight.w900, color: t.accentDark)),
          ),
        ],
      ),
    );
  }

  Widget _buyCard(DashThemeDef t,
      {required String title,
      required String subtitle,
      required String price,
      required VoidCallback onBuy}) {
    return DashKit.card(
      t: t,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DashKit.display(19, t)),
                const SizedBox(height: 4),
                Text(subtitle, style: DashKit.label(13, t)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DashKit.button(
            t: t,
            text: price,
            fontSize: 17,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            onTap: onBuy,
          ),
        ],
      ),
    );
  }

  Widget _storeNote(DashThemeDef t, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: t.onCard.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Purchases will appear here after the store products are set up ($text). The game itself is fully playable.',
              style: DashKit.label(12, t),
            ),
          ),
        ],
      ),
    );
  }
}
