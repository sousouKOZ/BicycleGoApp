/**
 * POST /functions/v1/get_recommendations
 *
 * Flutter アプリから現在地（lat, lng）を受け取り、
 * Python サーバーのレコメンドAPIへ投げて結果を取得。
 * さらに Supabase の stores テーブルから店舗詳細（benefitなど）をマージして返す。
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { serviceClient, getCallerUserId } from "../_shared/supabase.ts";

function parseCoordinate(value: unknown, min: number, max: number): number | null {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n) || n < min || n > max) return null;
  return n;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse(405, "method_not_allowed", "Only POST is allowed");
  }

  try {
    const userId = await getCallerUserId(req);
    if (!userId) {
      return errorResponse(401, "unauthorized", "valid JWT required");
    }

    let body: { lat?: unknown; lng?: unknown };
    try {
      body = await req.json();
    } catch {
      return errorResponse(400, "invalid_request", "invalid JSON body");
    }
    const { lat, lng } = body;
    const parsedLat = parseCoordinate(lat, -90, 90);
    const parsedLng = parseCoordinate(lng, -180, 180);

    if (parsedLat == null || parsedLng == null) {
      return errorResponse(
        400,
        "invalid_request",
        "valid lat and lng are required",
      );
    }

    // Python API URL (Docker内からホスト側の5001ポートへアクセス)
    const pythonApiUrl = Deno.env.get("PYTHON_API_URL") || "http://host.docker.internal:5001";
    const pythonApiKey = Deno.env.get("PYTHON_API_KEY")?.trim();
    const pythonHeaders: Record<string, string> = {
      "Content-Type": "application/json",
    };
    if (pythonApiKey) {
      pythonHeaders.Authorization = `Bearer ${pythonApiKey}`;
    }

    // 1. ユーザーの現在所持中のクーポンを集計
    const supabase = serviceClient();
    const { data: ownedCouponsData } = await supabase
      .from("coupons")
      .select("store_id")
      .eq("user_id", userId)
      .eq("status", "owned");
    
    const ownedCouponsMap: Record<string, number> = {};
    if (ownedCouponsData) {
      for (const row of ownedCouponsData) {
        if (!row.store_id || row.store_id.startsWith("exchange-")) continue;
        ownedCouponsMap[row.store_id] = (ownedCouponsMap[row.store_id] || 0) + 1;
      }
    }

    // 2. Python レコメンド API を呼び出す
    let pyResponse;
    try {
      const pyReq = await fetch(`${pythonApiUrl}/api/v2/recommend`, {
        method: "POST",
        headers: pythonHeaders,
        body: JSON.stringify({
          user_id: userId,
          lat: parsedLat,
          lng: parsedLng,
          owned_coupons: ownedCouponsMap,
        }),
      });

      if (!pyReq.ok) {
        throw new Error(`Python API responded with status: ${pyReq.status}`);
      }

      pyResponse = await pyReq.json();
    } catch (e: any) {
      console.error("[get_recommendations] Failed to call Python API:", e);
      // Pythonが落ちている場合は空のリストを返す（フォールバック）
      return jsonResponse({ recommendations: [] }, 200);
    }

    const pyRecs = pyResponse.recommendations || [];
    if (pyRecs.length === 0) {
      return jsonResponse({ recommendations: [] }, 200);
    }

    // 2. Python が返した Venue ID のリストを取得
    const venueIds = pyRecs.map((r: any) => r.venue_id);

    // 4. Supabase (PostgreSQL) から店舗詳細データ (benefit 等) を取得
    const { data: stores, error } = await supabase
      .from("stores")
      .select("id, name, category, lat, lng, benefit, recommend_weight, created_at")
      .in("id", venueIds);

    if (error) {
      console.error("[get_recommendations] Database query failed:", error);
      return errorResponse(500, "internal_error", error.message);
    }

    // 4. Pythonの結果(reason等)とDBの結果をマージし、Pythonのスコア順(元の順序)を維持する
    const storeMap = new Map((stores || []).map(s => [s.id, s]));

    const finalRecommendations = pyRecs
      .filter((pyRec: any) => storeMap.has(pyRec.venue_id))
      .map((pyRec: any) => {
        const dbStore = storeMap.get(pyRec.venue_id)!;
        return {
          ...dbStore,           // DBの全フィールド (id, name, category, lat, lng, benefit, recommend_weight, created_at)
          distance: pyRec.distance,
          recommend_reason: pyRec.reason, // Pythonで計算された「おすすめ理由」
          final_score: pyRec.score,       // Pythonで計算された最終スコア
        };
      });

    return jsonResponse({ recommendations: finalRecommendations }, 200);

  } catch (err: any) {
    console.error("[get_recommendations] Unexpected error:", err);
    return errorResponse(500, "internal_error", err.message);
  }
});
