import 'package:flutter/material.dart';

/// A small rise on entry and a stationary fade on exit, without changing layout.
class ContentReveal extends StatelessWidget {
  const ContentReveal({
    super.key,
    required this.animation,
    required this.child,
  });
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Opacity(
      opacity: animation.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(
          0,
          animation.status == AnimationStatus.reverse
              ? 0
              : 8 * (1 - animation.value),
        ),
        child: child,
      ),
    ),
  );
}
