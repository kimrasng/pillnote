import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/features/pillinfo.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/api/public_api_cache.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

int clockMicros() => DateTime.now().microsecondsSinceEpoch;

class Probe {
  Probe(this.scenario, this.mode, this.round);
  final String scenario, mode;
  final int round;
  int action = 0, query = 0, wire = 0, body = 0, ready = 0, paint = 0;
  int transition = 0, first = 0, stable = 0, requests = 0;
  String? edge;
  final completed = Completer<Map<String, dynamic>>();
  void beginQuery() {
    query = clockMicros();
  }

  void dataReady() {
    ready = clockMicros();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      paint = clockMicros();
    });
  }

  void frames(List<ui.FrameTiming> frames) {
    if (ready == 0 || completed.isCompleted) return;
    for (final frame in frames) {
      final finish = frame.timestampInMicroseconds(
        ui.FramePhase.rasterFinishWallTime,
      );
      final buildFinish =
          finish -
          frame.timestampInMicroseconds(ui.FramePhase.rasterFinish) +
          frame.timestampInMicroseconds(ui.FramePhase.buildFinish);
      final buildStart =
          finish -
          frame.timestampInMicroseconds(ui.FramePhase.rasterFinish) +
          frame.timestampInMicroseconds(ui.FramePhase.buildStart);
      // State is updated before dataReady. A frame whose build starts later
      // includes the loaded result, without counting timings batch delivery.
      if (buildStart < ready) continue;
      if (first == 0) first = finish;
      if (scenario == 'detail_open' &&
          (transition == 0 || buildFinish < transition))
        continue;
      stable = finish;
      if (query == 0 || first < ready || stable < action) {
        completed.completeError(StateError('Invalid frame clock correlation'));
        return;
      }
      completed.complete({
        'scenario': scenario,
        'mode': mode,
        'round': round,
        'actionToFirstFrameMs': (first - action) / 1000,
        'requestToFirstFrameMs': (first - query) / 1000,
        'actionToStableFrameMs': (stable - action) / 1000,
        'actionToDataReadyMs': (ready - action) / 1000,
        'readyToFirstFrameMs': (first - ready) / 1000,
        'inputWaitMs': (query - action) / 1000,
        'networkBodyMs': wire == 0 ? null : (body - wire) / 1000,
        'networkRequests': requests,
        'resultFrameBuildStartAfterReadyMs': (buildStart - ready) / 1000,
        'edgeCache': edge,
      });
      return;
    }
  }
}

