import 'dart:math' as math;

import '../../features/coupons/domain/coupon.dart';
import '../../features/parking/data/parking_mock_data.dart';
import '../../features/parking/domain/device.dart';
import '../../features/parking/domain/parking_lot.dart';
import '../../features/parking/domain/parking_session.dart';
import '../../features/stores/data/store_mock_data.dart';
import '../../features/stores/domain/store.dart';
import 'api_client.dart';
import 'api_exceptions.dart';

/// In-memoryモック実装。将来HTTP実装に差し替え可能。
class MockApiClient implements ApiClient {
  final Map<String, ParkingSession> _sessions = {};
  final Map<String, List<Coupon>> _userCoupons = {};
  final List<Device> _devices = List.of(mockDevices);
  int _seq = 0;

  static const double _maxGpsMeters = 80.0;

  String _nextId(String prefix) {
    _seq++;
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$_seq';
  }

  Device _findDevice(String deviceId) {
    return _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw DeviceNotFoundException('device $deviceId not found'),
    );
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  @override
  Future<ParkingSession> postParkingDetect({
    required String deviceId,
    required DateTime detectedAt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _findDevice(deviceId);
    ParkingSession? existing;
    for (final s in _sessions.values) {
      if (s.deviceId == deviceId &&
          s.status == ParkingSessionStatus.unauthenticated) {
        existing = s;
        break;
      }
    }
    if (existing != null) {
      return existing;
    }
    final session = ParkingSession(
      id: _nextId('ses'),
      deviceId: deviceId,
      detectedAt: detectedAt,
      status: ParkingSessionStatus.unauthenticated,
    );
    _sessions[session.id] = session;
    return session;
  }

  @override
  Future<ParkingSession> postParkingAuth({
    required String userId,
    required String deviceId,
    required double lat,
    required double lng,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final device = _findDevice(deviceId);

    final distance = _distanceMeters(
      lat,
      lng,
      device.position.latitude,
      device.position.longitude,
    );
    if (distance > _maxGpsMeters) {
      throw GpsMismatchException(
        'スタンドから約${distance.round()}m離れています。現地で再度お試しください。',
      );
    }

    var session = _sessions.values.where((s) =>
        s.deviceId == deviceId &&
        s.status == ParkingSessionStatus.unauthenticated).fold<ParkingSession?>(
      null,
      (prev, s) => (prev == null || s.detectedAt.isAfter(prev.detectedAt))
          ? s
          : prev,
    );

    session ??= ParkingSession(
      id: _nextId('ses'),
      deviceId: deviceId,
      detectedAt: DateTime.now(),
      status: ParkingSessionStatus.unauthenticated,
    );

    final now = DateTime.now();
    if (now.isAfter(session.authDeadline)) {
      _sessions[session.id] = session.copyWith(
        status: ParkingSessionStatus.expired,
      );
      throw const AuthGraceExpiredException(
        '駐輪検知から5分を超えたため、認証を受付できません。',
      );
    }

    final authenticated = session.copyWith(
      userId: userId,
      authenticatedAt: now,
      status: ParkingSessionStatus.measuring,
    );
    _sessions[authenticated.id] = authenticated;
    return authenticated;
  }

  @override
  Future<Coupon?> evaluateEarn({
    required String sessionId,
    required double userLat,
    required double userLng,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final session = _sessions[sessionId];
    if (session == null) {
      throw SessionNotFoundException('session $sessionId not found');
    }
    final earnBy = session.earnDeadline;
    if (earnBy == null || DateTime.now().isBefore(earnBy)) {
      return null;
    }
    if (session.issuedCouponId != null) {
      final owned = _userCoupons[session.userId] ?? const [];
      return owned.firstWhere(
        (c) => c.id == session.issuedCouponId,
        orElse: () => _buildFallbackCoupon(userLat, userLng),
      );
    }

    final coupon = _recommendCoupon(userLat, userLng);
    _sessions[sessionId] = session.copyWith(
      status: ParkingSessionStatus.achieved,
      issuedCouponId: coupon.id,
    );
    final userId = session.userId ?? 'guest';
    final list = _userCoupons.putIfAbsent(userId, () => <Coupon>[]);
    list.insert(0, coupon);
    return coupon;
  }

  Coupon _recommendCoupon(double userLat, double userLng) {
    final store = _pickStoreByDistance(userLat, userLng);
    final distanceM = _distanceMeters(
      userLat,
      userLng,
      store.position.latitude,
      store.position.longitude,
    );
    final tier = distanceM < 200
        ? CouponDistanceTier.near
        : distanceM < 800
            ? CouponDistanceTier.far
            : CouponDistanceTier.exchange;
    final now = DateTime.now();
    return Coupon(
      id: _nextId('cp'),
      storeId: store.id,
      storeName: store.name,
      title: '15分駐輪達成！${store.name}で使える',
      benefit: store.benefit,
      issuedAt: now,
      expiresAt: now.add(const Duration(days: 3)),
      status: CouponStatus.owned,
      distanceTier: tier,
    );
  }

  Store _pickStoreByDistance(double lat, double lng) {
    final stores = List.of(mockStores);
    stores.sort((a, b) {
      final da = _distanceMeters(lat, lng, a.position.latitude, a.position.longitude);
      final db = _distanceMeters(lat, lng, b.position.latitude, b.position.longitude);
      final scoreA = da / (a.recommendWeight + 0.01);
      final scoreB = db / (b.recommendWeight + 0.01);
      return scoreA.compareTo(scoreB);
    });
    return stores.first;
  }

  Coupon _buildFallbackCoupon(double userLat, double userLng) {
    return _recommendCoupon(userLat, userLng);
  }

  @override
  Future<List<Coupon>> getUserCoupons(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return List.of(_userCoupons[userId] ?? const []);
  }

  @override
  Future<Coupon> redeemCoupon({
    required String userId,
    required String couponId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final list = _userCoupons[userId];
    if (list == null) {
      throw const ApiException('not_found', 'user has no coupons');
    }
    final idx = list.indexWhere((c) => c.id == couponId);
    if (idx < 0) {
      throw const ApiException('not_found', 'coupon not found');
    }
    final redeemed = list[idx].copyWith(
      status: CouponStatus.used,
      usedAt: DateTime.now(),
    );
    list[idx] = redeemed;
    return redeemed;
  }

  @override
  Future<Coupon> issueExchangeCoupon({
    required String userId,
    required String exchangeItemId,
    required String displayStoreName,
    required String title,
    required String benefit,
    required Duration validity,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final now = DateTime.now();
    final coupon = Coupon(
      id: _nextId('cp-exch'),
      storeId: 'exchange-$exchangeItemId',
      storeName: displayStoreName,
      title: title,
      benefit: benefit,
      issuedAt: now,
      expiresAt: now.add(validity),
      status: CouponStatus.owned,
      distanceTier: CouponDistanceTier.exchange,
    );
    final list = _userCoupons.putIfAbsent(userId, () => <Coupon>[]);
    list.insert(0, coupon);
    return coupon;
  }

  @override
  Future<ParkingSession> endSession(String sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final session = _sessions[sessionId];
    if (session == null) {
      throw SessionNotFoundException('session $sessionId not found');
    }
    final ended = session.copyWith(
      exitedAt: DateTime.now(),
      status: session.status == ParkingSessionStatus.achieved
          ? ParkingSessionStatus.completed
          : ParkingSessionStatus.completed,
    );
    _sessions[sessionId] = ended;
    return ended;
  }

  @override
  Future<List<ParkingLot>> getParkingLots() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return mockParkingLots;
  }

  @override
  Future<List<Store>> getStores() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return mockStores;
  }

  @override
  Future<ParkingSession?> getActiveSession(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    for (final s in _sessions.values) {
      if (s.userId == userId &&
          (s.status == ParkingSessionStatus.measuring ||
              s.status == ParkingSessionStatus.achieved)) {
        return s;
      }
    }
    return null;
  }
}

