import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pillnote/services/api_client.dart';

class Distanc extends StatefulWidget {
  const Distanc({super.key});

  @override
  State<Distanc> createState() => _DistancState();
}

class _DistancState extends State<Distanc> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Map<String, dynamic>> _allPharmacies = [];
  double _lastClusteredZoom = 0;
  bool _isLoading = false;
  Timer? _debounceTimer;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')));
      }
      _fetchPharmacies(37.5665, 126.9780);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        }
        _fetchPharmacies(37.5665, 126.9780);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다.')));
      }
      _fetchPharmacies(37.5665, 126.9780);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          14.0,
        );
        _fetchPharmacies(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        _fetchPharmacies(37.5665, 126.9780);
      }
    }
  }

  Future<void> _fetchPharmacies(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _allPharmacies = await ApiClient.instance.searchPharmacies(
        latitude: lat,
        longitude: lng,
      );
      _updateMarkers(_mapController.camera.zoom, force: true);
    } on ApiException catch (error) {
      debugPrint('Pharmacy API error: ${error.code}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      debugPrint('Pharmacy search error: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('약국 정보를 불러오지 못했습니다.')));
      }
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
    final List<List<Map<String, dynamic>>> clusters = [];

    for (var pharmacy in _allPharmacies) {
      final double lat = (pharmacy['latitude'] as num?)?.toDouble() ?? 0;
      final double lng = (pharmacy['longitude'] as num?)?.toDouble() ?? 0;

      if (lat == 0 || lng == 0) continue;

      bool addedToCluster = false;
      for (var cluster in clusters) {
        final first = cluster.first;
        final double cLat = (first['latitude'] as num).toDouble();
        final double cLng = (first['longitude'] as num).toDouble();

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
      final pLat = (first['latitude'] as num).toDouble();
      final pLng = (first['longitude'] as num).toDouble();

      final bool isSingle = pharmacyList.length == 1;
      final bool showName = isSingle && zoom > 16.5;

      return Marker(
        point: LatLng(pLat, pLng),
        width: showName ? 140 : 50,
        height: showName ? 80 : 50,
        alignment: .bottomCenter,
        child: GestureDetector(
          onTap: () => _showPharmacyInfoList(pharmacyList),
          child: Column(
            mainAxisSize: .min,
            mainAxisAlignment: .end,
            children: [
              if (showName)
                Container(
                  margin: .only(bottom: 2),
                  padding: .symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: .circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    first['name'] ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: .bold,
                      color: Colors.black87,
                    ),
                    overflow: .ellipsis,
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
                        padding: .all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 2),
                          ],
                        ),
                        constraints: BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            '${pharmacyList.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: .bold,
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

    if (!mounted) return;
    setState(() {
      _markers = newMarkers;
    });
  }

  void _showPharmacyInfoList(List<Map<String, dynamic>> items) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: screenHeight * 0.35,
          margin: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: PageView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.all(screenWidth * 0.06),
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] ?? '정보 없음',
                            style: TextStyle(
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (items.length > 1)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.02,
                              vertical: screenHeight * 0.005,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.03,
                              ),
                            ),
                            child: Text(
                              '${index + 1} / ${items.length}',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: screenWidth * 0.045,
                          color: Colors.grey,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Expanded(
                          child: Text(
                            item['address'] ?? '주소 정보 없음',
                            style: TextStyle(fontSize: screenWidth * 0.035),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: screenWidth * 0.045,
                          color: Colors.grey,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          item['phone'] ?? '전화번호 정보 없음',
                          style: TextStyle(fontSize: screenWidth * 0.035),
                        ),
                      ],
                    ),
                    Spacer(),
                    if (items.length > 1)
                      Center(
                        child: Text(
                          '← 좌우로 스와이프하여 다음 약국 보기 →',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.03,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '주변 약국 확인',
          style: TextStyle(
            color: Colors.black,
            fontSize: screenWidth * 0.045,
            fontWeight: .bold,
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
                initialCenter: LatLng(37.5665, 126.9780),
                initialZoom: 14.0,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) {
                    _updateMarkers(camera.zoom);
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(Duration(milliseconds: 600), () {
                      _fetchPharmacies(
                        camera.center.latitude,
                        camera.center.longitude,
                      );
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
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (_isLoading)
              Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: .circular(12)),
                  child: Padding(
                    padding: .all(screenWidth * 0.04),
                    child: CircularProgressIndicator(),
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
          child: Icon(
            Icons.my_location,
            color: Colors.black,
            size: screenWidth * 0.05,
          ),
          onPressed: () => _initializeLocation(),
        ),
      ),
    );
  }
}
