import '../domain/active_parking_info.dart';
import '../domain/coupon.dart';
import '../domain/parking_lot.dart';
import '../domain/parking_session.dart';
import '../domain/session_record.dart';
import '../domain/store.dart';

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
  /// モバイルアプリからのNFC認証。ユーザーはサーバが JWT から解決するため
  /// 送信するのは機体IDのみ。5分猶予超過時は例外を投げる。
  Future<ParkingSession> postParkingAuth({
    required String deviceId,
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

  /// デモ用の即時クーポン発行トリガー。
  /// クライアント側でカウントダウンが0になった瞬間に呼び出し、pg_cron の
  /// 最大60秒のラグを待たずに即時発行させる。
  Future<void> triggerDemoCouponIssue();

  /// ユーザーの現在地周辺のおすすめ店舗をPython API(経由)から取得する。
  Future<List<Store>> getRecommendations(double lat, double lng);

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

  /// デバイスID から所属駐輪場の id と name を取得する。
  /// アプリ kill 後の `activeParkingInfoProvider` 復元に使用。
  Future<ActiveParkingInfo?> getParkingForDevice(String deviceId);

  /// 駐輪履歴を取得する。サーバ側 `parking_sessions` を真実の源として
  /// 自分のクーポン発行済みセッションを完了時刻降順で返す。
  Future<List<SessionRecord>> getSessionHistory(String userId);
}
