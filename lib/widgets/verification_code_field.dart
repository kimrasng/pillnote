import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pillnote/widgets/app_ui.dart';

/// Six visual cells backed by one native field for paste, autofill and editing.
class VerificationCodeField extends StatefulWidget {
  const VerificationCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autofocus = true,
    this.onSubmitted,
    this.arrivalSequence = 0,
    this.arrivalDelay = const Duration(milliseconds: 180),
  });

  final TextEditingController controller;
  final bool enabled, autofocus;
  final ValueChanged<String>? onSubmitted;
  final int arrivalSequence;
  final Duration arrivalDelay;

  @override
  State<VerificationCodeField> createState() => _VerificationCodeFieldState();
}

class _VerificationCodeFieldState extends State<VerificationCodeField>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode();
  late final _arrival = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 4000),
  );
  Timer? _arrivalTimer;
  bool _arrivalInitialized = false;
  bool _reduceMotion = false;
  int _tappedCell = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_arrivalInitialized) {
      _arrivalInitialized = true;
      _playArrival();
    }
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant VerificationCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.arrivalSequence != widget.arrivalSequence) _playArrival();
    _syncAnimation();
  }

  int? get _activeCell {
    if (!widget.enabled || !_focusNode.hasFocus) return null;
    final value = widget.controller.value;
    final offset = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    if (offset >= 6) return null;
    return math.min(offset, value.text.length).clamp(0, 5);
  }

  void _syncAnimation() {
    if (_reduceMotion || !widget.enabled) {
      _cancelArrival();
    } else if (_arrivalInitialized &&
        !_arrival.isAnimating &&
        _arrivalTimer == null) {
      _playArrival();
    }
  }

  void _cancelArrival() {
    _arrivalTimer?.cancel();
    _arrivalTimer = null;
    _arrival.stop();
    _arrival.value = 1;
  }

  void _playArrival() {
    _cancelArrival();
    if (_reduceMotion || !widget.enabled) {
      return;
    }
    _arrivalTimer = Timer(widget.arrivalDelay, () {
      _arrivalTimer = null;
      if (!mounted) return;
      _arrival.value = 0;
      _arrival.repeat();
      if (widget.autofocus) _focusNode.requestFocus();
    });
  }

  double _waveStrength(int index) {
    if (!_arrival.isAnimating) return 0;
    // Each cell has exactly one smooth rise and fall per four-second cycle.
    final elapsed = _arrival.value * 4000 - index * 320;
    if (elapsed <= 0 || elapsed >= 1200) return 0;
    return (1 - math.cos(2 * math.pi * elapsed / 1200)) / 2;
  }

  void _refresh() {
    _syncAnimation();
    setState(() {});
  }

  void _selectCell() {
    final length = widget.controller.text.length;
    widget.controller.selection = _tappedCell < length
        ? TextSelection(baseOffset: _tappedCell, extentOffset: _tappedCell + 1)
        : TextSelection.collapsed(offset: length);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    _arrivalTimer?.cancel();
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ExcludeSemantics(
        child: Text('인증번호', style: TextStyle(fontSize: 14, color: muted)),
      ),
      const SizedBox(height: 12),
      Builder(
        builder: (context) {
          const gap = 8.0;
          final height = math.max(
            60.0,
            MediaQuery.textScalerOf(context).scale(24) * 1.2 + 16,
          );
          return Listener(
            onPointerDown: (event) {
              final box = context.findRenderObject()! as RenderBox;
              final cellWidth = (box.size.width - gap * 5) / 6;
              _tappedCell = (event.localPosition.dx / (cellWidth + gap))
                  .floor()
                  .clamp(0, 5);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: TextSelectionTheme(
                    data: const TextSelectionThemeData(
                      selectionColor: Colors.transparent,
                      selectionHandleColor: Colors.transparent,
                    ),
                    child: Semantics(
                      label: '인증번호',
                      hint: '6자리 숫자를 입력하세요.',
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        autofocus: widget.autofocus,
                        enabled: widget.enabled,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        autocorrect: false,
                        enableSuggestions: false,
                        selectAllOnFocus: false,
                        showCursor: false,
                        style: const TextStyle(color: Colors.transparent),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _CodePasteFormatter(),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onTapAlwaysCalled: true,
                        onTap: _selectCell,
                        onSubmitted: widget.onSubmitted,
                      ),
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _arrival,
                      builder: (context, _) {
                        final code = widget.controller.text;
                        final active = _activeCell;
                        return Row(
                          children: [
                            for (var index = 0; index < 6; index++) ...[
                              if (index > 0) SizedBox(width: gap),
                              Expanded(
                                child: Container(
                                  key: ValueKey('code-cell-$index'),
                                  height: height,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color.lerp(
                                      wash,
                                      Color.alphaBlend(
                                        blue.withValues(alpha: .055),
                                        wash,
                                      ),
                                      _waveStrength(index),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: line,
                                      width: active == index ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: index < code.length
                                        ? FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              code[index],
                                              style: const TextStyle(
                                                color: ink,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w600,
                                                height: 1.2,
                                              ),
                                            ),
                                          )
                                        : active == index
                                        ? Opacity(
                                            key: const ValueKey('code-cursor'),
                                            opacity: .65,
                                            child: Container(
                                              width: 2,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: blue,
                                                borderRadius:
                                                    BorderRadius.circular(1),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

/// A whole code pasted into a partially filled field replaces the old code.
class _CodePasteFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > 6 && oldValue.selection.isValid) {
      final start = oldValue.selection.start;
      final suffix = oldValue.text.length - oldValue.selection.end;
      final end = newValue.text.length - suffix;
      if (start >= 0 && end <= newValue.text.length && end - start >= 6) {
        return TextEditingValue(
          text: newValue.text.substring(start, start + 6),
          selection: const TextSelection.collapsed(offset: 6),
        );
      }
    }
    return newValue;
  }
}
