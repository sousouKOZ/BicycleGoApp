import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/parking_providers.dart';
import 'parking_detail_sheet.dart';

class ParkingMapPage extends ConsumerStatefulWidget {
  const ParkingMapPage({super.key});

  static const _initialCamera = CameraPosition(
    target: LatLng(34.7025, 135.4959), // 大阪駅付近
    zoom: 14.5,
  );

  @override
  ConsumerState<ParkingMapPage> createState() => _ParkingMapPageState();
}

class _ParkingMapPageState extends ConsumerState<ParkingMapPage> {
  late final TextEditingController _searchController;
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  BitmapDescriptor? _currentLocationIcon;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(parkingSearchQueryProvider),
    );
    _searchController.addListener(() {
      final value = _searchController.text;
      if (ref.read(parkingSearchQueryProvider) != value) {
        ref.read(parkingSearchQueryProvider.notifier).state = value;
      }
    });
    _loadCurrentLocationIcon();
    _fetchCurrentLocation();
  }

  Future<void> _loadCurrentLocationIcon() async {
    final icon = await _createBikeMarker();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentLocationIcon = icon;
    });
  }

  Future<BitmapDescriptor> _createBikeMarker() async {
    const iconSize = 52.0;
    const padding = 14.0;
    final imageSize = (iconSize + padding * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(imageSize / 2, imageSize / 2);

    final background = Paint()..color = Colors.blue;
    canvas.drawCircle(center, imageSize / 2.0, background);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_bike.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.directions_bike.fontFamily,
          package: Icons.directions_bike.fontPackage,
          color: Colors.white,
        ),
      ),
    )..layout();

    final iconOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(imageSize, imageSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationDialog(
          title: '位置情報がオフです',
          message: '端末の位置情報サービスをオンにしてください。',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationDialog(
          title: '位置情報の権限が必要です',
          message: '設定から位置情報の許可を有効にしてください。',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
      });
      ref.read(currentLocationProvider.notifier).state = location;

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(location, 16),
        );
      }
    } catch (_) {}
  }

  void _showLocationDialog({
    required String title,
    required String message,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncLots = ref.watch(parkingLotsProvider);
    final query = ref.watch(parkingSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.directions_bike),
            SizedBox(width: 8),
            Text('Bicycle Go'),
          ],
        ),
      ),
      body: asyncLots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込み失敗: $e')),
        data: (lots) {
          final normalizedQuery = query.trim().toLowerCase();
          final visibleLots = normalizedQuery.isEmpty
              ? lots
              : lots
                  .where(
                    (p) => p.name.toLowerCase().contains(normalizedQuery),
                  )
                  .toList();
          final markers = visibleLots.map((p) {
            final usageRate = p.usageRatePercent;
            final markerHue = usageRate >= 85
                ? BitmapDescriptor.hueRed
                : usageRate >= 60
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueGreen;
            return Marker(
              markerId: MarkerId(p.id),
              position: p.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
              onTap: () {
                ref.read(selectedParkingProvider.notifier).state = p;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => ParkingDetailSheet(parking: p),
                );
              },
              infoWindow: InfoWindow(
                title: p.name,
                snippet: '空き ${p.available}/${p.capacity}（稼働${p.usageRatePercent}%）',
              ),
            );
          }).toSet();
          if (_currentLocation != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('current_location'),
                position: _currentLocation!,
                infoWindow: const InfoWindow(title: '現在地'),
                icon: _currentLocationIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                zIndex: 2,
              ),
            );
          }

          final circles = _currentLocation == null
              ? <Circle>{}
              : {
                  Circle(
                    circleId: const CircleId('current_location_accuracy'),
                    center: _currentLocation!,
                    radius: 25,
                    fillColor: Colors.blue.withOpacity(0.18),
                    strokeColor: Colors.blue.withOpacity(0.7),
                    strokeWidth: 2,
                    zIndex: 1,
                  ),
                };

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: ParkingMapPage._initialCamera,
                markers: markers,
                circles: circles,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '駐輪場を検索',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
