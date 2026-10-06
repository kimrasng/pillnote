import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Distanc extends StatefulWidget {
  const Distanc({super.key});
  @override
  State<Distanc> createState() => _DistancState();
}

class _DistancState extends State<Distanc> {
  final _map = MapController();
  List<Map<String, dynamic>> _pharmacies = [];
  LatLng? _searchCenter;
  bool _loading = false, _locating = false, _mapReady = false;
  bool _hasMoved = false;
  String _locationText = '서울 시청 중심 지도 · 현재 위치가 아니에요';
  String? _error;
  int _request = 0;
  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _location() async {
    if (_locating) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가까운 약국을 찾아요'),
        content: const Text(
          '현재 위치를 사용하면 주변 약국을 찾을 수 있어요. 허용하지 않아도 지도를 움직여 검색할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('지도에서 찾기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('현재 위치 사용'),
          ),
        ],
      ),
    );
    if (allow != true || !mounted) return;
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('위치 서비스가 꺼져 있어요. 지도를 움직여 검색하거나 기기 설정에서 위치를 켜세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          '위치 권한이 없어요. 지도를 움직여 검색하거나 기기 설정에서 PillNote의 위치 권한을 허용하세요.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final center = LatLng(position.latitude, position.longitude);
      if (_mapReady) _map.move(center, 14);
      setState(() {
        _locationText = '현재 위치 주변';
        _hasMoved = false;
      });
      await _search(center);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : '현재 위치를 확인하지 못했어요. 지도를 움직여 원하는 지역을 검색하세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search(LatLng center) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ApiClient.instance.searchPharmacies(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted || request != _request) return;
      results.sort(
        (a, b) => _distance(a, center).compareTo(_distance(b, center)),
      );
      setState(() {
        _pharmacies = results;
        _searchCenter = center;
        _hasMoved = false;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : '약국 정보를 불러오지 못했어요. 다시 검색하세요.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  double _distance(Map<String, dynamic> pharmacy, LatLng center) {
    final lat = pharmacy['latitude'] as num?;
    final lng = pharmacy['longitude'] as num?;
    if (lat == null || lng == null) return double.infinity;
    return const Distance().as(
      LengthUnit.Meter,
      center,
      LatLng(lat.toDouble(), lng.toDouble()),
    );
  }

  void _details(List<Map<String, dynamic>> pharmacies) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .4,
        minChildSize: .25,
        maxChildSize: .8,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            const SectionLabel('약국 정보'),
            ...pharmacies.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p['name'] ?? '약국'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('${p['address'] ?? '주소 정보 없음'}'),
                    const SizedBox(height: 8),
                    SelectableText('${p['phone'] ?? '전화번호 정보 없음'}'),
                    const SizedBox(height: 12),
                    const Text(
                      '방문 전 전화로 영업 여부를 확인하세요.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _markers() {
    final clusters = <List<Map<String, dynamic>>>[];
    for (final p in _pharmacies) {
      if (p['latitude'] is! num || p['longitude'] is! num) continue;
      final lat = (p['latitude'] as num).toDouble(),
          lng = (p['longitude'] as num).toDouble();
      final cluster = clusters
          .where(
            (c) =>
                ((c.first['latitude'] as num).toDouble() - lat).abs() +
                    ((c.first['longitude'] as num).toDouble() - lng).abs() <
                .0015,
          )
          .firstOrNull;
      if (cluster == null) {
        clusters.add([p]);
      } else {
        cluster.add(p);
      }
    }
    return clusters
        .map(
          (cluster) => Marker(
            point: LatLng(
              (cluster.first['latitude'] as num).toDouble(),
              (cluster.first['longitude'] as num).toDouble(),
            ),
            width: 44,
            height: 44,
            child: Semantics(
              label: cluster.length > 1
                  ? '약국 ${cluster.length}곳'
                  : '${cluster.first['name']}',
              button: true,
              child: GestureDetector(
                onTap: () => _details(cluster),
                child: Container(
                  decoration: BoxDecoration(
                    color: blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: cluster.length > 1
                        ? Text(
                            '${cluster.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : const Icon(
                            Icons.local_pharmacy_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: PageScrollView(
      title: '주변 약국',
      subtitle: '지도에서 찾고, 방문 전에 확인해요.',
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _locationText,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _locating ? null : _location,
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: const Text('현재 위치', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: const LatLng(37.5665, 126.9780),
                          initialZoom: 14,
                          onMapReady: () => _mapReady = true,
                          onPositionChanged: (_, gesture) {
                            if (gesture) {
                              setState(() {
                                _hasMoved = true;
                                _locationText = '지도에서 선택한 지역';
                              });
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'kr.kimrasng.pillnote.pillnote',
                          ),
                          MarkerLayer(markers: _markers()),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Center(
                          child: FilledButton.tonalIcon(
                            onPressed: _loading
                                ? null
                                : () {
                                    if (_mapReady) {
                                      setState(
                                        () => _locationText = '선택한 지도 지역 주변',
                                      );
                                      _search(_map.camera.center);
                                    }
                                  },
                            icon: const Icon(Icons.search, size: 18),
                            label: Text(
                              _loading
                                  ? '검색 중…'
                                  : _hasMoved
                                  ? '이 지역 다시 검색'
                                  : '이 지역 약국 찾기',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionLabel(
                '가까운 약국',
                trailing: Text(
                  '${_pharmacies.length}곳',
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: muted, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          if (_mapReady) _search(_map.camera.center);
                        },
                        child: const Text('지도 지역으로 다시 검색'),
                      ),
                    ],
                  ),
                )
              else if (_pharmacies.isEmpty)
                SoftPanel(
                  child: Text(
                    _searchCenter == null
                        ? '현재 위치를 사용하거나 지도를 움직인 뒤 “이 지역 약국 찾기”를 눌러 주세요.'
                        : '이 지역에서 검색된 약국이 없어요. 다른 지역으로 지도를 움직여 보세요.',
                    style: const TextStyle(color: muted, height: 1.6),
                  ),
                )
              else
                ..._pharmacies.map((p) {
                  final distance = _searchCenter == null
                      ? double.infinity
                      : _distance(p, _searchCenter!);
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        title: Text(
                          '${p['name'] ?? '약국'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${p['address'] ?? '주소 정보 없음'}\n${distance.isFinite
                              ? distance < 1000
                                    ? '${distance.round()}m · '
                                    : '${(distance / 1000).toStringAsFixed(1)}km · '
                              : ''}검색 중심에서의 직선 거리',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _details([p]),
                      ),
                      const Divider(),
                    ],
                  );
                }),
            ],
          ),
        ),
      ],
    ),
  );
}
