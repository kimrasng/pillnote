import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pillnote/models/medication.dart';

import 'common/app_colors.dart';

export 'common/app_colors.dart';
export 'common/content_reveal.dart';
export 'common/page_scroll_view.dart';

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
  const PillAvatar(this.pill, {super.key, this.size = 48, this.width});
  final Map<String, dynamic> pill;
  final double size;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final url = (pill['ITEM_IMAGE'] ?? '').toString().trim();
    final placeholder = Icon(
      Icons.medication_outlined,
      size: math.min(size * .48, 40),
      color: muted,
    );
    return SizedBox(
      width: width ?? size * 1.5,
      height: size,
      child: ExcludeSemantics(
        child: url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                    wasSynchronouslyLoaded || frame != null
                    ? child
                    : placeholder,
                errorBuilder: (_, _, _) => placeholder,
              ),
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
