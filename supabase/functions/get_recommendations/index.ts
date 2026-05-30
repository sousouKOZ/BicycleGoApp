/**
 * POST /functions/v1/get_recommendations
 *
 * Flutter アプリから現在地（lat, lng）を受け取り、
 * Python サーバーのレコメンドAPIへ投げて結果を取得。
 * さらに Supabase の stores テーブルから店舗詳細（benefitなど）をマージして返す。
 */

import { handleCorsPreflight, corsHeaders } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { serviceClient, getCallerUserId } from "../_shared/supabase.ts";
import type { Store } from "../_shared/types.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse(405, "method_not_allowed", "Only POST is allowed");
  }

  try {
    const { lat, lng } = await req.json();

    if (lat === undefined || lng === undefined) {
      return errorResponse(400, "invalid_request", "lat and lng are required");
    }

    // ユーザーIDの取得 (認証されていない場合は 'guest')
    const userId = (await getCallerUserId(req)) || "guest";

    // Python API URL (Docker内からホスト側の5001ポートへアクセス)
    const pythonApiUrl = Deno.env.get("PYTHON_API_URL") || "http://host.docker.internal:5001";

    console.log(`[get_recommendations] Calling Python API for user: ${userId} at ${lat}, ${lng}`);

    // 1. Python レコメンド API を呼び出す
    let pyResponse;
    try {
      const pyReq = await fetch(`${pythonApiUrl}/api/v2/recommend`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: userId,
          lat: lat,
          lng: lng,
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

    // 3. Supabase (PostgreSQL) から店舗詳細データ (benefit 等) を取得
    const supabase = serviceClient();
    const { data: stores, error } = await supabase
      .from("stores")
      .select("*")
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
