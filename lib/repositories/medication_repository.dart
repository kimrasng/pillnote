import 'dart:async';

import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/models/medication.dart';

/// Medication and group edits are persisted locally before notifying sync.
class MedicationRepository {
  MedicationRepository({
    required this._store,
    required this._onChanged,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationStore _store;
  final FutureOr<void> Function() _onChanged;
  final DateTime Function() _now;

  List<Map<String, dynamic>> getPills() => _store.readPills();

  List<Map<String, dynamic>> getGroups() =>
      _store.readGroups().where((group) => group['deleted'] != true).toList();

  Future<void> addPill(Map<String, dynamic> pill, num? stock) async {
    final pills = getPills();
    final now = _now();
    pills.add({
      ...pill,
      'id': now.microsecondsSinceEpoch.toString(),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'startDate': pill['startDate'],
      'endDate': pill['endDate'],
      'times': Medication.times(pill['times']),
      'stock': stock,
      'trackStock': stock != null,
      'dosage': pill['dosage'] ?? 1.0,
      'archived': false,
    });
    await _savePills(pills);
  }

  Future<void> updatePill(String id, Map<String, dynamic> changes) async {
    final pills = getPills();
    final index = pills.indexWhere((pill) => pill['id'].toString() == id);
    if (index == -1) return;
    pills[index] = {
      ...pills[index],
      ...changes,
      'id': id,
      'updatedAt': _now().toIso8601String(),
    };
    await _savePills(pills);
  }

  Future<void> archivePill(String id, bool archived) => updatePill(id, {
    'archived': archived,
    'archivedAt': archived ? _now().toIso8601String() : null,
  });

  Future<void> updatePillSchedule(
    String pillId,
    String? startDate,
    String? endDate,
    List<String> times,
    double dosage,
  ) => updatePill(pillId, {
    'startDate': startDate,
    'endDate': endDate,
    'times': times,
    'dosage': dosage,
  });

  Future<void> removePill(String pillId) async {
    final pills = getPills()..removeWhere((pill) => pill['id'] == pillId);
    await _savePills(pills);
  }

  Future<void> removePillFromGroups(String pillId) async {
    final groups = _store.readGroups();
    for (final group in groups) {
      final ids = List<dynamic>.from(group['pillIds'] as List? ?? const []);
      ids.removeWhere((id) => id.toString() == pillId);
      group['pillIds'] = ids;
    }
    groups.removeWhere((group) => (group['pillIds'] as List).isEmpty);
    await _saveGroups(groups);
  }

  Future<void> saveGroup(Map<String, dynamic> group) async {
    final groups = _store.readGroups();
    final now = _now();
    final saved = {
      ...group,
      'id': group['id'] ?? now.microsecondsSinceEpoch.toString(),
      'updatedAt': now.toIso8601String(),
      'deleted': false,
    };
    final index = groups.indexWhere((item) => item['id'] == saved['id']);
    if (index == -1) {
      groups.add(saved);
    } else {
      groups[index] = saved;
    }
    await _saveGroups(groups);
  }

  Future<void> removeGroup(String groupId) async {
    final groups = _store.readGroups();
    for (final group in groups.where((g) => g['id'] == groupId)) {
      group['deleted'] = true;
      group['updatedAt'] = _now().toIso8601String();
    }
    await _saveGroups(groups);
  }

  Future<void> _savePills(List<Map<String, dynamic>> pills) async {
    final generation = _store.dataGeneration;
    await _store.savePills(pills);
    if (generation != _store.dataGeneration) return;
    await _onChanged();
  }

  Future<void> _saveGroups(List<Map<String, dynamic>> groups) async {
    final generation = _store.dataGeneration;
    await _store.saveGroups(groups);
    if (generation != _store.dataGeneration) return;
    await _onChanged();
  }
}
