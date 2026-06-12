import '../domain/active_parking_info.dart';
import '../domain/coupon.dart';
import '../domain/parking_lot.dart';
import '../domain/parking_session.dart';
import '../domain/session_record.dart';
import '../domain/store.dart';

/// バックエンドとの API 契約。
/// 現行実装は [SupabaseApiClient]（Edge Function + PostgREST）。
/// テストやバックエンド差し替え時はこのインタフェースを実装する。
abstract class ApiClient {
  /// 駐輪検知の送信（Edge Function: parking_detect）。
  /// 本来は IoT デバイス（MCU）が行う処理で、アプリからはデモ用に呼ぶ。
  Future<ParkingSession> postParkingDetect({
    required String deviceId,
    required DateTime detectedAt,
  });

  /// NFC 認証（Edge Function: parking_auth）。
  /// ユーザーはサーバが JWT から解決するため送信するのは機体IDのみ。
  /// 5分猶予超過時は例外を投げる。
  Future<ParkingSession> postParkingAuth({
    required String deviceId,
  });

  /// 自分のクーポン一覧を取得する。
  Future<List<Coupon>> getUserCoupons(String userId);

  /// クーポン消込（スワイプto使用）。
  Future<Coupon> redeemCoupon({
    required String userId,
    required String couponId,
  });

  /// セッション終了（出庫）。
  Future<ParkingSession> endSession(String sessionId);

  /// クーポン獲得画面を確認済みにする。
  /// セッションを `achieved` から `parked` へ進め、サーバ側でも確認済みと
  /// なるようにする。これを呼ばないと起動のたびに獲得画面が再表示される。
  Future<ParkingSession> acknowledgeEarnedCoupon(String sessionId);

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

  /// マップ表示用の空き状況一覧。
  Future<List<ParkingLot>> getParkingLots();

  /// マップ表示用の提携店舗一覧。
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
