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
    // GPS 照合は屋内で誤判定が多いため廃止。スタンドに紐付けた deviceId（NFCタグID）の
    // 一致のみで認証する。本番では IoT 検知イベントの存在を必須化する。
    // lat/lng は将来のフォールバック用に引数だけ温存。
    _findDevice(deviceId);

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
    // 推薦は「駐輪場（スタンド）位置」基準に変更。
    // ユーザー GPS は屋内で揺らぐため、駐輪場座標を使った方が
    // 「停めた駐輪場の近くの店舗」というコンセプトと一致する。
    final device = _findDevice(session.deviceId);
    final origin = device.position;

    if (session.issuedCouponId != null) {
      final owned = _userCoupons[session.userId] ?? const [];
      return owned.firstWhere(
        (c) => c.id == session.issuedCouponId,
        orElse: () =>
            _recommendCoupon(origin.latitude, origin.longitude),
      );
    }

    final coupon = _recommendCoupon(origin.latitude, origin.longitude);
    _sessions[sessionId] = session.copyWith(
      status: ParkingSessionStatus.achieved,
      issuedCouponId: coupon.id,
    );
    final userId = session.userId ?? 'guest';
    final list = _userCoupons.putIfAbsent(userId, () => <Coupon>[]);
    list.insert(0, coupon);
    return coupon;
  }

  Coupon _recommendCoupon(double parkingLat, double parkingLng) {
    final store = _pickStoreWeighted(parkingLat, parkingLng);
    final distanceM = _distanceMeters(
      parkingLat,
      parkingLng,
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

  /// 駐輪場（lat, lng）からの距離 × 推薦重みで重み付きランダム選択。
  ///
  /// - 距離が近い店舗ほど選ばれやすい（distanceWeight = 1 / (1 + km)）
  /// - recommendWeight も乗算
  /// - ランダムなので同じ駐輪場でも毎回同じにはならず、バリエーションが出る
  Store _pickStoreWeighted(double lat, double lng) {
    final weights = <double>[];
    double sum = 0;
    for (final s in mockStores) {
      final meters = _distanceMeters(
          lat, lng, s.position.latitude, s.position.longitude);
      final km = meters / 1000.0;
      // 距離由来の重み（近いほど大きい、1km で半分）
      final distanceFactor = 1.0 / (1.0 + km);
      final w = distanceFactor * (s.recommendWeight + 0.05);
      weights.add(w);
      sum += w;
    }
    if (sum <= 0) {
      return mockStores.first;
    }
    final r = math.Random().nextDouble() * sum;
    double acc = 0;
    for (var i = 0; i < mockStores.length; i++) {
      acc += weights[i];
      if (r <= acc) return mockStores[i];
    }
    return mockStores.last;
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

