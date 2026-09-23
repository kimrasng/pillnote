import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/main.dart';
import 'package:pillnote/screen/onboarding.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Controller.init();
  await SessionStore.instance.initialize();
  await PushNotificationService.instance.initialize();

  if (SessionStore.instance.isLoggedIn) {
    try {
      await ApiClient.instance.me();
      await Controller.reconcileWithServer();
      await PushNotificationService.instance.registerCurrentDevice();
    } catch (_) {
      // 네트워크가 없어도 로컬 우선 기능으로 앱을 시작합니다.
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<SessionChange>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _messageSubscription = PushNotificationService.instance.foregroundMessages
        .listen((message) {
          final text = PushNotificationService.foregroundMessageText(message);
          _messengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(text)));
        });
    _sessionSubscription = SessionStore.instance.changes.listen((change) {
      if (change.reason != SessionChangeReason.expired) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const Main()),
          (_) => false,
        );
        _messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('로그인 세션이 만료되었습니다. 로컬 데이터는 유지되며 다시 로그인할 수 있습니다.'),
            ),
          );
      });
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'PillNote',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          surface: Colors.white,
        ),
        fontFamily: 'Pretendard',
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: const Color(0xFFF1F5F9),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home:
          Controller.shouldShowOnboarding() && !SessionStore.instance.isLoggedIn
          ? const Onboarding()
          : const Main(),
    );
  }
}
