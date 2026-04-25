import '../../features/coupons/domain/coupon.dart';
import '../../features/parking/domain/parking_lot.dart';
import '../../features/parking/domain/parking_session.dart';
import '../../features/stores/domain/store.dart';

/// Flaskバックエンド仕様（§8.2）に対応するAPI契約。
/// 実装は現状モックだが、インタフェースはHTTP版に差し替え可能なように設計。
abstract class ApiClient {
  /// POST /api/parking/detect
  /// IoTデバイスからの駐輪検知送信を模倣。
  Future<ParkingSession> postParkingDetect({
    required String deviceId,
    required DateTime detectedAt,
  });

  /// POST /api/parking/auth
  /// モバイルアプリからのNFC認証（ユーザID + 機体ID + 端末GPS）。
  /// GPS不一致や5分猶予超過時は例外を投げる。
  Future<ParkingSession> postParkingAuth({
    required String userId,
    required String deviceId,
    required double lat,
    required double lng,
  });

  /// 15分経過判定およびハイブリッド・レコメンド実行。
  /// 達成時、最適なクーポンを発行し session.issuedCouponId に紐付ける。
  Future<Coupon?> evaluateEarn({
    required String sessionId,
    required double userLat,
    required double userLng,
  });

  /// GET /api/user/coupons
  Future<List<Coupon>> getUserCoupons(String userId);

  /// クーポン消込（スワイプto使用）。
  Future<Coupon> redeemCoupon({
    required String userId,
    required String couponId,
  });

  /// セッション終了（出庫）。
  Future<ParkingSession> endSession(String sessionId);

  /// ポイント交換でクーポンを即時発行する。
  /// 駐輪達成と異なり距離スコアに依存せず、保有クーポン（owned）として直ちに利用可能。
  Future<Coupon> issueExchangeCoupon({
    required String userId,
    required String exchangeItemId,
    required String displayStoreName,
    required String title,
    required String benefit,
    required Duration validity,
  });

  /// マップ表示用の空き状況一覧（§7.1）。
  Future<List<ParkingLot>> getParkingLots();

  /// マップ表示用の提携店舗一覧（§7.1）。
  Future<List<Store>> getStores();

  /// 現在のアクティブセッション取得（NFCスキャン直後の計測画面復帰用）。
  Future<ParkingSession?> getActiveSession(String userId);
}
