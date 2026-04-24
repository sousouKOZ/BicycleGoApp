import 'dart:math' as math;
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
import '../domain/directions_route.dart';
import '../domain/parking_lot.dart';
import '../providers/favorite_providers.dart';
import '../providers/map_filter_providers.dart';
import '../providers/parking_providers.dart';
import '../providers/recommendation_providers.dart';
import '../providers/route_providers.dart';
import '../providers/sort_mode_providers.dart';
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
  late final FocusNode _searchFocus;
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
    _searchFocus = FocusNode();
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _loadCustomMarkerIcons();
    _fetchCurrentLocation();
  }

  Future<void> _focusParking(ParkingLot p) async {
    _searchFocus.unfocus();
    _searchController.clear();
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(p.position, 17),
    );
    if (!mounted) return;
    ref.read(selectedParkingProvider.notifier).state = p;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ParkingDetailSheet(parking: p),
    );
  }

  Future<void> _animateToRoute(DirectionsRoute route) async {
    final controller = _mapController;
    if (controller == null || route.polyline.isEmpty) return;
    double minLat = route.polyline.first.latitude;
    double maxLat = route.polyline.first.latitude;
    double minLng = route.polyline.first.longitude;
    double maxLng = route.polyline.first.longitude;
    for (final p in route.polyline) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 72),
    );
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
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncLots = ref.watch(parkingLotsProvider);
    final asyncStores = ref.watch(storesProvider);
    final query = ref.watch(parkingSearchQueryProvider);
    final activeRoute = ref.watch(activeRouteProvider);

    ref.listen<DirectionsRoute?>(activeRouteProvider, (prev, next) {
      if (next != null && next != prev) {
        _animateToRoute(next);
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: asyncLots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('読み込み失敗: $e')),
        data: (lots) {
          final normalizedQuery = query.trim().toLowerCase();
          final stores = asyncStores.asData?.value ?? const <Store>[];
          final filter = ref.watch(mapFilterProvider);
          final favorites = ref.watch(favoriteParkingsProvider);

          Iterable<ParkingLot> filtered = normalizedQuery.isEmpty
              ? lots
              : lots.where(
                  (p) => p.name.toLowerCase().contains(normalizedQuery),
                );
          if (filter.availableOnly) {
            filtered = filtered.where((p) => p.available > 0);
          }
          if (filter.favoriteOnly) {
            filtered = filtered.where((p) => favorites.contains(p.id));
          }
          if (filter.couponOnly) {
            filtered = filtered.where((p) {
              for (final s in stores) {
                if (_haversineMeters(p.position, s.position) <= 300) {
                  return true;
                }
              }
              return false;
            });
          }
          final visibleLots = filtered.toList();

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

          final polylines = <Polyline>{};
          if (activeRoute != null && activeRoute.polyline.isNotEmpty) {
            polylines.add(Polyline(
              polylineId: PolylineId('route-${activeRoute.parkingLotId}'),
              points: activeRoute.polyline,
              color: AppColors.accent,
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ));
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: ParkingMapPage._initialCamera,
                markers: markers,
                circles: circles,
                polylines: polylines,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                  final initialRoute = ref.read(activeRouteProvider);
                  if (initialRoute != null) {
                    _animateToRoute(initialRoute);
                  }
                },
                onTap: (_) => _searchFocus.unfocus(),
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
                              decoration: GlassDecoration.pill(context),
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
                                    color: context.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: GlassDecoration.light(context, radius: 16),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '駐輪場を検索',
                            prefixIcon: Icon(Icons.search,
                                color: context.textSecondary),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        color: context.textSecondary),
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
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: _MapFilterBar(),
                      ),
                      if (_searchFocus.hasFocus ||
                          normalizedQuery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _SearchResultsDropdown(
                            query: normalizedQuery,
                            allLots: lots,
                            filteredLots: visibleLots,
                            currentLocation: _currentLocation,
                            onTap: _focusParking,
                          ),
                        ),
                      if (activeRoute != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _RouteBanner(
                            route: activeRoute,
                            onClose: () {
                              ref
                                  .read(activeRouteProvider.notifier)
                                  .state = null;
                            },
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
      decoration: GlassDecoration.pill(context),
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
          decoration: GlassDecoration.accentCard(context, radius: 20),
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
                        color: context.textPrimary,
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

class _SearchResultsDropdown extends ConsumerWidget {
  final String query;
  final List<ParkingLot> allLots;
  final List<ParkingLot> filteredLots;
  final LatLng? currentLocation;
  final ValueChanged<ParkingLot> onTap;

  const _SearchResultsDropdown({
    required this.query,
    required this.allLots,
    required this.filteredLots,
    required this.currentLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stores = ref.watch(storesProvider).asData?.value ?? const <Store>[];
    final sortMode = ref.watch(parkingSortModeProvider);

    final source = query.isEmpty ? allLots : filteredLots;
    final recommendations = <String, ParkingRecommendation>{
      for (final p in source)
        p.id: computeRecommendation(
          parking: p,
          stores: stores,
          userLocation: currentLocation,
        ),
    };
    final sorted = [...source];
    if (sortMode == ParkingSortMode.recommend) {
      sorted.sort((a, b) =>
          recommendations[b.id]!.score.compareTo(recommendations[a.id]!.score));
    } else if (currentLocation != null) {
      sorted.sort((a, b) => _haversineMeters(currentLocation!, a.position)
          .compareTo(_haversineMeters(currentLocation!, b.position)));
    }

    if (sorted.isEmpty) {
      return Container(
        decoration: GlassDecoration.light(context, radius: 16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded,
                size: 18, color: context.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '「$query」に該当する駐輪場はありません',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: GlassDecoration.light(context, radius: 16),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxHeight: 360),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SortToggleRow(
              mode: sortMode,
              onChanged: (m) =>
                  ref.read(parkingSortModeProvider.notifier).state = m,
            ),
            Divider(
              height: 1,
              color: context.subtleBorder,
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sorted.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: context.subtleBorder,
                  indent: 62,
                ),
                itemBuilder: (_, i) {
                  final p = sorted[i];
                  final rec = recommendations[p.id]!;
                  final usage = p.usageRatePercent;
                  final usageColor = usage >= 85
                      ? AppColors.danger
                      : usage >= 60
                          ? AppColors.warning
                          : AppColors.success;
                  final distance = currentLocation == null
                      ? null
                      : _haversineMeters(currentLocation!, p.position);
                  final distanceLabel = distance == null
                      ? null
                      : distance >= 1000
                          ? '${(distance / 1000).toStringAsFixed(1)}km'
                          : '${distance.round()}m';
                  return InkWell(
                    onTap: () => onTap(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: usageColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.local_parking_rounded,
                                size: 20, color: usageColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (rec.isRecommended) ...[
                                      const SizedBox(width: 6),
                                      _RecommendBadge(
                                        bonusPercent: rec.bonusPointsPercent,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '空き${p.available}/${p.capacity}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: usageColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      ' ・ 稼働${p.usageRatePercent}%'
                                      '${distanceLabel != null ? ' ・ $distanceLabel' : ''}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.north_east_rounded,
                              size: 16, color: context.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortToggleRow extends StatelessWidget {
  final ParkingSortMode mode;
  final ValueChanged<ParkingSortMode> onChanged;
  const _SortToggleRow({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Icon(Icons.sort_rounded,
              size: 16, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            '並び替え',
            style: theme.textTheme.labelMedium,
          ),
          const Spacer(),
          _SortToggleButton(
            label: '距離順',
            selected: mode == ParkingSortMode.distance,
            onTap: () => onChanged(ParkingSortMode.distance),
          ),
          const SizedBox(width: 6),
          _SortToggleButton(
            label: 'おすすめ順',
            selected: mode == ParkingSortMode.recommend,
            onTap: () => onChanged(ParkingSortMode.recommend),
          ),
        ],
      ),
    );
  }
}

class _SortToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.accent : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.transparent : context.subtleBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected ? Colors.white : context.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendBadge extends StatelessWidget {
  final int bonusPercent;
  const _RecommendBadge({required this.bonusPercent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accentAlt],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            bonusPercent > 0 ? 'おすすめ +$bonusPercent%' : 'おすすめ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

double _haversineMeters(LatLng a, LatLng b) {
  const earth = 6371000.0;
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(b.latitude - a.latitude);
  final dLng = toRad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(a.latitude)) *
          math.cos(toRad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return earth * 2 * math.asin(math.sqrt(h.toDouble()));
}

class _MapFilterBar extends ConsumerWidget {
  const _MapFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(mapFilterProvider);
    final notifier = ref.read(mapFilterProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipItem(
            icon: Icons.event_available_rounded,
            label: '空きのみ',
            selected: filter.availableOnly,
            onTap: () => notifier.state =
                filter.copyWith(availableOnly: !filter.availableOnly),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            icon: Icons.local_offer_rounded,
            label: 'クーポンあり',
            selected: filter.couponOnly,
            onTap: () => notifier.state =
                filter.copyWith(couponOnly: !filter.couponOnly),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            icon: Icons.star_rounded,
            label: 'お気に入り',
            selected: filter.favoriteOnly,
            onTap: () => notifier.state =
                filter.copyWith(favoriteOnly: !filter.favoriteOnly),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChipItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: selected
          ? BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : GlassDecoration.pill(context),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.accent.withValues(alpha: 0.1),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : context.textPrimary,
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

class _RouteBanner extends StatelessWidget {
  final DirectionsRoute route;
  final VoidCallback onClose;
  const _RouteBanner({required this.route, required this.onClose});

  String get _distanceLabel {
    final m = route.distanceMeters;
    if (m >= 1000) {
      return '${(m / 1000).toStringAsFixed(1)}km';
    }
    return '${m}m';
  }

  String get _durationLabel {
    final minutes = (route.durationSeconds / 60).round();
    if (minutes < 60) return '約$minutes分';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '約$h時間' : '約$h時間$m分';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: GlassDecoration.light(context, radius: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_bike_rounded,
                size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.parkingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.route_rounded,
                        size: 14, color: context.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _distanceLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.schedule_rounded,
                        size: 14, color: context.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _durationLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ルートを消す',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded,
                size: 18, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}
