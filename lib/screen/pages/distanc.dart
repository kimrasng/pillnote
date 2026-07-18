import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class Distanc extends StatefulWidget {
  const Distanc({super.key});

  @override
  State<Distanc> createState() => _DistancState();
}

class _DistancState extends State<Distanc> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<dynamic> _allPharmacies = [];
  double _lastClusteredZoom = 0;
  bool _isLoading = false;
  Timer? _debounceTimer;

  final String _apiKey = dotenv.get('API_KEY');

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')),
        );
      }
      _fetchPharmacies(37.5665, 126.9780);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
          );
        }
        _fetchPharmacies(37.5665, 126.9780);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다.')),
        );
      }
      _fetchPharmacies(37.5665, 126.9780);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        _mapController.move(LatLng(position.latitude, position.longitude), 14.0);
        _fetchPharmacies(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      _fetchPharmacies(37.5665, 126.9780);
    }
  }

  Future<void> _fetchPharmacies(double lat, double lng) async {
    if (_apiKey.isEmpty) {
      debugPrint('API_KEY가 설정되지 않았습니다.');
      return;
    }

    setState(() => _isLoading = true);

    final String urlString = 'https://apis.data.go.kr/B551182/pharmacyInfoService/getParmacyBasisList'
        '?serviceKey=$_apiKey'
        '&_type=json'
        '&xPos=$lng'
        '&yPos=$lat'
        '&radius=3000'
        '&numOfRows=100';

    try {
      final url = Uri.parse(urlString);
      final response = await http.get(url);
      final decodedBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        if (decodedBody.trim().startsWith('<')) {
          if (decodedBody.contains('SERVICE_KEY_IS_NOT_REGISTERED')) {
            throw Exception('SERVICE_KEY_IS_NOT_REGISTERED_ERROR');
          }
          throw const FormatException('API 응답 오류');
        }

        final data = json.decode(decodedBody);
        final body = data['response']?['body'];
        if (body == null || body['items'] == null || body['items'] == "") {
           _allPharmacies = [];
           _updateMarkers(_mapController.camera.zoom, force: true);
           return;
        }

        final itemList = body['items']['item'];
        List<dynamic> list = [];
        if (itemList is List) {
          list = itemList;
        } else if (itemList is Map) {
          list = [itemList];
        }

        _allPharmacies = list;
        _updateMarkers(_mapController.camera.zoom, force: true);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _getClusterThreshold(double zoom) {
    if (zoom <= 11) return 0.05;
    if (zoom <= 12) return 0.025;
    if (zoom <= 13) return 0.012;
    if (zoom <= 14) return 0.006;
    if (zoom <= 15) return 0.003;
    if (zoom <= 16) return 0.0015;
    if (zoom <= 17) return 0.0007;
    return 0.0002;
  }

  void _updateMarkers(double zoom, {bool force = false}) {
    if (_allPharmacies.isEmpty) {
      setState(() => _markers = []);
      return;
    }
    
    if (!force && (zoom - _lastClusteredZoom).abs() < 0.1) return;
    _lastClusteredZoom = zoom;

    final double threshold = _getClusterThreshold(zoom);
    final List<List<dynamic>> clusters = [];

    for (var pharmacy in _allPharmacies) {
      final double lat = double.tryParse((pharmacy['YPos'] ?? pharmacy['yPos'] ?? '0').toString()) ?? 0;
      final double lng = double.tryParse((pharmacy['XPos'] ?? pharmacy['xPos'] ?? '0').toString()) ?? 0;
      
      if (lat == 0 || lng == 0) continue;

      bool addedToCluster = false;
      for (var cluster in clusters) {
        final first = cluster.first;
        final double cLat = double.parse((first['YPos'] ?? first['yPos'] ?? '0').toString());
        final double cLng = double.parse((first['XPos'] ?? first['xPos'] ?? '0').toString());
        
        if ((lat - cLat).abs() + (lng - cLng).abs() < threshold) {
          cluster.add(pharmacy);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        clusters.add([pharmacy]);
      }
    }

    final List<Marker> newMarkers = clusters.map((pharmacyList) {
      final first = pharmacyList.first;
      final pLat = double.parse((first['YPos'] ?? first['yPos'] ?? '0').toString());
      final pLng = double.parse((first['XPos'] ?? first['xPos'] ?? '0').toString());

      final bool isSingle = pharmacyList.length == 1;
      final bool showName = isSingle && zoom > 16.5;

      return Marker(
        point: LatLng(pLat, pLng),
        width: showName ? 140 : 50,
        height: showName ? 80 : 50,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => _showPharmacyInfoList(pharmacyList),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showName)
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    first['yadmNm'] ?? '',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.location_on,
                    color: isSingle ? Colors.red : Colors.blueAccent,
                    size: isSingle ? 38 : 45,
                  ),
                  if (!isSingle)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Center(
                          child: Text(
                            '${pharmacyList.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();

    setState(() {
      _markers = newMarkers;
    });
  }

  void _showPharmacyInfoList(List<dynamic> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 250,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 5)],
          ),
          child: PageView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['yadmNm'] ?? '정보 없음',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (items.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${index + 1} / ${items.length}', 
                              style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item['addr'] ?? '주소 정보 없음', maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(item['telno'] ?? '전화번호 정보 없음'),
                      ],
                    ),
                    const Spacer(),
                    if (items.length > 1)
                      const Center(
                        child: Text('← 좌우로 스와이프하여 다음 약국 보기 →', 
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '주변 약국 확인',
          style: TextStyle(
            color: Colors.black,
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(37.5665, 126.9780),
                initialZoom: 14.0,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) {
                    _updateMarkers(camera.zoom);
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                      _fetchPharmacies(camera.center.latitude, camera.center.longitude);
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: NetworkTileProvider(
                    headers: {'User-Agent': 'kr.kimrasng.pillnote.pillnote'},
                  ),
                ),
                MarkerLayer(markers: _markers),
                RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
              ],
            ),
            if (_isLoading)
              Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: screenWidth * 0.12,
        height: screenWidth * 0.12,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          elevation: 4,
          child: Icon(Icons.my_location, color: Colors.black, size: screenWidth * 0.05),
          onPressed: () => _initializeLocation(),
        ),
      ),
    );
  }
}
