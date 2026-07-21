/// 現在セッション中の駐輪場情報（履歴記録・アプリ再起動時の復元に利用）。
/// NFC認証成功時にセットし、セッション終了でクリアする。
class ActiveParkingInfo {
  final String parkingId;
  final String parkingName;
  const ActiveParkingInfo({required this.parkingId, required this.parkingName});
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
