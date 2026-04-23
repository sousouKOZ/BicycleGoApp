import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
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
  BitmapDescriptor? _couponIcon;
  bool _showCouponStrip = true;

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
    _loadCustomMarkerIcons();
    _fetchCurrentLocation();
  }

  Future<void> _loadCustomMarkerIcons() async {
    final bikeIcon = await _createCircleIconMarker(
      icon: Icons.directions_bike,
      backgroundColor: Colors.blue,
    );
    final couponIcon = await _createCouponMarker();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentLocationIcon = bikeIcon;
      _couponIcon = couponIcon;
    });
  }

  Future<BitmapDescriptor> _createCircleIconMarker({
    required IconData icon,
    required Color backgroundColor,
    Color iconColor = Colors.white,
  }) async {
    const iconSize = 52.0;
    const padding = 14.0;
    final imageSize = (iconSize + padding * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(imageSize / 2, imageSize / 2);

    final background = Paint()..color = backgroundColor;
    canvas.drawCircle(center, imageSize / 2.0, background);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
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

  Future<BitmapDescriptor> _createCouponMarker() async {
    const iconSize = 56.0;
    const padding = 16.0;
    final imageSize = (iconSize + padding * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = imageSize.toDouble();
    final height = imageSize.toDouble();

    final tagPath = Path();
    final bodyRect = Rect.fromLTWH(padding, padding * 0.6,
        width - padding * 1.8, height - padding * 1.2);
    const radius = Radius.circular(14);
    tagPath.addRRect(RRect.fromRectAndCorners(
      bodyRect,
      topLeft: radius,
      topRight: const Radius.circular(6),
      bottomLeft: radius,
      bottomRight: const Radius.circular(6),
    ));

    final tipStartY = bodyRect.top + bodyRect.height * 0.25;
    final tipEndY = bodyRect.bottom - bodyRect.height * 0.25;
    final tipPoint = Offset(width - padding * 0.2, height / 2);
    final tipPath = Path()
      ..moveTo(bodyRect.right, tipStartY)
      ..lineTo(tipPoint.dx, tipPoint.dy)
      ..lineTo(bodyRect.right, tipEndY)
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(tagPath.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(tipPath.shift(const Offset(0, 2)), shadowPaint);

    final tagPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawPath(tagPath, tagPaint);
    canvas.drawPath(tipPath, tagPaint);

    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(bodyRect.left + 10, bodyRect.center.dy),
      4,
      holePaint,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.local_offer.codePoint),
        style: TextStyle(
          fontSize: 28,
          fontFamily: Icons.local_offer.fontFamily,
          package: Icons.local_offer.fontPackage,
          color: Colors.white,
        ),
      ),
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        bodyRect.center.dx - textPainter.width / 2 + 4,
        bodyRect.center.dy - textPainter.height / 2,
      ),
    );

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
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: AppColors.background,
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
              icon: _couponIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRose,
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: GlassDecoration.pill(),
                              child: Icon(Icons.directions_bike,
                                  size: 18, color: AppColors.accent),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Bicycle Go',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.onSurfacePrimary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: GlassDecoration.light(radius: 16),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '駐輪場を検索',
                            prefixIcon: Icon(Icons.search,
                                color: AppColors.onSurfaceSecondary),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        color: AppColors.onSurfaceSecondary),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (stores.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: _showCouponStrip
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 6),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _CouponStripToggle(
                                  icon: Icons.close,
                                  label: '配信中クーポンを隠す',
                                  onTap: () => setState(
                                    () => _showCouponStrip = false,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 112,
                              child: _CouponPreviewStrip(stores: stores),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _CouponStripToggle(
                              icon: Icons.local_offer,
                              label: '配信中クーポンを表示',
                              onTap: () => setState(
                                () => _showCouponStrip = true,
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

class _CouponStripToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CouponStripToggle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: GlassDecoration.pill(),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.accent.withValues(alpha: 0.08),
          highlightColor: AppColors.accent.withValues(alpha: 0.04),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        return DecoratedBox(
          decoration: GlassDecoration.accentCard(radius: 20),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => StorePreviewSheet(store: s),
              ),
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            s.category.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.local_offer,
                              size: 14, color: AppColors.accent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurfacePrimary,
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
            ),
          ),
        );
      },
    );
  }
}
