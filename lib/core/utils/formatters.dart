// 画面表示用の共通フォーマッタ。
//
// 「あと」「約」「残り」などの文脈依存の接頭辞は呼び出し側で付ける。

String _two(int n) => n.toString().padLeft(2, '0');

/// 残り時間の表示。`3日 4時間` / `2時間 5分` / `12分`。
/// 負（期限切れ）は `0分`。期限切れ時に別表記にしたい場合は呼び出し側で分岐する。
String formatRemainingCompact(Duration diff) {
  if (diff.isNegative) return '0分';
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  if (days >= 1) return '$days日 $hours時間';
  final minutes = diff.inMinutes % 60;
  if (diff.inHours >= 1) return '${diff.inHours}時間 $minutes分';
  return '${diff.inMinutes}分';
}

/// 距離の表示。1km 以上は `1.2km`、未満は `350m`。
String formatDistanceMeters(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
  return '${meters.round()}m';
}

/// 音声読み上げ用の距離表記。単位を漢字仮名で綴り、TTS が「km」を
/// 「けーえむ」と読んでしまうのを防ぐ（例: `1.2キロメートル` / `350メートル`）。
String formatDistanceSpeech(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)}キロメートル';
  }
  return '${meters.round()}メートル';
}

/// `2026/06/12` 形式。
String formatDate(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}';

/// `2026/06/12 09:05` 形式。
String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

/// `09:05` 形式。
String formatTimeHm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// `6/05` 形式（月はゼロ埋めなし・日はゼロ埋め）。
String formatMonthDay(DateTime d) => '${d.month}/${_two(d.day)}';
