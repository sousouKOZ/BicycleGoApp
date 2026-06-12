import 'package:bicycle_go/core/api/supabase_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSupabaseTimestamp', () {
    test('Z 付き（UTC）はそのままパースしてローカルに変換', () {
      final result = parseSupabaseTimestamp('2026-06-12T10:50:00Z');
      expect(result.toUtc(), DateTime.utc(2026, 6, 12, 10, 50));
    });

    test('+00:00 オフセット付き（timestamptz の標準形）', () {
      final result = parseSupabaseTimestamp('2026-06-12T10:50:00+00:00');
      expect(result.toUtc(), DateTime.utc(2026, 6, 12, 10, 50));
    });

    test('+09:00 オフセット付き', () {
      final result = parseSupabaseTimestamp('2026-06-12T19:50:00+09:00');
      expect(result.toUtc(), DateTime.utc(2026, 6, 12, 10, 50));
    });

    test('コロン無しオフセット（+0900）も TZ 付きと判定する', () {
      final result = parseSupabaseTimestamp('2026-06-12T19:50:00+0900');
      expect(result.toUtc(), DateTime.utc(2026, 6, 12, 10, 50));
    });

    test('タイムゾーン無しは UTC と見なす（日付部のハイフンに惑わされない）', () {
      // 旧実装は日付部の '-' を TZ 指定子と誤判定し、ローカル時刻として
      // パースしてしまっていた（test_tz.dart で調査されていた問題）。
      final result = parseSupabaseTimestamp('2026-06-12T10:50:00');
      expect(result.toUtc(), DateTime.utc(2026, 6, 12, 10, 50));
    });

    test('小数秒付き・タイムゾーン無しも UTC と見なす', () {
      final result = parseSupabaseTimestamp('2026-06-12T10:50:00.123456');
      expect(result.toUtc(), DateTime.utc(2026, 6, 12, 10, 50, 0, 123, 456));
    });

    test('戻り値はローカル時刻', () {
      final result = parseSupabaseTimestamp('2026-06-12T10:50:00Z');
      expect(result.isUtc, isFalse);
    });
  });
}