class WireClient extends http.BaseClient {
  final delegate = IOClient();
  Probe? probe;
  bool bypass = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (bypass) request.headers['cache-control'] = 'no-cache';
    final active = probe;
    if (active != null) {
      active.requests++;
      active.wire = clockMicros();
    }
    final response = await delegate.send(request);
    if (active != null) active.edge = response.headers['x-pillnote-edge-cache'];
    final stream = response.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) => sink.add(data),
        handleDone: (sink) {
          if (active != null) active.body = clockMicros();
          sink.close();
        },
      ),
    );
    return http.StreamedResponse(
      stream,
      response.statusCode,
      headers: response.headers,
      contentLength: response.contentLength,
      request: response.request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

class NoCache extends PublicApiCache {
  NoCache() : super.inMemory();
  @override
  Future<Map<String, dynamic>> getOrLoad({
    required String key,
    required Duration ttl,
    required Future<Map<String, dynamic>> Function() load,
    required bool Function(Map<String, dynamic>) cacheable,
  }) => load();
}

final nav = GlobalKey<NavigatorState>();
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('pillnote.latency.benchmark.');
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatefulWidget {
  const BenchmarkApp({super.key});
  @override
  State<BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<BenchmarkApp> {
  final wire = WireClient();
  final records = <Map<String, dynamic>>[];
  Probe? active;
  Widget page = const Scaffold(
    body: Center(child: Text('Preparing read-only benchmark')),
  );
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_run());
    });
  }

  void _timings(List<ui.FrameTiming> frames) => active?.frames(frames);
  TextField? _field(Element element) {
    if (element.widget is TextField) return element.widget as TextField;
    TextField? found;
    element.visitChildren((child) {
      found ??= _field(child);
    });
    return found;
  }

  ApiClient _client(PublicApiCache cache) => ApiClient(
    client: wire,
    cache: cache,
    sessionStore: SessionStore.inMemory(),
  );

  Future<void> _run() async {
    try {
      if (!kProfileMode) throw StateError('Measurements require profile mode');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final health = await _client(NoCache()).health();
      print(
        'PN_BENCH_META ${jsonEncode({'version': health['version'], 'profile': kProfileMode, 'device': 'Pixel 10 Pro Android emulator', 'refreshRate': ui.PlatformDispatcher.instance.views.first.display.refreshRate, 'searchLimit': 50, 'samplesPerCase': 6, 'measuredAt': DateTime.now().toUtc().toIso8601String()})}',
      );
      // Warm the D1/edge paths before controlled comparisons; no production
      // cache deletion, authenticated requests or account writes are performed.
      final warm = _client(NoCache());
      final items = await warm.searchDrugs('타이레놀');
      if (items.isEmpty) throw StateError('Search returned no public fixtures');
      final seq = items.first['ITEM_SEQ'].toString();
      final detail = await warm.drugDetail(seq);
      if (detail['meta']['stale'] != false ||
          detail['meta']['consumerInfoAvailable'] != true) {
        throw StateError(
          'A fresh complete detail is needed for a fair cache comparison',
        );
      }
      for (var round = -1; round < 6; round++) {
        // Alternate modes to reduce bias from changing network conditions.
        final modes = round.isOdd
            ? ['baseline', 'edge', 'local_memory', 'local_restore']
            : ['local_restore', 'local_memory', 'edge', 'baseline'];
        for (final scenario in [
          'search_submit',
          'search_typing',
          'detail_open',
        ]) {
          for (final mode in modes) {
            wire.probe = null;
            wire.bypass = false;
            await prefs.remove(PublicApiCache.storageKey);
            final cache = mode == 'baseline'
                ? NoCache()
                : PublicApiCache(preferences: () async => prefs);
            var client = _client(cache);
            if (mode.startsWith('local_')) {
              if (scenario == 'detail_open') {
                await client.drugDetail(seq);
              } else {
                await client.searchDrugs('타이레놀');
              }
              if (mode == 'local_restore')
                client = _client(
                  PublicApiCache(preferences: () async => prefs),
                );
            }
            wire.bypass = mode == 'baseline';
            final probe = Probe(scenario, mode, round);
            if (scenario == 'detail_open') {
              setState(() {
                page = const Scaffold(body: Center(child: Text('약 검색 결과')));
              });
              await WidgetsBinding.instance.endOfFrame;
              await Future<void>.delayed(const Duration(milliseconds: 450));
              active = probe;
              wire.probe = probe;
              final route = MaterialPageRoute<void>(
                builder: (_) => Pillinfo(
                  pillSEQ: seq,
                  isLocal: false,
                  apiClient: client,
                  onBenchmarkStart: probe.beginQuery,
                  onBenchmarkReady: probe.dataReady,
                ),
              );
              probe.action = clockMicros();
              unawaited(nav.currentState!.push(route));
              route.animation!.addStatusListener((status) {
                if (status == AnimationStatus.completed)
                  probe.transition = clockMicros();
              });
            } else {
              final key = GlobalKey();
              setState(() {
                page = Pillsearch(
                  key: key,
                  apiClient: client,
                  onBenchmarkStart: probe.beginQuery,
                  onBenchmarkReady: probe.dataReady,
                );
              });
              await WidgetsBinding.instance.endOfFrame;
              await Future<void>.delayed(const Duration(milliseconds: 450));
              final field = _field(key.currentContext! as Element)!;
              field.controller!.text = '타이레놀';
              active = probe;
              wire.probe = probe;
              probe.action = clockMicros();
              if (scenario == 'search_typing') {
                field.onChanged!('타이레놀');
              } else {
                field.onSubmitted!('타이레놀');
              }
            }
            final record = await probe.completed.future.timeout(
              const Duration(seconds: 25),
            );
            if (mode.startsWith('local_') && probe.requests != 0)
              throw StateError('Expected local cache hit');
            if (mode == 'baseline' && probe.edge != 'BYPASS')
              throw StateError('Expected original API path');
            if (mode == 'edge' && probe.edge != 'HIT')
              throw StateError('Expected warm edge cache');
            if (round >= 0) {
              records.add(record);
              print('PN_BENCH_SAMPLE ${jsonEncode(record)}');
            }
            active = null;
            wire.probe = null;
            if (scenario == 'detail_open') {
              nav.currentState!.pop();
              await Future<void>.delayed(const Duration(milliseconds: 450));
            }
          }
        }
      }
      await prefs.clear();
      print('PN_BENCH_DONE ${records.length}');
      setState(() {
        page = Scaffold(
          body: Center(child: Text('Completed ${records.length} measurements')),
        );
      });
    } catch (error, stack) {
      print('PN_BENCH_ERROR $error\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: nav,
    debugShowCheckedModeBanner: false,
    // The application theme is copied verbatim from lib/main.dart below.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    home: page,
  );
}
