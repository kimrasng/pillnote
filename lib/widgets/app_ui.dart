import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:pillnote/models/medication.dart';

const ink = Color(0xFF172033);
const muted = Color(0xFF64748B);
const blue = Color(0xFF2563EB);
const line = Color(0xFFE8EDF3);
const wash = Color(0xFFF6F8FB);

/// A single scroll surface keeps the heading pinned without affecting nested
/// gestures (for example, panning the pharmacy map).
class PageScrollView extends StatelessWidget {
  const PageScrollView({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBackButton = false,
    this.navigationLabel,
    this.headingInset = 24,
    this.headingAnimation,
    this.children = const [],
    this.sliver,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    this.controller,
    this.physics,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBackButton;

  /// An expanded navigation row above the title, used by the auth flow.
  final String? navigationLabel;
  final double headingInset;
  final Animation<double>? headingAnimation;
  final List<Widget> children;
  final Widget? sliver;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final leading = showBackButton && Navigator.canPop(context)
        ? IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            onPressed: () => Navigator.maybePop(context),
          )
        : null;
    return SafeArea(
      maintainBottomViewPadding: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = _PageHeadingDelegate(
            title: title,
            subtitle: subtitle,
            leading: leading,
            trailing: trailing,
            navigationLabel: navigationLabel,
            inset: headingInset,
            headingAnimation: headingAnimation,
            width: constraints.maxWidth,
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
            textStyle: DefaultTextStyle.of(context).style,
          );
          return CustomScrollView(
            controller: controller,
            physics: _ContentScrollPhysics(parent: physics),
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: heading),
              SliverPadding(
                padding: padding,
                sliver: sliver ?? SliverList.list(children: children),
              ),
            ],
          );
        },
      ),
    );
  }
}

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

/// Keep the platform's scroll behavior for overflowing content, but prevent
/// dragging, bouncing and wheel scrolling when everything fits on screen.
class _ContentScrollPhysics extends ScrollPhysics {
  const _ContentScrollPhysics({super.parent});

  @override
  _ContentScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _ContentScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.maxScrollExtent > position.minScrollExtent &&
      super.shouldAcceptUserOffset(position);
}

class _PageHeadingDelegate extends SliverPersistentHeaderDelegate {
  _PageHeadingDelegate({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
    required this.navigationLabel,
    required this.inset,
    required this.headingAnimation,
    required this.width,
    required this.textScaler,
    required this.textDirection,
    required this.textStyle,
  });

  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final String? navigationLabel;
  final double inset;
  final Animation<double>? headingAnimation;
  final double width;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final TextStyle textStyle;

