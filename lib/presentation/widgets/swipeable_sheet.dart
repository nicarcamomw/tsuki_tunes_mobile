import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';

/// A reusable bottom-sheet wrapper that can be dismissed by swiping down,
/// even when the content is scrollable. Uses [DraggableScrollableSheet] so
/// the drag-to-dismiss gesture works once the user scrolls to the top.
///
/// Pass a [builder] that receives a [ScrollController] — attach it to whatever
/// scrollable widget your content uses (ListView, SingleChildScrollView, etc.).
/// If the content is short and non-scrollable, you can ignore the controller.
class SwipeableSheet extends StatelessWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;
  final double initialChildSize;
  final double maxChildSize;
  final double minChildSize;

  const SwipeableSheet({
    super.key,
    required this.builder,
    this.initialChildSize = 0.65,
    this.maxChildSize = 0.92,
    this.minChildSize = 0.25,
  });

  /// Shows a modal bottom sheet that wraps [child] in a [SwipeableSheet].
  ///
  /// [child] receives a [ScrollController] that must be attached to the
  /// scrollable inside it for drag-to-dismiss to work.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function(BuildContext, ScrollController) builder,
    Color backgroundColor = AppColors.bgCard,
    double initialChildSize = 0.65,
    double maxChildSize = 0.92,
    double minChildSize = 0.25,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SwipeableSheet(
        initialChildSize: initialChildSize,
        maxChildSize: maxChildSize,
        minChildSize: minChildSize,
        builder: (ctx, controller) => Material(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          clipBehavior: Clip.antiAlias,
          child: builder(ctx, controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      maxChildSize: maxChildSize,
      minChildSize: minChildSize,
      expand: false,
      snap: true,
      snapSizes: [minChildSize, initialChildSize],
      builder: (context, controller) => builder(context, controller),
    );
  }
}

/// R-02: every bottom sheet of the app opens through here (or
/// [SwipeableSheet.show] when it scrolls): the root navigator, the card
/// background, the sheet's corner radius and room to grow.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color backgroundColor = AppColors.bgCard,
  BoxConstraints? constraints,
  bool isScrollControlled = true,
  bool drawHandle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    constraints: constraints,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: drawHandle
        ? (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [const SheetHandle(), Flexible(child: builder(ctx))])
        : builder,
  );
}

/// The grip at the top of a sheet: one size and colour everywhere (R-02).
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.color});

  /// For a sheet on a dark tint (the player's).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          decoration: BoxDecoration(
            color: color ?? AppColors.textMuted.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}
