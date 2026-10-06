import 'package:flutter/material.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:pillnote/widgets/auth_step_route.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.description,
    required this.fields,
    required this.actions,
    this.contentAnimation,
    this.appBar,
  });
  final String title, description;
  final List<Widget> fields, actions;
  final Animation<double>? contentAnimation;
  final PreferredSizeWidget? appBar;
  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final entering = route is AuthStepRoute && !reduceMotion;
    Animation<double> progress(double start, double end) {
      if (reduceMotion) return kAlwaysCompleteAnimation;
      if (contentAnimation != null) return contentAnimation!;
      return entering
          ? route.animation!.drive(
              CurveTween(
                curve: Interval(start, end, curve: Curves.easeOutCubic),
              ),
            )
          : kAlwaysCompleteAnimation;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: appBar,
      body: PageScrollView(
        title: title,
        subtitle: description,
        headingInset: 28,
        headingAnimation: entering || contentAnimation != null
            ? progress(0, .65)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContentReveal(
                  key: const ValueKey('auth-fields-reveal'),
                  animation: progress(.1, .85),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: fields,
                  ),
                ),
                const SizedBox(height: 32),
                const Spacer(),
                ContentReveal(
                  key: const ValueKey('auth-actions-reveal'),
                  animation: progress(.2, 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
