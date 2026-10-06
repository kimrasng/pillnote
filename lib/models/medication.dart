class Medication {
  Medication._();

  static String name(Map<String, dynamic> pill) =>
      (pill['ITEM_NAME'] ?? pill['name'] ?? '이름 없는 약').toString();
  static String quantity(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
  static String unit(Map<String, dynamic> pill) =>
      (pill['unit'] ?? '정').toString();
  static bool tracksStock(Map<String, dynamic> pill) =>
      pill['trackStock'] != false && pill['stock'] is num;
  static bool isLowStock(Map<String, dynamic> pill) =>
      tracksStock(pill) &&
      (pill['stock'] as num) <= ((pill['dosage'] as num?) ?? 1) * 3;
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  static bool isEnded(Map<String, dynamic> pill, {DateTime? at}) {
    final end = DateTime.tryParse(pill['endDate']?.toString() ?? '');
    final now = at ?? DateTime.now();
    return end != null && end.isBefore(DateTime(now.year, now.month, now.day));
  }

  static bool isActiveOn(Map<String, dynamic> item, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (isArchivedOn(item, date)) return false;
    final start = DateTime.tryParse(item['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(item['endDate']?.toString() ?? '');
    return (start == null ||
            !day.isBefore(DateTime(start.year, start.month, start.day))) &&
        (end == null || !day.isAfter(DateTime(end.year, end.month, end.day)));
  }

  static bool isArchivedOn(Map<String, dynamic> item, DateTime date) {
    if (item['archived'] != true) return false;
    final archived = DateTime.tryParse(item['archivedAt']?.toString() ?? '');
    final day = DateTime(date.year, date.month, date.day);
    return archived == null ||
        !day.isBefore(DateTime(archived.year, archived.month, archived.day));
  }

  static List<String> times(Object? value) {
    if (value is! List) return [];
    final result = <String>{};
    for (final time in value) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch('$time');
      if (match == null) continue;
      final hour = int.parse(match[1]!);
      final minute = int.parse(match[2]!);
      if (hour < 24 && minute < 60) {
        result.add(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        );
      }
    }
    return result.toList()..sort();
  }
}

class ScheduledDose {
  const ScheduledDose({
    required this.pill,
    required this.time,
    this.groups = const [],
  });
  final Map<String, dynamic> pill;
  final String time;
  final List<String> groups;
  String get pillId => pill['id'].toString();
  String get key => '$pillId|$time';
}
