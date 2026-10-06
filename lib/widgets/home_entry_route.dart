import 'package:flutter/material.dart';

/// Moves forward into the home screen instead of sliding it sideways.
class HomeEntryRoute extends PageRouteBuilder<void> {
  HomeEntryRoute({required WidgetBuilder builder, bool animate = true})
    : super(
        transitionDuration: animate
            ? const Duration(milliseconds: 560)
            : Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            HomeDepthTransition(animation: animation, child: child),
      );

  // Keep a MaterialPageRoute underneath stationary too; its content handles
  // the outgoing depth effect using secondaryAnimation.
  @override
  DelegatedTransitionBuilder get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          child;
}

class HomeDepthTransition extends StatelessWidget {
  const HomeDepthTransition({
    super.key,
    required this.animation,
    required this.child,
    this.outgoing = false,
  });

  final Animation<double> animation;
  final Widget child;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(animation.value);
        return IgnorePointer(
          ignoring: outgoing && animation.value > 0,
          child: Opacity(
            opacity: outgoing ? 1 - progress : progress,
            child: Transform.scale(
              scale: outgoing ? 1 + .12 * progress : .88 + .12 * progress,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