  TextStyle _titleStyle(double size) => textStyle.copyWith(
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.3,
    color: ink,
  );
  TextStyle get _subtitleStyle =>
      textStyle.copyWith(fontSize: 15, color: muted, height: 1.5);
  Widget _reveal(Widget child) => headingAnimation == null
      ? child
      : ContentReveal(animation: headingAnimation!, child: child);
  double _height(String text, TextStyle style, double availableWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      textDirection: textDirection,
    )..layout(maxWidth: math.max(1, availableWidth));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  bool get _hasNavigationRow => navigationLabel != null;
  double get _actionWidth =>
      (leading == null ? 0 : 48) + (trailing == null ? 0 : 48);
  double _rowHeight(double fontSize, {double progress = 1}) => math.max(
    !_hasNavigationRow && _actionWidth > 0 ? 48 : 0,
    _height(
      title,
      _titleStyle(fontSize),
      width - inset * 2 - _actionWidth * progress,
    ),
  );
  double get _expandedTop => _hasNavigationRow ? 80 : 24;
  @override
  late final double minExtent = math.max(56, _rowHeight(30) + 8);
  @override
  late final double maxExtent = math.max(
    minExtent + 24,
    _expandedTop +
        _rowHeight(30, progress: _hasNavigationRow ? 0 : 1) +
        20 +
        (subtitle == null
            ? 0
            : 8 + _height(subtitle!, _subtitleStyle, width - inset * 2)),
  );

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(progress);
    const fontSize = 30.0;
    final rowHeight = _rowHeight(
      fontSize,
      progress: _hasNavigationRow ? eased : 1,
    );
    final top = lerpDouble(_expandedTop, (minExtent - rowHeight) / 2, eased)!;
    final subtitleOpacity =
        1 - Curves.easeInOut.transform((progress / .8).clamp(0.0, 1.0));
    return ClipRect(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            if (subtitle != null)
              Positioned(
                left: inset,
                right: inset,
                top: top + rowHeight + 8,
                child: IgnorePointer(
                  child: Opacity(
                    key: ValueKey('page-subtitle-$title'),
                    opacity: subtitleOpacity,
                    child: _reveal(Text(subtitle!, style: _subtitleStyle)),
                  ),
                ),
              ),
            Positioned(
              left: inset,
              right: inset,
              top: top,
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    if (_hasNavigationRow)
                      SizedBox(width: leading == null ? 0 : 48 * eased)
                    else
                      ?leading,
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: _reveal(
                          Text(
                            title,
                            key: ValueKey('page-title-$title'),
                            style: _titleStyle(fontSize),
                          ),
                        ),
                      ),
                    ),
                    if (_hasNavigationRow)
                      SizedBox(width: trailing == null ? 0 : 48 * eased)
                    else
                      ?trailing,
                  ],
                ),
              ),
            ),
            if (_hasNavigationRow) ...[
              Positioned(
                left: inset - 12,
                right: inset,
                top: 4,
                height: 48,
                child: Row(
                  children: [
                    ?leading,
                    const Spacer(),
                    IgnorePointer(
                      child: Opacity(
                        opacity: subtitleOpacity,
                        child: Text(
                          navigationLabel!,
                          style: textStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.3,
                            color: blue,
                          ),
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: overlapsContent ? 1 : progress,
                child: const Divider(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PageHeadingDelegate oldDelegate) =>
      title != oldDelegate.title ||
      subtitle != oldDelegate.subtitle ||
      leading != oldDelegate.leading ||
      trailing != oldDelegate.trailing ||
      navigationLabel != oldDelegate.navigationLabel ||
      inset != oldDelegate.inset ||
      headingAnimation != oldDelegate.headingAnimation ||
      width != oldDelegate.width ||
      textScaler != oldDelegate.textScaler ||
      textDirection != oldDelegate.textDirection ||
      textStyle != oldDelegate.textStyle;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class SoftPanel extends StatelessWidget {
  const SoftPanel({super.key, required this.child, this.color = wash});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.medication_outlined,
    this.action,
    this.padding = const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
  });
  final String title, description;
  final IconData icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: wash, shape: BoxShape.circle),
          child: Icon(icon, size: 32, color: blue),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: muted, height: 1.6),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class PillAvatar extends StatelessWidget {
  const PillAvatar(this.pill, {super.key, this.size = 48});
  final Map<String, dynamic> pill;
  final double size;
  @override
  Widget build(BuildContext context) {
    final url = (pill['ITEM_IMAGE'] ?? '').toString();
    final placeholder = Icon(
      Icons.medication_outlined,
      size: size * .48,
      color: blue,
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: url.isEmpty
          ? placeholder
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SafeArea(
    maintainBottomViewPadding: true,
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    ),
  );
}

String scheduleSummary(
  Map<String, dynamic> pill,
  List<Map<String, dynamic>> groups,
) {
  final times = <String>{
    if (!Medication.isEnded(pill)) ...Medication.times(pill['times']),
  };
  for (final group in groups.where(
    (g) =>
        (g['pillIds'] as List? ?? []).contains(pill['id']) &&
        !Medication.isEnded(g),
  )) {
    times.addAll(Medication.times(group['times']));
  }
  return times.isEmpty
      ? '일정 설정하기'
      : '매일 ${(times.toList()..sort()).join(' · ')}';
}

bool isStoredMedication(
  Map<String, dynamic> pill,
  List<Map<String, dynamic>> groups,
) {
  if (pill['archived'] == true) return true;
  if (!Medication.isEnded(pill)) return false;
  return !groups.any(
    (g) =>
        (g['pillIds'] as List? ?? []).contains(pill['id']) &&
        !Medication.isEnded(g) &&
        Medication.times(g['times']).isNotEmpty,
  );
}
