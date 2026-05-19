/**
 * POST /functions/v1/parking_detect
 *
 * マイコンから「自転車の入庫/出庫」イベントを受け取る。
 *
 * 入力:  { deviceId, detectedAt, status: "entry"|"exit" }
 *         status を省略した場合は "entry" として扱う（後方互換）。
 * 出力:  status='entry' のとき: 作成または既存の unauthenticated ParkingSession
 *         status='exit' のとき: 終了処理サマリ { terminated: [{id, prev, next}, ...] }
 *
 * 認証: service_role key（マイコンは外部から service_role で叩く想定）。
 *
 * セッション遷移ルール（exit 時）:
 *   unauthenticated → expired   （NFC 認証前に取り出された）
 *   measuring       → expired   （15分達成前に取り出された）
 *   achieved        → completed （クーポン発行済みで取り出した。出庫扱い）
 *   parked          → completed （正規の出庫）
 *   completed / expired         → 何もしない（重複イベント、冪等）
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { serviceClient } from "../_shared/supabase.ts";

interface DetectBody {
  deviceId?: string;
  detectedAt?: string;
  status?: string;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }

  let body: DetectBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "invalid_request", "invalid JSON body");
  }

  const deviceId = body.deviceId?.trim();
  const detectedAt = body.detectedAt;
  const eventStatus = (body.status ?? "entry").toLowerCase();
  if (!deviceId || !detectedAt) {
    return errorResponse(
      400,
      "invalid_request",
      "deviceId and detectedAt are required",
    );
  }
  if (eventStatus !== "entry" && eventStatus !== "exit") {
    return errorResponse(
      400,
      "invalid_request",
      `status must be 'entry' or 'exit' (got '${eventStatus}')`,
    );
  }

  const supabase = serviceClient();

  // デバイス存在確認（共通）
  const { data: device, error: deviceErr } = await supabase
    .from("devices")
    .select("id")
    .eq("id", deviceId)
    .maybeSingle();
  if (deviceErr) {
    console.error("device lookup failed", deviceErr);
    return errorResponse(500, "internal_error", deviceErr.message);
  }
  if (!device) {
    return errorResponse(404, "device_not_found", `device ${deviceId} not found`);
  }

  // 在席タイムスタンプ更新（entry/exit 両方で「最後にマイコンが応答した時刻」として記録）
  await supabase
    .from("devices")
    .update({ last_seen_at: detectedAt })
    .eq("id", deviceId);

  if (eventStatus === "exit") {
    return handleExit(supabase, deviceId, detectedAt);
  }
  return handleEntry(supabase, deviceId, detectedAt);
});

async function handleEntry(
  supabase: ReturnType<typeof serviceClient>,
  deviceId: string,
  detectedAt: string,
): Promise<Response> {
  // 同 deviceId の既存 unauthenticated セッションがあれば返す（重複検知の冪等性）
  const { data: existing, error: existingErr } = await supabase
    .from("parking_sessions")
    .select("*")
    .eq("device_id", deviceId)
    .eq("status", "unauthenticated")
    .order("detected_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existingErr) {
    console.error("existing session lookup failed", existingErr);
    return errorResponse(500, "internal_error", existingErr.message);
  }
  if (existing) {
    return jsonResponse(existing, 200);
  }

  const sessionId = `ses-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
  const { data: created, error: insertErr } = await supabase
    .from("parking_sessions")
    .insert({
      id: sessionId,
      device_id: deviceId,
      detected_at: detectedAt,
      status: "unauthenticated",
    })
    .select("*")
    .single();

  if (insertErr) {
    console.error("session insert failed", insertErr);
    return errorResponse(500, "internal_error", insertErr.message);
  }
  return jsonResponse(created, 201);
}

async function handleExit(
  supabase: ReturnType<typeof serviceClient>,
  deviceId: string,
  detectedAt: string,
): Promise<Response> {
  // この device で「まだ自転車があると思われている」セッションを全て探す。
  // 通常は1件のはずだが、過去のロジックで複数残っている可能性も考慮。
  const { data: actives, error: queryErr } = await supabase
    .from("parking_sessions")
    .select("id, status")
    .eq("device_id", deviceId)
    .in("status", ["unauthenticated", "measuring", "achieved", "parked"]);
  if (queryErr) {
    console.error("active sessions lookup failed", queryErr);
    return errorResponse(500, "internal_error", queryErr.message);
  }

  const terminated: { id: string; prev: string; next: string }[] = [];
  for (const row of actives ?? []) {
    const prev = row.status as string;
    const next = prev === "achieved" || prev === "parked"
      ? "completed"
      : "expired";

    const patch: Record<string, unknown> = { status: next };
    if (next === "completed") {
      patch.exited_at = detectedAt;
    }

    const { error: updateErr } = await supabase
      .from("parking_sessions")
      .update(patch)
      .eq("id", row.id)
      .eq("status", prev); // 楽観ロック: 他プロセスが変えていれば skip
    if (updateErr) {
      console.error(`exit update failed for ${row.id}`, updateErr);
      continue;
    }
    terminated.push({ id: row.id, prev, next });

    // 出庫（completed 遷移）時は parking_lots.occupied を減算
    if (next === "completed") {
      await decrementOccupied(supabase, deviceId);
    }
  }

  return jsonResponse({ terminated }, 200);
}

async function decrementOccupied(
  supabase: ReturnType<typeof serviceClient>,
  deviceId: string,
): Promise<void> {
  // device → parking_lot を引いて occupied を 1 減らす（0 未満にはしない）
  const { data: dev } = await supabase
    .from("devices")
    .select("parking_lot_id")
    .eq("id", deviceId)
    .maybeSingle();
  if (!dev) return;
  const { data: lot } = await supabase
    .from("parking_lots")
    .select("occupied")
    .eq("id", dev.parking_lot_id)
    .maybeSingle();
  if (!lot) return;
  const next = Math.max(0, (lot.occupied as number) - 1);
  await supabase
    .from("parking_lots")
    .update({ occupied: next, updated_at: new Date().toISOString() })
    .eq("id", dev.parking_lot_id);
}
