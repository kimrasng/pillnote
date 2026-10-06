/// Timestamp-based snapshot merging preserves cancellation and deletion markers.
/// Equal timestamps favor the local snapshot, matching the existing sync format.
class SnapshotMerger {
  SnapshotMerger._();

  static Map<String, dynamic> merge(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) => {
    'schemaVersion': 1,
    'deviceId': local['deviceId'] ?? remote['deviceId'],
    'pills': _mergeById(remote['pills'], local['pills']),
    'groups': _mergeById(remote['groups'], local['groups']),
    'intakeHistory': _mergeHistory(
      remote['intakeHistory'],
      local['intakeHistory'],
    ),
    'settings': {
      ...Map<String, dynamic>.from(remote['settings'] as Map? ?? const {}),
      ...Map<String, dynamic>.from(local['settings'] as Map? ?? const {}),
    },
  };

  static List<Map<String, dynamic>> _mergeById(Object? remote, Object? local) {
    final merged = <String, Map<String, dynamic>>{};
    for (final source in [remote, local]) {
      if (source is! List) continue;
      for (final item in source.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final existing = merged[id];
        if (existing == null ||
            _isNewer(existing, map, fallback: 'createdAt')) {
          merged[id] = map;
        }
      }
    }
    return merged.values.toList();
  }

  static Map<String, dynamic> _mergeHistory(Object? remote, Object? local) {
    final history = <String, dynamic>{};
    for (final source in [remote, local]) {
      if (source is! Map) continue;
      for (final entry in source.entries) {
        final key = entry.key.toString();
        final existing = List<dynamic>.from(history[key] as List? ?? const []);
        for (final item in entry.value as List? ?? const []) {
          if (item is! Map) continue;
          final index = existing.indexWhere(
            (value) =>
                value is Map &&
                value['pillId'] == item['pillId'] &&
                value['groupId'] == item['groupId'] &&
                value['scheduledTime'] == item['scheduledTime'],
          );
          if (index == -1) {
            existing.add(Map<String, dynamic>.from(item));
          } else if (_isNewer(
            existing[index] as Map,
            item,
            fallback: 'takenAt',
          )) {
            existing[index] = Map<String, dynamic>.from(item);
          }
        }
        history[key] = existing;
      }
    }
    return history;
  }

  static bool _isNewer(Map existing, Map incoming, {required String fallback}) {
    final oldAt = DateTime.tryParse(
      '${existing['updatedAt'] ?? existing[fallback]}',
    );
    final newAt = DateTime.tryParse(
      '${incoming['updatedAt'] ?? incoming[fallback]}',
    );
    return oldAt == null || (newAt != null && !newAt.isBefore(oldAt));
  }
}
