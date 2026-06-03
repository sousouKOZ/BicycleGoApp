/**
 * POST /functions/v1/issue_coupons
 *
 * 15分達成判定 + クーポン自律発行のスケジュールジョブ。
 * pg_cron から60秒ごとに呼び出される。
 *
 * 処理:
 *   1. status='measuring' で authenticated_at + 15分 を超えたセッションを抽出
 *   2. 各セッションの駐輪場 → 重み付きランダムで店舗選定
 *   3. クーポン発行 + session を 'achieved' に + 10pt 加算
 *   4. 件数を返す（push 通知は Phase 4 で追加）
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import {
  getCallerUserId,
  isLocalInternalBypassEnabled,
  isServiceRoleRequest,
  serviceClient,
} from "../_shared/supabase.ts";
import {
  EARN_COUPON_VALIDITY_DAYS,
  EARN_POINTS_PER_SESSION,
  EARN_THRESHOLD_PROD_SECONDS,
  EARN_THRESHOLD_DEMO_SECONDS,
} from "../_shared/constants.ts";
import {
  distanceTierFor,
  pickStoreWeighted,
} from "../_shared/recommendation.ts";
import { sendToToken } from "../_shared/fcm.ts";
import type { ParkingLot, Store } from "../_shared/types.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }

  const isInternalJob = isServiceRoleRequest(req) ||
    isLocalInternalBypassEnabled();
  const callerUserId = isInternalJob ? null : await getCallerUserId(req);
  if (!isInternalJob && !callerUserId) {
    return errorResponse(
      401,
      "unauthorized",
      "valid JWT or service_role bearer required",
    );
  }

  const supabase = serviceClient();

  // 1. 達成済み（15分超過 または デモは30秒超過）で未発行の measuring セッションを抽出
  const prodCutoff = new Date(Date.now() - EARN_THRESHOLD_PROD_SECONDS * 1000).toISOString();
  const demoCutoff = new Date(Date.now() - EARN_THRESHOLD_DEMO_SECONDS * 1000).toISOString();
  console.log(`[issue_coupons] prodCutoff=${prodCutoff}, demoCutoff=${demoCutoff}`);

  type SessionRow = { id: string; user_id: string; device_id: string };

  // 1-A. デモ用セッションの抽出（30秒超過）
  let demoQuery = supabase
    .from("parking_sessions")
    .select("id, user_id, device_id")
    .eq("status", "measuring")
    .is("issued_coupon_id", null)
    .not("user_id", "is", null)
    .like("id", "demo-%")
    .lte("authenticated_at", demoCutoff)
    .limit(50);
  if (!isInternalJob) {
    demoQuery = demoQuery.eq("user_id", callerUserId!);
  }
  const { data: demoSessions, error: demoErr } = await demoQuery;

  if (demoErr) {
    console.error("demo sessions query failed", demoErr);
    return errorResponse(500, "internal_error", demoErr.message);
  }

  // 1-B. 本番用セッションの抽出（15分超過）
  let prodSessions: SessionRow[] = [];
  if (isInternalJob) {
    const { data, error: prodErr } = await supabase
      .from("parking_sessions")
      .select("id, user_id, device_id")
      .eq("status", "measuring")
      .is("issued_coupon_id", null)
      .not("user_id", "is", null)
      .not("id", "like", "demo-%")
      .lte("authenticated_at", prodCutoff)
      .limit(50);

    if (prodErr) {
      console.error("prod sessions query failed", prodErr);
      return errorResponse(500, "internal_error", prodErr.message);
    }
    prodSessions = (data ?? []) as SessionRow[];
  }

  // 両方の結果を結合
  const sessions = [
    ...((demoSessions ?? []) as SessionRow[]),
    ...prodSessions,
  ];

  if (!sessions || sessions.length === 0) {
    console.log("[issue_coupons] no eligible sessions found");
    return jsonResponse({ issued: 0, message: "no eligible sessions" }, 200);
  }
  
  console.log(`[issue_coupons] found ${sessions.length} eligible sessions`);

  const typedSessions = sessions;

  // 2. デバイス → 駐輪場 のマップを作成（複数セッションが同じデバイスを使う可能性あり）
  const deviceIds = [...new Set(typedSessions.map((s: SessionRow) => s.device_id))];
  const { data: devices, error: devErr } = await supabase
    .from("devices")
    .select("id, parking_lot_id")
    .in("id", deviceIds);
  if (devErr || !devices) {
    return errorResponse(500, "internal_error", devErr?.message ?? "no devices");
  }
  type DeviceRow = { id: string; parking_lot_id: string };
  const typedDevices = devices as DeviceRow[];
  const deviceToParkingLotId = new Map<string, string>(
    typedDevices.map((d: DeviceRow) => [d.id, d.parking_lot_id]),
  );

  // 3. 駐輪場マスタを取得
  const parkingLotIds = [...new Set(typedDevices.map((d: DeviceRow) => d.parking_lot_id))];
  const { data: parkingLots, error: lotErr } = await supabase
    .from("parking_lots")
    .select("id, name, lat, lng, capacity, occupied, price_yen_per_day, updated_at")
    .in("id", parkingLotIds);
  if (lotErr || !parkingLots) {
    return errorResponse(500, "internal_error", lotErr?.message ?? "no lots");
  }
  const parkingLotMap = new Map<string, ParkingLot>(
    (parkingLots as ParkingLot[]).map((p) => [p.id, p]),
  );

  // 4. 全店舗を1回だけ取得（推薦ロジックで使う）
  const { data: stores, error: storesErr } = await supabase
    .from("stores")
    .select("id, name, category, lat, lng, benefit, recommend_weight");
  if (storesErr || !stores) {
    return errorResponse(500, "internal_error", storesErr?.message ?? "no stores");
  }

  let issued = 0;
  const errors: string[] = [];

  // 「自転車が取り出された」検知は parking_detect (status='exit') が直接セッションを
  // 終了させる。issue_coupons の段階で measuring のままで残っている = まだ自転車が
  // ある と前提できるため、ここでは在席チェックは行わない。
  for (const session of sessions) {
    const parkingLotId = deviceToParkingLotId.get(session.device_id);
    if (!parkingLotId) {
      errors.push(`session ${session.id}: device ${session.device_id} not found`);
      continue;
    }
    const parkingLot = parkingLotMap.get(parkingLotId);
    if (!parkingLot) {
      errors.push(`session ${session.id}: parking lot ${parkingLotId} not found`);
      continue;
    }

    // Python APIを呼び出して店舗を選定
    const pythonApiUrl = Deno.env.get("PYTHON_API_URL") || "http://host.docker.internal:5001";
    const pythonApiKey = Deno.env.get("PYTHON_API_KEY")?.trim();
    const pythonHeaders: Record<string, string> = {
      "Content-Type": "application/json",
    };
    if (pythonApiKey) {
      pythonHeaders.Authorization = `Bearer ${pythonApiKey}`;
    }
    let store: Store | undefined;
    let recommendReason: string | undefined;
    
    try {
      const pyReq = await fetch(`${pythonApiUrl}/api/v2/recommend`, {
        method: "POST",
        headers: pythonHeaders,
        body: JSON.stringify({
          user_id: session.user_id,
          lat: parkingLot.lat,
          lng: parkingLot.lng,
        }),
      });
      if (pyReq.ok) {
        const pyResponse = await pyReq.json();
        const pyRecs = pyResponse.recommendations || [];
        if (pyRecs.length > 0) {
          // スコアの3乗を重みとした確率的ランダム抽選
          let totalWeight = 0;
          const weightedStores = pyRecs.map((r: any) => {
            // pyRecs には score フィールドが含まれる前提。もしなければ0.1とする。
            const weight = Math.pow(r.score || 0.1, 3);
            totalWeight += weight;
            return { ...r, weight };
          });

          let random = Math.random() * totalWeight;
          let selected = weightedStores[0];
          for (const s of weightedStores) {
            random -= s.weight;
            if (random <= 0) {
              selected = s;
              break;
            }
          }

          const topVenueId = selected.venue_id;
          store = (stores as Store[]).find(s => s.id === topVenueId);
          recommendReason = selected.reason;
        }
      } else {
        console.warn(`[issue_coupons] Python API returned ${pyReq.status}`);
      }
    } catch(e) {
      console.error(`[issue_coupons] Python API Error:`, e);
    }
    
    // フォールバック（APIが落ちている、対象が見つからない等）
    if (!store) {
      store = pickStoreWeighted(
        parkingLot.lat,
        parkingLot.lng,
        stores as Store[],
      );
    }

    const tier = distanceTierFor(parkingLot.lat, parkingLot.lng, store);

    const couponId = `cp-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const now = new Date();
    const expiresAt = new Date(
      now.getTime() + EARN_COUPON_VALIDITY_DAYS * 24 * 60 * 60 * 1000,
    );

    // a) クーポン作成
    const { error: couponErr } = await supabase.from("coupons").insert({
      id: couponId,
      user_id: session.user_id,
      store_id: store.id,
      store_name: store.name,
      title: `15分駐輪達成！${store.name}で使える`,
      benefit: store.benefit,
      issued_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      status: "owned",
      distance_tier: tier,
    });
    if (couponErr) {
      errors.push(`session ${session.id}: coupon insert failed: ${couponErr.message}`);
      continue;
    }

    // b) セッションを achieved に（競合防止条件付き UPDATE）
    const { data: updated, error: sessionErr } = await supabase
      .from("parking_sessions")
      .update({
        status: "achieved",
        issued_coupon_id: couponId,
      })
      .eq("id", session.id)
      .eq("status", "measuring")
      .is("issued_coupon_id", null)
      .select("id");
    if (sessionErr || !updated || updated.length === 0) {
      // 既に他プロセスが更新済み → 自分が作ったクーポンは余計なので削除
      await supabase.from("coupons").delete().eq("id", couponId);
      errors.push(
        `session ${session.id}: race condition or update failed (rolled back coupon)`,
      );
      continue;
    }

    // c) ポイント取引履歴
    const { error: txErr } = await supabase.from("point_transactions").insert({
      user_id: session.user_id,
      delta: EARN_POINTS_PER_SESSION,
      kind: "earn",
      related_session_id: session.id,
      note: "15分駐輪達成",
    });
    if (txErr) {
      errors.push(`session ${session.id}: tx insert failed: ${txErr.message}`);
    }

    // d) 残高加算（add_points RPC で原子的に処理 / race condition 対策）
    const { error: pointsErr } = await supabase.rpc("add_points", {
      p_user_id: session.user_id,
      p_delta: EARN_POINTS_PER_SESSION,
    });
    if (pointsErr) {
      errors.push(`session ${session.id}: add_points failed: ${pointsErr.message}`);
    }

    issued += 1;
    console.log(
      `issued ${couponId} for session ${session.id} (store=${store.name}, tier=${tier})`,
    );

    // e) FCM push 送信。fcm_token が未登録 / FCM 未設定なら静かに skip。
    //    送信失敗はログに残すだけで業務処理（クーポン発行）の成功は変えない。
    const { data: userRow, error: userErr } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", session.user_id)
      .maybeSingle();
    if (userErr) {
      console.error(`[FCM] users lookup failed for ${session.user_id}:`, userErr);
    } else {
      const fcmToken = (userRow as { fcm_token: string | null } | null)?.fcm_token;
      if (fcmToken) {
        const ok = await sendToToken(
          fcmToken,
          {
            title: "🎉 クーポンが発行されました！",
            body: `${store.name} で使える特典が届きました`,
          },
          {
            type: "coupon_issued",
            coupon_id: couponId,
            session_id: session.id,
          },
        );
        if (!ok) console.warn(`[FCM] push failed for ${session.user_id}`);
      }
    }
  }

  return jsonResponse({ issued, total: sessions.length, errors }, 200);
});
