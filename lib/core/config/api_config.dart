/// Directions API 専用のキー。
///
/// ビルド時に `--dart-define-from-file=env/dev.json` 経由で注入する。
/// Maps SDK（地図描画）のキーは iOS/Android ネイティブ側の設定で注入しているため別物。
const directionsApiKey =
    String.fromEnvironment('GOOGLE_DIRECTIONS_API_KEY', defaultValue: '');
