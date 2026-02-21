import 'dart:convert';

import 'package:flutter/material.dart';


// 약 정보
class Pill {
  static int _nextid = 0;

  final int id;
  final int count; // 개수
  // (공공데이터 포탈 기준)
  final String name; // 약품 이름
  final int pilCode; // 약품 코드
  final String effect; // 효능
  final String guid; // 사용법
  final String warning; // 주의사항 경고
  final String caution; // 주의사항
  final String sideEffect; // 부작용
  final String img;

  Pill({
    int? id,
    required this.count,
    required this.name,
    required this.pilCode,
    required this.effect,
    required this.guid,
    required this.warning,
    required this.caution,
    required this.sideEffect,
    required this.img,
  }) : id = id ?? _nextid++;

  Pill.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        count = json['count'],
        name = json['name'],
        pilCode = json['pilCode'],
        effect = json['effect'],
        guid = json['guid'],
        warning = json['warning'],
        caution = json['caution'],
        sideEffect = json['sideEffect'],
        img = json['img'];

  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'count': count,
        'name': name,
        'pilCode': pilCode,
        'effect': effect,
        'guid': guid,
        'warning': warning,
        'caution': caution,
        'sideEffect': sideEffect,
        'img': img
      };
}

// 복용 관련 정보(어떤 약을 먹는지 하루에 얼마나 먹는지 등)
class UserPill {
  static int _nextid = 0;

  final int id;
  final int pillId; // Pill.id 참조
  final DateTime startDate;
  final DateTime? endDate;
  final int dosePerTake; // 1회 복용양
  final int timesPerDay; // 1일 복용횟
  final List<TimeOfDay> alarmTimes; // 알람 시간
  final bool isActive; // 활성상태 약을 복용 할지 말지

  UserPill({
    int? id,
    required this.pillId,
    required this.startDate,
    this.endDate,
    required this.dosePerTake,
    required this.timesPerDay,
    required this.alarmTimes,
    this.isActive = true
  }) : id = id ?? _nextid++;

  UserPill.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        pillId = json['pillId'],
        startDate = DateTime.parse(json['startDate']),
        endDate = json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
        dosePerTake = json['dosePerTake'],
        timesPerDay = json['timesPerDay'],
        alarmTimes = (json['alarmTimes'] as List)
            .map((timeStr) => TimeOfDay(
                hour: int.parse(timeStr.split(':')[0]),
                minute: int.parse(timeStr.split(':')[1])))
            .toList(),
        isActive = json['isActive'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'pillId': pillId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'dosePerTake': dosePerTake,
        'timesPerDay': timesPerDay,
        'alarmTimes': alarmTimes.map((time) => '${time.hour}:${time.minute}').toList(),
        'isActive': isActive,
      };
}


// 복용 기록
class PillTakeLog {
  static int _nextid = 0;

  final int id;
  final int userPillId; // UserPill.id 참조
  final DateTime scheduledTime; // 예정 섭취시간 alaramTimes(AlaramSettings) 에 있는거 기준
  final DateTime? takeTime; // 복용 시간 사용자가 복용 클릭한 기준 시간
  final bool isTake;

  PillTakeLog({
    int? id,
    required this.userPillId,
    required this.scheduledTime,
    required this.takeTime,
    this.isTake = false,
  }) : id = id ?? _nextid++;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userPillId': userPillId,
    'scheduledTime': scheduledTime,
    'takeTime': takeTime,
    'isTake': isTake,
  };
}


// 알림 시간
class AlarmSettings {
  final TimeOfDay morning;
  final TimeOfDay afternoon;
  final TimeOfDay night;

  AlarmSettings({
    TimeOfDay? morning,
    TimeOfDay? afternoon,
    TimeOfDay? night,
  })  : morning = morning ?? const TimeOfDay(hour: 6, minute: 30),
        afternoon = afternoon ?? const TimeOfDay(hour: 12, minute: 30),
        night = night ?? const TimeOfDay(hour: 18, minute: 30);

  Map<String, dynamic> toJson() => {
    'morning' : morning,
    'afternoon' : afternoon,
    'night' : night,
  };
}
