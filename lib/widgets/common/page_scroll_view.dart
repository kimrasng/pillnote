import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'content_reveal.dart';

/// A single scroll surface keeps the heading pinned without affecting nested
/// gestures (for example, panning the pharmacy map).
class PageScrollView extends StatefulWidget {
  const PageScrollView({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBackButton = false,
    this.compactHeading = false,
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

  /// A fixed 18-point title matching the app bar on settings pages.
  final bool compactHeading;

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
  State<PageScrollView> createState() => _PageScrollViewState();
}

class _PageScrollViewState extends State<PageScrollView> {
  final _controller = ScrollController();
  bool _revealScheduled = false;

  ScrollController get _effectiveController => widget.controller ?? _controller;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_scheduleReveal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleReveal();
  }

  void _scheduleReveal() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || !_effectiveController.hasClients) return;
      final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (keyboardInset == 0 ||
          focusContext == null ||
          focusContext.findAncestorStateOfType<_PageScrollViewState>() !=
              this) {
        return;
      }
      RenderObject? field = focusContext.findRenderObject();
      focusContext.visitAncestorElements((element) {
        if (element.widget is TextField) {
          field = element.findRenderObject();
          return false;
        }
        return true;
      });
      final fieldBox = field;
      if (fieldBox is! RenderBox || !fieldBox.hasSize) return;
      final view = View.of(context);
      final keyboardTop =
          view.physicalSize.height / view.devicePixelRatio - keyboardInset;
      final fieldBottom = fieldBox
          .localToGlobal(Offset(0, fieldBox.size.height))
          .dy;
      final overlap = fieldBottom + 20 - keyboardTop;
      if (overlap <= 0) return;
      final position = _effectiveController.position;
      final target = (position.pixels + overlap).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        position.jumpTo(target);
      } else {
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleReveal);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final leading = widget.showBackButton && Navigator.canPop(context)
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
            title: widget.title,
            subtitle: widget.subtitle,
            leading: leading,
            trailing: widget.trailing,
            navigationLabel: widget.navigationLabel,
            compactHeading: widget.compactHeading,
            inset: widget.headingInset,
            headingAnimation: widget.headingAnimation,
            width: constraints.maxWidth,
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
            textStyle: DefaultTextStyle.of(context).style,
          );
          return CustomScrollView(
            controller: _effectiveController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: _ContentScrollPhysics(parent: widget.physics),
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: heading),
              SliverPadding(
                padding: widget.padding,
                sliver:
                    widget.sliver ?? SliverList.list(children: widget.children),
              ),
              // Keep fill-remaining content and bottom actions in their original
              // positions; only add room to scroll past the keyboard.
              if (keyboardInset > 0)
                SliverToBoxAdapter(child: SizedBox(height: keyboardInset)),
            ],
          );
        },
      ),
    );
  }
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
    required this.compactHeading,
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
  final bool compactHeading;
  final double inset;
  final Animation<double>? headingAnimation;
  final double width;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final TextStyle textStyle;

  double get _expandedTitleSize => compactHeading ? 18 : 30;
  double get _collapsedTitleSize => compactHeading ? 18 : 22;

  TextStyle _titleStyle(double size) => textStyle.copyWith(
    fontSize: size,
    fontWeight: compactHeading ? FontWeight.w600 : FontWeight.w700,
    letterSpacing: compactHeading ? 0 : -1,
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
    !_hasNavigationRow && (compactHeading || _actionWidth > 0) ? 48 : 0,
    _height(
      title,
      _titleStyle(fontSize),
      width - inset * 2 - _actionWidth * progress,
    ),
  );
  double get _expandedTop => _hasNavigationRow ? 80 : (compactHeading ? 4 : 24);
  @override
  late final double minExtent = math.max(
    56,
    _rowHeight(_collapsedTitleSize) + 8,
  );
  @override
  late final double maxExtent = compactHeading && !_hasNavigationRow
      ? minExtent +
            (subtitle == null
                ? 0
                : 8 +
                      _height(subtitle!, _subtitleStyle, width - inset * 2) +
                      20)
      : math.max(
          minExtent + 24,
          _expandedTop +
              _rowHeight(
                _expandedTitleSize,
                progress: _hasNavigationRow ? 0 : 1,
              ) +
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
    final collapseExtent = maxExtent - minExtent;
    final progress = collapseExtent == 0
        ? 0.0
        : (shrinkOffset / collapseExtent).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(progress);
    final fontSize = lerpDouble(
      _expandedTitleSize,
      _collapsedTitleSize,
      eased,
    )!;
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
      compactHeading != oldDelegate.compactHeading ||
      inset != oldDelegate.inset ||
      headingAnimation != oldDelegate.headingAnimation ||
      width != oldDelegate.width ||
      textScaler != oldDelegate.textScaler ||
      textDirection != oldDelegate.textDirection ||
      textStyle != oldDelegate.textStyle;
}
