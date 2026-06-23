/**
 * Edge Function 内で使う DB row の型定義。
 *
 * Supabase からは generated types を使うのが理想だが、初期段階は手書きで進める。
 * テーブル定義の更新時はここも合わせて更新する。
 */

export type CouponStatus = "distributing" | "owned" | "used" | "expired";
export type CouponDistanceTier = "near" | "far" | "exchange";
export type ParkingSessionStatus =
  | "unauthenticated"
  | "measuring"
  | "achieved"
  | "parked"
  | "completed"
  | "cancelled"
  | "expired";
export type StoreCategory =
  | "cafe"
  | "restaurant"
  | "bakery"
  | "retail"
  | "sweets"
  | "bar";

export interface Device {
  id: string;
  store_id: string | null;
  parking_lot_id: string;
  lat: number;
  lng: number;
  status: string;
  nfc_code: string;
}

export interface ParkingSession {
  id: string;
  device_id: string;
  user_id: string | null;
  detected_at: string;
  authenticated_at: string | null;
  exited_at: string | null;
  status: ParkingSessionStatus;
  issued_coupon_id: string | null;
  created_at: string;
}

export interface ParkingLot {
  id: string;
  name: string;
  lat: number;
  lng: number;
  capacity: number;
  occupied: number;
  price_yen_per_day: number;
  updated_at: string;
}

export interface Store {
  id: string;
  name: string;
  category: StoreCategory;
  lat: number;
  lng: number;
  benefit: string;
  recommend_weight: number;
}

export interface Coupon {
  id: string;
  user_id: string;
  store_id: string;
  store_name: string;
  title: string;
  benefit: string;
  issued_at: string;
  expires_at: string;
  used_at: string | null;
  status: CouponStatus;
  distance_tier: CouponDistanceTier;
}
