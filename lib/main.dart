import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/screen/main.dart';
import 'package:pillnote/screen/onboarding.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/app_device_service.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:pillnote/widgets/startup_permission_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionStore.instance.initialize();
  await AppServices.initialize();
  runApp(const MyApp());
  unawaited(AppServices.instance.reminders.refresh());
  // Network and Firebase initialization must not delay the local first frame.
  unawaited(initializeOnlineServices());
}

Future<void> initializeOnlineServices() async {
  AppDeviceService.instance.initialize();
  await Future.wait([
    AppDeviceService.instance.register(),
    () async {
      if (!SessionStore.instance.isLoggedIn) return;
      try {
        await ApiClient.instance.me();
        await AppServices.instance.sync.reconcileWithServer();
      } catch (_) {
        // Local records remain available while the network is unavailable.
      }
    }(),
    () async {
      await PushNotificationService.instance.initialize();
      if (!SessionStore.instance.isLoggedIn) return;
      await PushNotificationService.instance.refreshPermissionStatus();
      if (PushNotificationService.instance.permissionGranted == true) {
        await PushNotificationService.instance.registerCurrentDevice();
      }
    }(),
  ]);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<SessionChange>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppServices.instance.reminders.refresh());
      unawaited(AppDeviceService.instance.register());
    }
  }

  void _startupPermissionsCompleted() {
    unawaited(AppServices.instance.reminders.refresh());
    unawaited(() async {
      await PushNotificationService.instance.refreshPermissionStatus();
      if (SessionStore.instance.isLoggedIn &&
          PushNotificationService.instance.permissionGranted == true) {
        await PushNotificationService.instance.registerCurrentDevice();
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'PillNote',
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => kIsWeb
          ? ColoredBox(
              color: wash,
              child: Center(
                child: SizedBox(
                  width: 480,
                  child: ColoredBox(color: Colors.white, child: child),
                ),
              ),
            )
          : child!,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          surface: Colors.white,
        ),
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: Colors.white,
        dividerTheme: const DividerThemeData(color: line, space: 1),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: ink, fontSize: 15, height: 1.45),
          bodyLarge: TextStyle(color: ink, fontSize: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            textStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(vertical: 16),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: line),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: blue, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: const Color(0xFFF1F5F9),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Pretendard',
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: StartupPermissionGate(
        service: AppServices.instance.permissions,
        onCompleted: _startupPermissionsCompleted,
        child:
            AppServices.instance.shouldShowOnboarding &&
                !SessionStore.instance.isLoggedIn
            ? const Onboarding()
            : const Main(),
      ),
    );
  }
}
