import 'package:flutter/widgets.dart';

/// The space a page in the main shell leaves at its end, so its last rows
/// clear the glass dock (mini player and bottom bar) that floats over it.
///
/// The shell gives its pages the dock's height as their bottom padding
/// (MediaQuery), so this follows it: taller with a song playing, nothing
/// extra with the keyboard up.
double dockBottom(BuildContext context, {double extra = 24}) => MediaQuery.paddingOf(context).bottom + extra;
