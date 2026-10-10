import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adaptive_layout.dart';

class AdaptivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const AdaptivePage({super.key, required this.child, this.maxWidth = 1440});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final policy = AdaptiveLayout.resolve(
        size: constraints.biggest,
        padding: EdgeInsets.zero,
        displayFeatures: media.displayFeatures,
        textScale: media.textScaler.scale(1),
      );
      var region = policy.primaryRegion;
      final second = policy.secondaryRegion;
      if (second != null &&
          second.width * second.height > region.width * region.height)
        region = second;
      final width = math.min(region.width, maxWidth);
      final left = region.left + (region.width - width) / 2;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: region.top,
            width: width,
            height: region.height,
            child: MediaQuery(
              data: shiftedMedia(
                media,
                Offset(left, region.top),
                Size(width, region.height),
              ),
              child: child,
            ),
          ),
        ],
      );
    },
  );
}

/// Dialog route content constrained to one unobstructed region, above the keyboard.
class AdaptiveDialog extends StatelessWidget {
  final Widget child;
  const AdaptiveDialog({super.key, required this.child});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final padding = EdgeInsets.fromLTRB(
        math.max(media.padding.left, media.viewInsets.left),
        math.max(media.padding.top, media.viewInsets.top),
        math.max(media.padding.right, media.viewInsets.right),
        math.max(media.padding.bottom, media.viewInsets.bottom),
      );
      final policy = AdaptiveLayout.resolve(
        size: constraints.biggest,
        padding: padding,
        displayFeatures: media.displayFeatures,
        textScale: media.textScaler.scale(1),
      );
      // Dialogs use the largest available region even when the calendar can split.
      var region = policy.primaryRegion;
      final second = policy.secondaryRegion;
      if (second != null &&
          second.width * second.height > region.width * region.height)
        region = second;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: region,
            child: MediaQuery(
              data: shiftedMedia(media, region.topLeft, region.size).copyWith(
                viewInsets: EdgeInsets.zero,
                displayFeatures: const [],
              ),
              child: child,
            ),
          ),
        ],
      );
    },
  );
}

/// Entire dialog scrolls, including actions, on short/large-text windows.
class AdaptiveAlertDialog extends StatelessWidget {
  final Widget? title, content;
  final List<Widget>? actions;
  const AdaptiveAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => AdaptiveDialog(
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.headlineSmall!,
                    child: title!,
                  ),
                if (content != null) ...[const SizedBox(height: 16), content!],
                if (actions != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdaptiveStatusBanner extends StatelessWidget {
  final Widget content;
  final List<Widget> actions;
  const AdaptiveStatusBanner({
    super.key,
    required this.content,
    required this.actions,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    ),
  );
}

/// The route leaves region selection to AdaptiveDialog, including after a fold.
Future<T?> showDinnerMapDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => Navigator.of(context, rootNavigator: true).push<T>(
  _DinnerMapDialogRoute<T>(
    builder,
    Theme.of(context),
    MaterialLocalizations.of(context).modalBarrierDismissLabel,
  ),
);

class _DinnerMapDialogRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final ThemeData theme;
  @override
  final String barrierLabel;
  _DinnerMapDialogRoute(this.builder, this.theme, this.barrierLabel)
    : super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);
  @override
  bool get barrierDismissible => true;
  @override
  Color get barrierColor => Colors.black54;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: Theme(
      data: theme,
      child: Builder(builder: builder),
    ),
  );
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}
