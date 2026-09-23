import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/services/push_notification_service.dart';

void main() {
  test('foreground missed-dose notification never renders server PII', () {
    const message = RemoteMessage(
      data: {'type': 'missed-dose'},
      notification: RemoteNotification(
        title: '홍길동님의 복약 알림',
        body: '혈압약을 08:00에 복용하지 않았습니다.',
      ),
    );

    final text = PushNotificationService.foregroundMessageText(message);

    expect(text, '확인이 필요한 복약 알림이 도착했습니다.');
    expect(text, isNot(contains('홍길동')));
    expect(text, isNot(contains('혈압약')));
    expect(text, isNot(contains('08:00')));
  });

  test('unknown foreground notification uses a generic message', () {
    const message = RemoteMessage(data: {'type': 'future-event'});

    expect(
      PushNotificationService.foregroundMessageText(message),
      '새로운 알림이 도착했습니다.',
    );
  });
}
