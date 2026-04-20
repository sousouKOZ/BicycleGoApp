import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../stores/domain/store.dart';
import '../../stores/presentation/store_preview_sheet.dart';
import '../../stores/providers/store_providers.dart';
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
    final asyncStores = ref.watch(storesProvider);
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
          final stores = asyncStores.asData?.value ?? const <Store>[];

          final markers = <Marker>{};
          for (final p in visibleLots) {
            final usageRate = p.usageRatePercent;
            final markerHue = usageRate >= 85
                ? BitmapDescriptor.hueRed
                : usageRate >= 60
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueGreen;
            markers.add(Marker(
              markerId: MarkerId('lot-${p.id}'),
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
                snippet:
                    '空き ${p.available}/${p.capacity}（稼働${p.usageRatePercent}%）',
              ),
            ));
          }
          for (final s in stores) {
            markers.add(Marker(
              markerId: MarkerId('store-${s.id}'),
              position: s.position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => StorePreviewSheet(store: s),
                );
              },
              infoWindow: InfoWindow(
                title: s.name,
                snippet: '🎁 ${s.benefit}',
              ),
            ));
          }

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
              if (stores.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: SizedBox(
                    height: 112,
                    child: _CouponPreviewStrip(stores: stores),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CouponPreviewStrip extends StatelessWidget {
  final List<Store> stores;
  const _CouponPreviewStrip({required this.stores});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: stores.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final s = stores[i];
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => StorePreviewSheet(store: s),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.primary.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.category.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('🎁',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  s.benefit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
