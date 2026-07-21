/**
 * クーポン推薦ロジック。
 *
 * アプリ側 lib/core/api/mock_api_client.dart の `_pickStoreWeighted` と
 * 同じアルゴリズム（駐輪場座標 × 距離係数 × recommend_weight）で店舗を選ぶ。
 */

import {
  RECOMMEND_WEIGHT_FLOOR,
  TIER_FAR_METERS,
  TIER_NEAR_METERS,
} from "./constants.ts";
import type { CouponDistanceTier, Store } from "./types.ts";

/** ハバーサイン公式で2点間の距離（メートル）を計算 */
export function distanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const earthRadius = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) ** 2;
  return earthRadius * 2 * Math.asin(Math.sqrt(a));
}

/**
 * 駐輪場座標から重み付きランダムで1店舗を選ぶ。
 *
 * 重み = (1 / (1 + km)) × (recommend_weight + RECOMMEND_WEIGHT_FLOOR)
 *   - 近い店舗ほど大きい
 *   - recommend_weight 0 でもベースラインで選ばれる可能性あり
 *   - ランダムなので毎回同じ店舗にならず、バリエーションが出る
 */
export function pickStoreWeighted(
  parkingLat: number,
  parkingLng: number,
  stores: Store[],
): Store {
  if (stores.length === 0) {
    throw new Error("no stores available for recommendation");
  }

  const weights: number[] = [];
  let sum = 0;
  for (const s of stores) {
    const m = distanceMeters(parkingLat, parkingLng, s.lat, s.lng);
    const km = m / 1000;
    const distanceFactor = 1 / (1 + km);
    const w = distanceFactor * (s.recommend_weight + RECOMMEND_WEIGHT_FLOOR);
    weights.push(w);
    sum += w;
  }

  if (sum <= 0) return stores[0];

  const r = Math.random() * sum;
  let acc = 0;
  for (let i = 0; i < stores.length; i++) {
    acc += weights[i];
    if (r <= acc) return stores[i];
  }
  return stores[stores.length - 1];
}

/** 駐輪場と店舗の距離から tier を決定 */
export function distanceTierFor(
  parkingLat: number,
  parkingLng: number,
  store: Store,
): CouponDistanceTier {
  const m = distanceMeters(parkingLat, parkingLng, store.lat, store.lng);
  if (m < TIER_NEAR_METERS) return "near";
  if (m < TIER_FAR_METERS) return "far";
  return "exchange";
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
