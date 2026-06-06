import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/active_parking_info.dart';
import '../domain/coupon.dart';
import '../domain/parking_lot.dart';
import '../domain/parking_session.dart';
import '../domain/session_record.dart';
import '../domain/store.dart';
import 'api_client.dart';
import 'api_exceptions.dart';

/// Supabase バックエンドに接続する [ApiClient] 実装。
///
/// 各メソッドは Edge Function 経由 (POST /functions/v1/...) または
/// PostgREST 直接アクセス (.from(table).select()) を使い分ける:
/// - **書き込み・副作用あり**: Edge Function（業務ロジック・トランザクション）
/// - **単純読み取り**: PostgREST（マスタデータ・自分のクーポン取得）
class SupabaseApiClient implements ApiClient {
  SupabaseApiClient(this._client);

  final SupabaseClient _client;

  // ---- Edge Function 共通呼び出しヘルパー -------------------------------

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _client.functions.invoke(
        functionName,
        body: body ?? const <String, dynamic>{},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is String) {
        // 空 body のケース等
        return <String, dynamic>{};
      }
      throw ApiException(
        'internal_error',
        'unexpected response type from $functionName',
      );
    } on FunctionException catch (e) {
      // Edge Function が 4xx/5xx を返した場合
      _throwForFunctionError(e);
    } catch (e) {
      throw ApiException('internal_error', e.toString());
    }
  }

  /// FunctionException から `errors.ts` の code に対応した例外を投げる。
  Never _throwForFunctionError(FunctionException e) {
    final details = e.details;
    String? code;
    String? message;
    if (details is Map) {
      code = details['code'] as String?;
      message = details['message'] as String?;
    }
    final msg = message ?? e.toString();
    switch (code) {
      case 'device_not_found':
        throw DeviceNotFoundException(msg);
      case 'session_not_found':
        throw SessionNotFoundException(msg);
      case 'auth_grace_expired':
        throw AuthGraceExpiredException(msg);
      case 'no_recent_detection':
        throw NoRecentDetectionException(msg);
      default:
        throw ApiException(code ?? 'internal_error', msg);
    }
  }

  // ---- セッション関連 ---------------------------------------------------

  @override
  Future<ParkingSession> postParkingDetect({
    required String deviceId,
    required DateTime detectedAt,
  }) async {
    final json = await _invoke('parking_detect', body: {
      'deviceId': deviceId,
      'detectedAt': detectedAt.toUtc().toIso8601String(),
      'is_demo': ParkingSession.isDemoMode,
    });
    return _parseSession(json);
  }

  @override
  Future<ParkingSession> postParkingAuth({
    required String deviceId,
  }) async {
    // ユーザーはサーバが JWT から解決するため deviceId のみ送信する。
    final json = await _invoke('parking_auth', body: {
      'deviceId': deviceId,
    });
    return _parseSession(json);
  }

  @override
  Future<ParkingSession> endSession(String sessionId) async {
    final json = await _invoke('end_session', body: {
      'sessionId': sessionId,
    });
    return _parseSession(json);
  }

  @override
  Future<ParkingSession?> getActiveSession(String userId) async {
    final rows = await _client
        .from('parking_sessions')
        .select()
        .eq('user_id', userId)
        .inFilter('status', const ['measuring', 'achieved', 'parked'])
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return _parseSession(rows.first);
  }

  @override
  Future<ActiveParkingInfo?> getParkingForDevice(String deviceId) async {
    // device → parking_lot を1クエリで join 取得
    final row = await _client
        .from('devices')
        .select('parking_lot_id, parking_lots(id, name)')
        .eq('id', deviceId)
        .maybeSingle();
    if (row == null) return null;
    final lot = row['parking_lots'];
    if (lot is! Map<String, dynamic>) return null;
    return ActiveParkingInfo(
      parkingId: lot['id'] as String,
      parkingName: lot['name'] as String,
    );
  }

  @override
  Future<List<SessionRecord>> getSessionHistory(String userId) async {
    // クーポン発行済み（issued_coupon_id が入っている）セッションのみ履歴対象とする。
    // device → parking_lot で駐輪場名、coupons で特典、point_transactions で
    // 実際に付与されたポイント（earn）を1クエリで取得。
    final rows = await _client
        .from('parking_sessions')
        .select(
          'id, authenticated_at, exited_at, status, issued_coupon_id, '
          'devices(parking_lot_id, parking_lots(id, name)), '
          'coupons!parking_sessions_issued_coupon_fk(benefit), '
          'point_transactions(delta, kind)',
        )
        .eq('user_id', userId)
        .not('issued_coupon_id', 'is', null)
        .order('authenticated_at', ascending: false)
        .limit(200);

    final records = <SessionRecord>[];
    for (final r in rows) {
      final device = r['devices'] as Map<String, dynamic>?;
      final lot = device?['parking_lots'] as Map<String, dynamic>?;
      if (lot == null) continue;
      final coupon = r['coupons'] as Map<String, dynamic>?;
      final authAt = r['authenticated_at'] as String?;
      if (authAt == null) continue;
      final exitedAt = r['exited_at'] as String?;
      records.add(SessionRecord(
        id: r['id'] as String,
        parkingId: lot['id'] as String,
        parkingName: lot['name'] as String,
        startedAt: DateTime.parse(authAt),
        completedAt: exitedAt != null
            ? DateTime.parse(exitedAt)
            : DateTime.parse(authAt),
        // サーバが付与した earn トランザクションの delta を真実の源とする。
        earnedPoints: earnedPointsFromTransactions(r['point_transactions']),
        issuedCouponId: r['issued_coupon_id'] as String?,
        couponBenefit: coupon?['benefit'] as String?,
      ));
    }
    return records;
  }

  @override
  Future<void> triggerDemoCouponIssue() async {
    // 戻り値は捨て、 Edge Function を呼び出す
    await _invoke('issue_coupons');
  }

  @override
  Future<List<Store>> getRecommendations(double lat, double lng) async {
    final response = await _invoke('get_recommendations', body: {
      'lat': lat,
      'lng': lng,
    });
    
    final recommendations = response['recommendations'] as List<dynamic>? ?? [];
    return recommendations.map((json) => Store.fromJson(json)).toList();
  }

  // ---- ヘルパー --------------------------------------------------------

  @override
  Future<List<Coupon>> getUserCoupons(String userId) async {
    final rows = await _client
        .from('coupons')
        .select()
        .eq('user_id', userId)
        .order('issued_at', ascending: false);
    return rows.map<Coupon>(_parseCoupon).toList();
  }

  @override
  Future<Coupon> redeemCoupon({
    required String userId,
    required String couponId,
  }) async {
    final json = await _invoke('redeem_coupon', body: {
      'couponId': couponId,
    });
    return _parseCoupon(json);
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
    // displayStoreName / title / benefit / validity はサーバ側 exchange_items
    // テーブルから取られるため送らない。互換のため引数だけ受け取る。
    final json = await _invoke('issue_exchange_coupon', body: {
      'exchangeItemId': exchangeItemId,
    });
    return _parseCoupon(json);
  }

  // ---- マスタ取得 ------------------------------------------------------

  @override
  Future<List<ParkingLot>> getParkingLots() async {
    final rows = await _client.from('parking_lots').select();
    return rows.map<ParkingLot>((r) {
      return ParkingLot(
        id: r['id'] as String,
        name: r['name'] as String,
        position: LatLng(
          (r['lat'] as num).toDouble(),
          (r['lng'] as num).toDouble(),
        ),
        capacity: (r['capacity'] as num).toInt(),
        occupied: (r['occupied'] as num).toInt(),
        priceYenPerDay: (r['price_yen_per_day'] as num).toInt(),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
    }).toList();
  }

  @override
  Future<List<Store>> getStores() async {
    final rows = await _client.from('stores').select();
    return rows.map<Store>((r) {
      return Store(
        id: r['id'] as String,
        name: r['name'] as String,
        category: _parseStoreCategory(r['category'] as String),
        position: LatLng(
          (r['lat'] as num).toDouble(),
          (r['lng'] as num).toDouble(),
        ),
        benefit: r['benefit'] as String,
        recommendWeight: (r['recommend_weight'] as num).toDouble(),
      );
    }).toList();
  }

  // ---- パース --------------------------------------------------------

  DateTime _parseTimestamp(String s) {
    if (!s.endsWith('Z') && !s.contains('+') && !s.contains('-')) {
      s = '${s}Z';
    }
    return DateTime.parse(s).toLocal();
  }

  ParkingSession _parseSession(Map<String, dynamic> r) {
    return ParkingSession(
      id: r['id'] as String,
      deviceId: r['device_id'] as String,
      userId: r['user_id'] as String?,
      detectedAt: _parseTimestamp(r['detected_at'] as String),
      authenticatedAt: r['authenticated_at'] == null
          ? null
          : _parseTimestamp(r['authenticated_at'] as String),
      exitedAt: r['exited_at'] == null
          ? null
          : _parseTimestamp(r['exited_at'] as String),
      status: _parseSessionStatus(r['status'] as String),
      issuedCouponId: r['issued_coupon_id'] as String?,
    );
  }

  Coupon _parseCoupon(Map<String, dynamic> r) {
    return Coupon(
      id: r['id'] as String,
      storeId: r['store_id'] as String,
      storeName: r['store_name'] as String,
      title: r['title'] as String,
      benefit: r['benefit'] as String,
      issuedAt: _parseTimestamp(r['issued_at'] as String),
      expiresAt: _parseTimestamp(r['expires_at'] as String),
      usedAt: r['used_at'] == null
          ? null
          : _parseTimestamp(r['used_at'] as String),
      status: _parseCouponStatus(r['status'] as String),
      distanceTier: _parseDistanceTier(r['distance_tier'] as String),
    );
  }

  ParkingSessionStatus _parseSessionStatus(String s) {
    switch (s) {
      case 'unauthenticated':
        return ParkingSessionStatus.unauthenticated;
      case 'measuring':
        return ParkingSessionStatus.measuring;
      case 'achieved':
        return ParkingSessionStatus.achieved;
      case 'parked':
        return ParkingSessionStatus.parked;
      case 'completed':
        return ParkingSessionStatus.completed;
      case 'expired':
        return ParkingSessionStatus.expired;
      default:
        throw ApiException('internal_error', 'unknown session status: $s');
    }
  }

  CouponStatus _parseCouponStatus(String s) {
    switch (s) {
      case 'distributing':
        return CouponStatus.distributing;
      case 'owned':
        return CouponStatus.owned;
      case 'used':
        return CouponStatus.used;
      case 'expired':
        return CouponStatus.expired;
      default:
        throw ApiException('internal_error', 'unknown coupon status: $s');
    }
  }

  CouponDistanceTier _parseDistanceTier(String s) {
    switch (s) {
      case 'near':
        return CouponDistanceTier.near;
      case 'far':
        return CouponDistanceTier.far;
      case 'exchange':
        return CouponDistanceTier.exchange;
      default:
        throw ApiException('internal_error', 'unknown distance tier: $s');
    }
  }

  StoreCategory _parseStoreCategory(String s) {
    switch (s) {
      case 'cafe':
        return StoreCategory.cafe;
      case 'restaurant':
        return StoreCategory.restaurant;
      case 'bakery':
        return StoreCategory.bakery;
      case 'retail':
        return StoreCategory.retail;
      case 'sweets':
        return StoreCategory.sweets;
      case 'bar':
        return StoreCategory.bar;
      default:
        throw ApiException('internal_error', 'unknown store category: $s');
    }
  }
}

/// 埋め込み取得した point_transactions（PostgREST の to-many embed）から
/// earn 種別の delta を合算して返す。1セッションに通常 earn は1件だが、
/// 調整(adjust)等が混ざる可能性を考慮して kind=='earn' のみを対象にする。
/// 該当が無い・型が想定外なら 0。
int earnedPointsFromTransactions(Object? transactions) {
  if (transactions is! List) return 0;
  var total = 0;
  for (final tx in transactions) {
    if (tx is Map && tx['kind'] == 'earn') {
      total += (tx['delta'] as num?)?.toInt() ?? 0;
    }
  }
  return total;
}
