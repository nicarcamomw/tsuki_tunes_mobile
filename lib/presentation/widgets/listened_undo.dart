import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../state/app_providers.dart';
import '../state/use_cases.dart';
import 'track_tile.dart' show showTrackSnack;

/// Unmarks [trackIds] (a song, or a whole album) and offers to undo it for
/// a few seconds: one tap too many shouldn't cost an album's history.
Future<void> unmarkWithUndo(BuildContext context, WidgetRef ref, List<String> trackIds) async {
  final strings = ref.read(localeProvider).strings;
  final done = await ref.read(unmarkWithUndoProvider)(trackIds);
  if (done == null || !context.mounted) return;
  showTrackSnack(
    context,
    strings.unmarkedSongs(done.count),
    action: SnackBarAction(label: strings.undo, onPressed: () => unawaited(done.undo())),
  );
}

/// The listened toggle of a song: marking as usual, unmarking with undo.
Future<void> toggleListenedWithUndo(BuildContext context, WidgetRef ref, Track track) async {
  if (ref.read(libraryRepositoryProvider).isTrackListened(track.id)) {
    await unmarkWithUndo(context, ref, [track.id]);
  } else {
    await ref.read(toggleTrackListenedProvider)(track);
  }
}
