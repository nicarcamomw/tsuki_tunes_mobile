import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../navigation/app_router.dart';
import '../state/app_providers.dart';
import '../state/mask_provider.dart';
import '../widgets/lore_text.dart';
import '../widgets/oni_mask_art.dart';

const _bg = Color(0xFF040408);
const _moon = Color(0xFFFFF4D6);

/// Level 100: the Bearer's choice. To be (cross the wall of the logical and
/// become an ethereal being) or not to be (stay a Bearer for good). Shown
/// once the level is reached, until the choice is made.
class AscensionScreen extends ConsumerStatefulWidget {
  const AscensionScreen({super.key});

  static Future<void> open(BuildContext context) {
    final nav = Navigator.maybeOf(context, rootNavigator: true) ?? rootNavigatorKey.currentState;
    return nav?.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const AscensionScreen())) ??
        Future.value();
  }

  @override
  ConsumerState<AscensionScreen> createState() => _AscensionScreenState();
}

enum _Step { call, name, crossed, stayed }

class _AscensionScreenState extends ConsumerState<AscensionScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 9000))..forward();
  late final TextEditingController _maskName;
  _Step _step = _Step.call;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The Bearer's name, to start from, for their mask.
    _maskName = TextEditingController(text: ref.read(maskProvider).userName?.call() ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) _reveal.value = 1;
  }

  @override
  void dispose() {
    _reveal.dispose();
    _maskName.dispose();
    super.dispose();
  }

  Future<void> _choose(bool ser) async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(HapticFeedback.heavyImpact());
    await ref.read(maskProvider).chooseEthereal(
          ser: ser,
          name: ref.read(maskProvider).userName?.call(),
          maskName: ser ? _maskName.text : null,
        );
    if (mounted) {
      setState(() {
        _busy = false;
        _step = ser ? _Step.crossed : _Step.stayed;
      });
    }
  }

  Future<void> _confirmStay() async {
    final strings = ref.read(localeProvider).strings;
    final locale = ref.read(localeProvider);
    final stay = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E0E14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: loreNameColor.withValues(alpha: 0.6)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: loreNameColor),
            const SizedBox(width: 8),
            Text(strings.ascensionWarningTitle,
                style: locale.getTextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: loreNameColor, letterSpacing: 2)),
          ],
        ),
        content: Text(strings.ascensionWarning,
            style: locale.getTextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.ascensionBack, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.ascensionKeepForm,
                style: const TextStyle(color: loreNameColor, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (stay == true) await _choose(false);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final strings = locale.strings;
    final lines = strings.ascensionCall;
    TextStyle line(double size, {Color c = AppColors.textPrimary, FontWeight w = FontWeight.w500}) =>
        locale.getTextStyle(fontSize: size, color: c, fontWeight: w, height: 1.55);

    final Widget body = switch (_step) {
      _Step.call => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < lines.length; i++)
              _Reveal(
                at: i / (lines.length + 2),
                controller: _reveal,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(lines[i], textAlign: TextAlign.center, style: line(16)),
                ),
              ),
            _Reveal(
              at: lines.length / (lines.length + 2),
              controller: _reveal,
              child: LoreText('[[${strings.ascensionBeing}]]',
                  textAlign: TextAlign.center, style: line(26, w: FontWeight.w900)),
            ),
          ],
        ),
      _Step.name => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(strings.ascensionNameTitle, textAlign: TextAlign.center, style: line(18, c: _moon, w: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(strings.ascensionNameHint, textAlign: TextAlign.center, style: line(13, c: AppColors.textSecondary)),
            const SizedBox(height: 22),
            TextField(
              controller: _maskName,
              maxLength: 40,
              textAlign: TextAlign.center,
              style: line(18, c: Colors.white, w: FontWeight.w800),
              cursorColor: _moon,
              decoration: InputDecoration(
                counterStyle: const TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _moon.withValues(alpha: 0.4))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _moon)),
              ),
            ),
            const SizedBox(height: 30),
            _ChoiceButton(
              label: strings.ascensionCross,
              filled: true,
              onTap: _busy ? null : () => _choose(true),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _step = _Step.call),
              child: Text(strings.ascensionBack, style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      _Step.crossed => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (MaskCatalog.byId('portador') case final m?) OniMaskArt(mask: m, size: 150, unlocked: true),
            const SizedBox(height: 24),
            Text(strings.ascensionCrossed, textAlign: TextAlign.center, style: line(16)),
            const SizedBox(height: 30),
            _ChoiceButton(label: strings.ascensionDone, filled: true, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      _Step.stayed => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(strings.ascensionStayed, textAlign: TextAlign.center, style: line(16)),
            const SizedBox(height: 30),
            _ChoiceButton(label: strings.ascensionDone, filled: true, onTap: () => Navigator.of(context).pop()),
          ],
        ),
    };

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.55),
                radius: 0.9,
                colors: [Color(0x33FFF4D6), Color(0x0AFFF4D6), _bg],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                if (_step == _Step.call || _step == _Step.name)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: strings.ascensionLater,
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 56, 28, 24),
                          child: body,
                        ),
                      ),
                    ),
                    // The choice stays in reach, whatever the screen.
                    if (_step == _Step.call)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                        child: _Reveal(
                          at: (lines.length + 1) / (lines.length + 2),
                          controller: _reveal,
                          child: Row(
                            children: [
                              Expanded(
                                child: _ChoiceButton(
                                  label: strings.ascensionSer,
                                  filled: true,
                                  onTap: _busy ? null : () => setState(() => _step = _Step.name),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _ChoiceButton(
                                  label: strings.ascensionNoSer,
                                  filled: false,
                                  onTap: _busy ? null : _confirmStay,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades a line in at [at] (0..1) of the reveal.
class _Reveal extends StatelessWidget {
  final double at;
  final AnimationController controller;
  final Widget child;
  const _Reveal({required this.at, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: controller,
      curve: Interval(at.clamp(0.0, 0.9), (at + 0.12).clamp(0.1, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(opacity: fade, child: child);
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  const _ChoiceButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _moon,
                foregroundColor: const Color(0xFF111217),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onTap,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3)),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _moon,
                side: BorderSide(color: _moon.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onTap,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3)),
            ),
    );
  }
}

/// Opens the choice once per run of the app, when level 100 is reached and
/// the choice is still to make.
class AscensionPrompt extends ConsumerStatefulWidget {
  final Widget child;
  const AscensionPrompt({super.key, required this.child});

  @override
  ConsumerState<AscensionPrompt> createState() => _AscensionPromptState();
}

class _AscensionPromptState extends ConsumerState<AscensionPrompt> {
  static bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(maskProvider.select((m) => m.choicePending));
    if (pending && !_shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _shown) return;
        _shown = true;
        AscensionScreen.open(context);
      });
    }
    return widget.child;
  }
}
