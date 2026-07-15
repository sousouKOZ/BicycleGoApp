import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// ナビの音声案内。
///
/// ミュートは「発話を止める」のではなく「音量を 0 にする」方式にしている。
/// 案内は常に読み上げに流し続け、ミュートボタンは出力のオン/オフだけを担う
/// （テレビのミュートと同じ挙動）。こうすると解除した瞬間から以降の案内が
/// そのまま聞こえ、「解除したのに戻らない」状態にならない。
///
/// TTS はエンジン未インストール・言語未対応の端末があるため、失敗しても
/// 案内自体は続行できるよう全ての呼び出しを握りつぶす（画面表示は生きている）。
class NavVoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _muted = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(_muted ? 0.0 : 1.0);
      await _tts.setPitch(1.0);
      // 音楽再生中でも案内を割り込ませる（他アプリの音量を一時的に下げる）。
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
      );
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  /// ミュートのオン/オフ。音量だけを変え、再生中の案内は止めない。
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _ensureInitialized();
    try {
      await _tts.setVolume(muted ? 0.0 : 1.0);
    } catch (e) {
      debugPrint('TTS setVolume failed: $e');
    }
  }

  /// 読み上げる。前の読み上げは打ち切る（古い案内が残ると誤誘導になる）。
  /// ミュート中でも発話自体は流す（音量 0 なので聞こえないだけ）。
  Future<void> speak(String text) async {
    await _ensureInitialized();
    try {
      // 直前の setMuted と取りこぼしなく揃えるため、発話ごとに音量を明示する。
      await _tts.setVolume(_muted ? 0.0 : 1.0);
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  /// 案内終了時に読み上げを完全に止める（ナビ画面を閉じたときだけ使う）。
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }
}
