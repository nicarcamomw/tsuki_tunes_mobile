import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's haptic vocabulary. Every vibration goes through here, one kind
/// per meaning, so the same gesture feels the same on every screen (and
/// test/haptics_test.dart keeps HapticFeedback out of everywhere else).
///
/// | Meaning      | When                                                    | Feel          |
/// |--------------|---------------------------------------------------------|---------------|
/// | [selection]  | moving between options or flipping a state              | tick          |
/// | [tap]        | pressing something that opens or starts                 | light         |
/// | [threshold]  | a drag crossing the point where letting go will act     | light         |
/// | [longPress]  | a long press revealing a menu or a hidden action        | medium        |
/// | [confirm]    | an action that changes the user's music or circle       | medium        |
/// | [remove]     | taking something away (remove, clear, stop, leave)      | medium        |
/// | [success]    | a goal reached: an unlock, a level, a right answer      | heavy + light |
/// | [error]      | something that didn't work: a wrong answer, a failure   | light + light |
///
/// The user can turn them all off in the settings ([setEnabled]).
abstract final class Haptics {
  static const _prefsKey = 'haptics_enabled_v1';

  static bool _enabled = true;

  /// Whether the app vibrates at all.
  static bool get enabled => _enabled;

  /// Reads the user's choice; call once at startup.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // No storage: keep vibrating.
    }
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }

  @visibleForTesting
  static void debugReset() => _enabled = true;

  /// Moving between options or flipping a state: tabs, chips, segments,
  /// switches, sort and filter, follow, listened, like, picking from a list,
  /// reordering.
  static void selection() => _play(HapticFeedback.selectionClick);

  /// Pressing something that opens or starts: buttons, cards, rows, links,
  /// opening a screen or a sheet, play, retry, copy.
  static void tap() => _play(HapticFeedback.lightImpact);

  /// A drag crossing the point where letting go will act (swipe to skip,
  /// swipe to queue). Pair it with [confirm] when the drag is released.
  static void threshold() => _play(HapticFeedback.lightImpact);

  /// A long press that reveals a menu or a hidden action.
  static void longPress() => _play(HapticFeedback.mediumImpact);

  /// An action that changes the user's music or circle: add to the queue or
  /// a playlist, play next, start a radio, a run or a party, accept or send a
  /// bond, mark an album, a swipe or a shake that skips.
  static void confirm() => _play(HapticFeedback.mediumImpact);

  /// Taking something away: remove, clear, stop, leave, decline, cancel,
  /// unequip. As firm as [confirm]; kept apart so it can be tuned alone.
  static void remove() => _play(HapticFeedback.mediumImpact);

  /// A goal reached: a mask unlocked, a level, a right answer, ascension.
  static void success() {
    _play(HapticFeedback.heavyImpact);
    _later(const Duration(milliseconds: 90), HapticFeedback.lightImpact);
  }

  /// Something that didn't work: a wrong answer, a failed voice search.
  static void error() {
    _play(HapticFeedback.lightImpact);
    _later(const Duration(milliseconds: 80), HapticFeedback.lightImpact);
  }

  static void _play(Future<void> Function() feedback) {
    if (_enabled) unawaited(feedback());
  }

  static void _later(Duration delay, Future<void> Function() feedback) {
    if (_enabled) unawaited(Future<void>.delayed(delay, () => feedback()));
  }
}
