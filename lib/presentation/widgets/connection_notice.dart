import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/locale_provider.dart';
import 'frosted_glass.dart';
import 'motion.dart';

/// The connection, at the top of the shell: a dark glass pill that drops
/// in when it's lost ("No internet connection") and, when it's back, says
/// so for a moment in green before it leaves. White on dark glass, so it
/// reads over any page; TalkBack announces each change.
class ConnectionNotice extends StatefulWidget {
  const ConnectionNotice({super.key, required this.online, required this.locale});

  final bool online;
  final LocaleProvider locale;

  /// How long "back online" stays before the pill leaves.
  static const Duration backFor = Duration(milliseconds: 2400);

  /// Whether the pill is showing: the app-wide banners (a mask, a level, a
  /// birthday) sit below it instead of on top of it.
  static final ValueNotifier<bool> visible = ValueNotifier(false);

  /// How far below the top the pill reaches, for those banners.
  static const double clearance = 46;

  @override
  State<ConnectionNotice> createState() => _ConnectionNoticeState();
}

class _ConnectionNoticeState extends State<ConnectionNotice> {
  /// Showing "back online" (after being offline here).
  bool _back = false;
  Timer? _leave;

  @override
  void didUpdateWidget(covariant ConnectionNotice old) {
    super.didUpdateWidget(old);
    if (widget.online == old.online) return;
    _leave?.cancel();
    if (widget.online) {
      _back = true;
      _leave = Timer(ConnectionNotice.backFor, () {
        if (mounted) setState(() => _back = false);
      });
    } else {
      _back = false;
    }
  }

  @override
  void dispose() {
    _leave?.cancel();
    // After this frame: the tree is locked while it's torn down.
    if (ConnectionNotice.visible.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ConnectionNotice.visible.value = false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.locale.strings;
    final shown = !widget.online || _back;
    if (ConnectionNotice.visible.value != shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ConnectionNotice.visible.value = shown);
    }
    final still = reduceMotion(context);
    final (icon, color, text) = widget.online
        ? (Icons.wifi_rounded, AppColors.success, strings.backOnline)
        : (Icons.wifi_off_rounded, AppColors.accentText, strings.offline);
    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: AnimatedSlide(
              duration: still ? Duration.zero : AppMotion.normal,
              curve: shown ? AppMotion.enter : AppMotion.exit,
              offset: shown ? Offset.zero : const Offset(0, -1.6),
              child: AnimatedOpacity(
                duration: still ? Duration.zero : AppMotion.normal,
                opacity: shown ? 1 : 0,
                child: Semantics(
                  liveRegion: shown,
                  label: shown ? text : null,
                  child: ExcludeSemantics(
                    child: FrostedGlass(
                      color: AppColors.inkPanel,
                      fill: AppGlass.fill,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                      shadowColor: color.withValues(alpha: 0.25),
                      child: AnimatedSize(
                        duration: still ? Duration.zero : AppMotion.normal,
                        curve: AppMotion.move,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
                          child: AnimatedSwitcher(
                            duration: still ? Duration.zero : AppMotion.fast,
                            child: Row(
                              key: ValueKey(widget.online),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 16, color: color),
                                const SizedBox(width: 8),
                                Text(
                                  text,
                                  style: widget.locale.getTextStyle(
                                    fontSize: AppFontSize.body,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textBright,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
