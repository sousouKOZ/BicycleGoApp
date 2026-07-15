import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/parking_lot.dart';
import '../../../core/domain/store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../navigation/presentation/navigation_page.dart';
import '../../stores/presentation/store_preview_sheet.dart';
import '../../stores/providers/store_providers.dart';
import '../domain/directions_route.dart';
import '../domain/parking_lot_filter.dart';
import '../providers/favorite_providers.dart';
import '../providers/location_permission_providers.dart';
import '../providers/map_filter_providers.dart';
import '../providers/parking_providers.dart';
import '../providers/route_providers.dart';
import 'parking_detail_sheet.dart';
import 'widgets/coupon_strip.dart';
import 'widgets/location_gate_overlay.dart';
import 'widgets/location_permission_banner.dart';
import 'widgets/map_controls.dart';
import 'widgets/map_filter_bar.dart';
import 'widgets/map_insight_card.dart';
import 'widgets/map_marker_icons.dart';
import 'widgets/route_banner.dart';
import 'widgets/search_results_dropdown.dart';

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
    await showAppBottomSheet<void>(
      context,
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
    final bikeIcon = await createCircleIconMarker(
      icon: Icons.directions_bike,
      backgroundColor: AppColors.navigation,
    );
    final couponIcon = await createCouponMarker();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentLocationIcon = bikeIcon;
      _couponIcon = couponIcon;
    });
  }

  Future<void> _fetchCurrentLocation({bool requestIfDenied = true}) async {
    try {
      final notifier = ref.read(locationPermissionProvider.notifier);
      final status =
          requestIfDenied ? await notifier.request() : await notifier.refresh();
      if (status != LocationGateStatus.granted) {
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncLots = ref.watch(parkingLotsProvider);

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
          return Stack(
            children: [
              _MapCanvas(
                lots: lots,
                currentLocation: _currentLocation,
                currentLocationIcon: _currentLocationIcon,
                couponIcon: _couponIcon,
                onMapCreated: (controller) {
                  _mapController = controller;
                  final initialRoute = ref.read(activeRouteProvider);
                  if (initialRoute != null) {
                    _animateToRoute(initialRoute);
                  }
                },
                onMapTap: () => _searchFocus.unfocus(),
              ),
              Positioned.fill(
                child: _MapOverlay(
                  lots: lots,
                  searchController: _searchController,
                  searchFocus: _searchFocus,
                  currentLocation: _currentLocation,
                  onParkingSelected: _focusParking,
                  onRecenter: () => _fetchCurrentLocation(),
                  onLocationGranted: () => _fetchCurrentLocation(
                    requestIfDenied: false,
                  ),
                ),
              ),
              LocationGateOverlay(
                onGranted: () => _fetchCurrentLocation(
                  requestIfDenied: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// GoogleMap 本体とマーカー・円・ポリライン。
///
/// オーバーレイ側の表示トグル（検索フォーカス・クーポン帯の開閉など）の
/// setState で地図とマーカー群が再構築されないよう、ページから分離している。
class _MapCanvas extends ConsumerWidget {
  final List<ParkingLot> lots;
  final LatLng? currentLocation;
  final BitmapDescriptor? currentLocationIcon;
  final BitmapDescriptor? couponIcon;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onMapTap;

  const _MapCanvas({
    required this.lots,
    required this.currentLocation,
    required this.currentLocationIcon,
    required this.couponIcon,
    required this.onMapCreated,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider).asData?.value ?? const <Store>[];
    final normalizedQuery =
        ref.watch(parkingSearchQueryProvider).trim().toLowerCase();
    final filter = ref.watch(mapFilterProvider);
    final favorites = ref.watch(favoriteParkingsProvider);
    final activeRoute = ref.watch(activeRouteProvider);

    final visibleLots = filterParkingLots(
      lots: lots,
      normalizedQuery: normalizedQuery,
      filter: filter,
      favoriteIds: favorites,
      stores: stores,
      origin: currentLocation ?? ParkingMapPage._initialCamera.target,
    );

    final markers = <Marker>{};
    for (final p in visibleLots) {
      final markerHue = usageMarkerHue(p.usageLevel);
      markers.add(Marker(
        markerId: MarkerId('lot-${p.id}'),
        position: p.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        onTap: () {
          showAppBottomSheet<void>(
            context,
            builder: (_) => ParkingDetailSheet(parking: p),
          );
        },
        infoWindow: InfoWindow(
          title: p.name,
          snippet: '空き ${p.available}/${p.capacity}（稼働${p.usageRatePercent}%）',
        ),
      ));
    }
    for (final s in stores) {
      markers.add(Marker(
        markerId: MarkerId('store-${s.id}'),
        position: s.position,
        icon: couponIcon ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRose,
            ),
        onTap: () {
          showAppBottomSheet<void>(
            context,
            builder: (_) => StorePreviewSheet(store: s),
          );
        },
        infoWindow: InfoWindow(
          title: s.name,
          snippet: '🎁 ${s.benefit}',
        ),
      ));
    }

    if (currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocation!,
          infoWindow: const InfoWindow(title: '現在地'),
          icon: currentLocationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
          zIndexInt: 2,
        ),
      );
    }

    final circles = currentLocation == null
        ? <Circle>{}
        : {
            Circle(
              circleId: const CircleId('current_location_accuracy'),
              center: currentLocation!,
              radius: 25,
              fillColor: AppColors.navigation.withValues(alpha: 0.18),
              strokeColor: AppColors.navigation.withValues(alpha: 0.7),
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

    return GoogleMap(
      initialCameraPosition: ParkingMapPage._initialCamera,
      markers: markers,
      circles: circles,
      polylines: polylines,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      onMapCreated: onMapCreated,
      onTap: (_) => onMapTap(),
    );
  }
}

/// 地図の上に被せる UI（検索バー・フィルタ・インサイト・クーポン帯・現在地ボタン）。
/// 開閉トグルや検索フォーカスの状態はここに閉じる。
class _MapOverlay extends ConsumerStatefulWidget {
  final List<ParkingLot> lots;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final LatLng? currentLocation;
  final ValueChanged<ParkingLot> onParkingSelected;
  final VoidCallback onRecenter;
  final VoidCallback onLocationGranted;

  const _MapOverlay({
    required this.lots,
    required this.searchController,
    required this.searchFocus,
    required this.currentLocation,
    required this.onParkingSelected,
    required this.onRecenter,
    required this.onLocationGranted,
  });

  @override
  ConsumerState<_MapOverlay> createState() => _MapOverlayState();
}

class _MapOverlayState extends ConsumerState<_MapOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _couponStripAnim;
  bool _showCouponStrip = false;
  bool _showMapControls = true;
  bool _showInsightDetails = false;

  @override
  void initState() {
    super.initState();
    _couponStripAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 220),
    );
    widget.searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.searchFocus.removeListener(_onFocusChanged);
    _couponStripAnim.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _openCouponStrip() {
    if (_showCouponStrip) return;
    setState(() => _showCouponStrip = true);
    _couponStripAnim.forward();
  }

  void _closeCouponStrip() {
    if (!_showCouponStrip) return;
    _couponStripAnim.reverse().whenComplete(() {
      if (mounted) setState(() => _showCouponStrip = false);
    });
  }

  void _collapseMapControls() {
    widget.searchFocus.unfocus();
    setState(() {
      _showMapControls = false;
      _showInsightDetails = false;
    });
  }

  void _expandMapControls() {
    setState(() => _showMapControls = true);
  }

  /// プレビュー中の経路をそのまま使ってターンバイターン案内を開始する。
  void _startNavigation(DirectionsRoute route) {
    ParkingLot? found;
    for (final lot in widget.lots) {
      if (lot.id == route.parkingLotId) {
        found = lot;
        break;
      }
    }
    final parking = found;
    if (parking == null) {
      // 経路取得後に駐輪場一覧が更新されて対象が消えた場合。経路も畳んでおく。
      ref.read(activeRouteProvider.notifier).state = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この駐輪場は現在表示できません。もう一度選び直してください。')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationPage(
          parking: parking,
          initialRoute: route,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider).asData?.value ?? const <Store>[];
    final query = ref.watch(parkingSearchQueryProvider);
    final normalizedQuery = query.trim().toLowerCase();
    final filter = ref.watch(mapFilterProvider);
    final favorites = ref.watch(favoriteParkingsProvider);
    final activeRoute = ref.watch(activeRouteProvider);

    final visibleLots = filterParkingLots(
      lots: widget.lots,
      normalizedQuery: normalizedQuery,
      filter: filter,
      favoriteIds: favorites,
      stores: stores,
      origin: widget.currentLocation ?? ParkingMapPage._initialCamera.target,
    );

    final searchActive =
        widget.searchFocus.hasFocus || normalizedQuery.isNotEmpty;
    final showMapControls = _showMapControls || searchActive;
    final couponStripVisible =
        stores.isNotEmpty && !searchActive && _showCouponStrip;
    final couponToggleVisible =
        stores.isNotEmpty && !searchActive && !_showCouponStrip;
    final recenterButtonBottom = couponStripVisible
        ? 154.0
        : couponToggleVisible
            ? 68.0
            : 16.0;

    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: showMapControls
                ? Column(
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
                            Expanded(
                              child: Text(
                                'Bicycle Go',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: context.textPrimary,
                                    ),
                              ),
                            ),
                            if (!searchActive) ...[
                              const SizedBox(width: 10),
                              MapControlsToggle(
                                icon: Icons.keyboard_arrow_up_rounded,
                                label: '検索・条件を隠す',
                                tooltip: '検索と条件を隠す',
                                onTap: _collapseMapControls,
                              ),
                            ],
                          ],
                        ),
                      ),
                      DecoratedBox(
                        decoration: GlassDecoration.light(context, radius: 16),
                        child: TextField(
                          controller: widget.searchController,
                          focusNode: widget.searchFocus,
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
                                      widget.searchController.clear();
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
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: LocationPermissionBanner(
                          onGranted: widget.onLocationGranted,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: MapFilterBar(),
                      ),
                      if (!searchActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: MapInsightCard(
                            visibleLots: visibleLots,
                            stores: stores,
                            referenceLocation: widget.currentLocation ??
                                ParkingMapPage._initialCamera.target,
                            usingFallbackLocation: widget.currentLocation == null,
                            expanded: _showInsightDetails,
                            onToggle: () => setState(
                              () => _showInsightDetails = !_showInsightDetails,
                            ),
                          ),
                        ),
                      if (widget.searchFocus.hasFocus ||
                          normalizedQuery.isNotEmpty)
                        // Flexible で残り高さに合わせてドロップダウンを自動収縮。
                        // キーボードや上部ウィジェットの実寸が読めなくても overflow しない。
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SearchResultsDropdown(
                              query: normalizedQuery,
                              allLots: widget.lots,
                              filteredLots: visibleLots,
                              currentLocation: widget.currentLocation,
                              onTap: widget.onParkingSelected,
                            ),
                          ),
                        ),
                      if (activeRoute != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: RouteBanner(
                            route: activeRoute,
                            onClose: () {
                              ref.read(activeRouteProvider.notifier).state =
                                  null;
                            },
                            onStartNavigation: () =>
                                _startNavigation(activeRoute),
                          ),
                        ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: MapControlsToggle(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: '検索・条件を表示',
                      tooltip: '検索と条件を表示',
                      onTap: _expandMapControls,
                    ),
                  ),
          ),
        ),
        if (!searchActive)
          Positioned(
            right: 16,
            bottom: recenterButtonBottom,
            child: MapFloatingButton(
              icon: Icons.my_location_rounded,
              tooltip: '現在地へ移動',
              onTap: widget.onRecenter,
            ),
          ),
        if (stores.isNotEmpty && !searchActive)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: _showCouponStrip
                ? CouponStripReveal(
                    animation: _couponStripAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: CouponStripToggle(
                              icon: Icons.close,
                              label: '配信中クーポンを隠す',
                              onTap: _closeCouponStrip,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 112,
                          child: CouponPreviewStrip(stores: stores),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: CouponHandle(
                        count: stores.length,
                        onTap: _openCouponStrip,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
