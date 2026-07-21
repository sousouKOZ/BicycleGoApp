/**
 * BicycleGo ビジネスルール定数
 *
 * アプリ側 (lib/features/parking/domain/parking_session.dart) と
 * 値を同期させること。
 */

/** NFC 認証の猶予時間（秒）— IoT 検知から認証までこの時間を超えると expired */
export const AUTH_GRACE_SECONDS = 5 * 60; // 5分

export const EARN_THRESHOLD_PROD_SECONDS = parseInt(Deno.env.get("EARN_THRESHOLD_SECONDS") || "900", 10);
export const EARN_THRESHOLD_DEMO_SECONDS = 30; // 30秒

/** この秒数を超えて駐輪が続くと警告 push を1回送る（デフォルト24h、env で上書き可） */
export const LONG_PARK_WARN_SECONDS = parseInt(
  Deno.env.get("LONG_PARK_WARN_SECONDS") || String(24 * 60 * 60),
  10,
);

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

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
