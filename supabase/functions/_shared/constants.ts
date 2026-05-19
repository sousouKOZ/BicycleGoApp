/**
 * BicycleGo ビジネスルール定数
 *
 * アプリ側 (lib/features/parking/domain/parking_session.dart) と
 * 値を同期させること。
 */

/** NFC 認証の猶予時間（秒）— IoT 検知から認証までこの時間を超えると expired */
export const AUTH_GRACE_SECONDS = 5 * 60; // 5分

/**
 * クーポン発行のための駐輪達成しきい値（秒）。
 * デフォルトは 15分。デモ撮影用に環境変数 `EARN_THRESHOLD_SECONDS` で短縮可能。
 * アプリ側 `--dart-define=DEMO=true` と一致させると client/server 両方が短時間で動く。
 */
export const EARN_THRESHOLD_SECONDS = (() => {
  const raw = Deno.env.get("EARN_THRESHOLD_SECONDS");
  if (raw == null) return 15 * 60;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) && n > 0 ? n : 15 * 60;
})();

/** ポイント交換クーポンの有効期間（日） */
export const EXCHANGE_COUPON_VALIDITY_DAYS = 30;

/** 駐輪達成クーポンの有効期間（日） */
export const EARN_COUPON_VALIDITY_DAYS = 3;

/** 駐輪達成1回あたりの付与ポイント */
export const EARN_POINTS_PER_SESSION = 10;

/** 距離 tier の判定値（メートル） */
export const TIER_NEAR_METERS = 200;
export const TIER_FAR_METERS = 800;

/** 推薦時の重み計算で使うベースライン（重み 0 の店舗にも最低限の選択確率） */
export const RECOMMEND_WEIGHT_FLOOR = 0.05;
