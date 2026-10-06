import 'package:flutter/material.dart';

/// The auth shell stays still; its content animates using the route's progress.
class AuthStepRoute extends PageRouteBuilder<void> {
  AuthStepRoute({required WidgetBuilder builder, bool animate = true})
    : super(
        transitionDuration: animate
            ? const Duration(milliseconds: 420)
            : Duration.zero,
        reverseTransitionDuration: animate
            ? const Duration(milliseconds: 300)
            : Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (_, child) => Opacity(
                opacity: animation.status == AnimationStatus.reverse
                    ? animation.value
                    : 1,
                child: child,
              ),
            ),
      );
}
