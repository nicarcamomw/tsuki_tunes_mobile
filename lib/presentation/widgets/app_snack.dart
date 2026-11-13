import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../state/app_providers.dart';
import '../state/locale_provider.dart';

/// The kinds of message a snack bar carries (D-08).
enum SnackKind {
  /// Something happened (added, copied, saved).
  info,

  /// Something failed: an icon and an error-coloured edge.
  error,

  /// Something was undone-able: an action, and longer on screen.
  undo,
}

/// Marks the screens [MainNavigationScreen] hosts: their snack bars float
/// in its Scaffold, over its bottom dock (bar + mini player), so they must
/// clear it. Screens outside (lyrics, login, a full-screen page) have none.
class SnackDock extends InheritedWidget {
  const SnackDock({super.key, required super.child});

  /// The dock's height as last laid out (see [DockSizeReporter]), the
  /// device's bottom inset included. 0 while the shell isn't there.
  static double shellHeight = 0;

  /// How far from the bottom a snack bar shown from [context] sits: over
  /// the dock inside the shell (or a sheet over it), else 12.
  static double bottomFor(BuildContext context) {
    // With the keyboard up the dock hides (the shell slides it away).
    final keyboard = MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
    if (keyboard > 0) return 12;
    final inShell = context.getInheritedWidgetOfExactType<SnackDock>() != null ||
        ModalRoute.of(context) is PopupRoute;
    return (inShell ? shellHeight : 0) + 12;
  }

  @override
  bool updateShouldNotify(SnackDock oldWidget) => false;
}

/// Reports its child's laid-out height as [SnackDock.shellHeight].
class DockSizeReporter extends SingleChildRenderObjectWidget {
  const DockSizeReporter({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDockSize();
}

class _RenderDockSize extends RenderProxyBox {
  @override
  void performLayout() {
    super.performLayout();
    SnackDock.shellHeight = size.height;
  }

  @override
  void dispose() {
    SnackDock.shellHeight = 0;
    super.dispose();
  }
}

/// The app's snack bars: one look, three kinds, placed over the dock.
///
/// Take it before any `await` (it keeps the messenger, the language and
/// the place), then show:
///
/// ```dart
/// final snack = AppSnack.of(context);
/// await something();
/// snack.info(strings.done);
/// ```
class AppSnack {
  AppSnack._(this._messenger, this._locale, this._bottom);

  /// For [context]'s screen. Inside the main shell, over its dock.
  /// [bottom] places it that far from the screen's edge instead.
  factory AppSnack.of(BuildContext context, {double? bottom}) => AppSnack._(
        ScaffoldMessenger.of(context),
        context.readState(localeProvider),
        bottom ?? _bottomFor(context),
      );

  /// Like [of], or null where there's no messenger (a context already gone).
  static AppSnack? maybeOf(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;
    return AppSnack._(messenger, context.readState(localeProvider), _bottomFor(context));
  }

  final ScaffoldMessengerState _messenger;
  final LocaleProvider _locale;
  final double _bottom;

  static double _bottomFor(BuildContext context) => SnackDock.bottomFor(context);

  void info(String message, {String? actionLabel, VoidCallback? onAction, IconData? icon, Duration? duration}) =>
      show(message, actionLabel: actionLabel, onAction: onAction, icon: icon, duration: duration);

  void error(String message, {String? actionLabel, VoidCallback? onAction, IconData? icon, Duration? duration}) =>
      show(message,
          kind: SnackKind.error, actionLabel: actionLabel, onAction: onAction, icon: icon, duration: duration);

  /// [message] with an undo action ([actionLabel], "Deshacer" by default).
  void undo(String message, {required VoidCallback onUndo, String? actionLabel, Duration? duration}) => show(message,
      kind: SnackKind.undo,
      actionLabel: actionLabel ?? _locale.strings.undo,
      onAction: onUndo,
      duration: duration);

  void show(
    String message, {
    SnackKind kind = SnackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    Duration? duration,
  }) {
    final hasAction = actionLabel != null && onAction != null;
    final shownIcon = icon ?? (kind == SnackKind.error ? Icons.error_outline_rounded : null);
    _messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            if (shownIcon != null) ...[
              Icon(shownIcon,
                  size: 18,
                  color: kind == SnackKind.error ? AppColors.errorText : AppColors.textSecondary,
                  // Decoration: the message says it.
                  semanticLabel: null),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: _locale.getTextStyle(
                    fontSize: AppFontSize.body, fontWeight: FontWeight.w600, color: AppColors.textBright),
              ),
            ),
          ],
        ),
        action: hasAction
            ? SnackBarAction(label: actionLabel, textColor: AppColors.accentText, onPressed: onAction)
            : null,
        backgroundColor: AppColors.bgCard,
        // The border sets it apart; a Material shadow is a black band here.
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: _bottom, left: 16, right: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: kind == SnackKind.error
              ? const BorderSide(color: AppColors.error, width: 1.2)
              : const BorderSide(color: AppColors.border),
        ),
        duration: duration ?? Duration(seconds: hasAction || kind != SnackKind.info ? 4 : 2),
      ));
  }
}
