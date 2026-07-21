import 'package:bicycle_go/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRemainingCompact', () {
    test('1日以上は「n日 n時間」', () {
      expect(
        formatRemainingCompact(const Duration(days: 3, hours: 4, minutes: 5)),
        '3日 4時間',
      );
    });

    test('1時間以上は「n時間 n分」', () {
      expect(
        formatRemainingCompact(const Duration(hours: 2, minutes: 5)),
        '2時間 5分',
      );
    });

    test('1時間未満は「n分」', () {
      expect(formatRemainingCompact(const Duration(minutes: 12)), '12分');
    });

    test('負は「0分」', () {
      expect(formatRemainingCompact(const Duration(minutes: -1)), '0分');
    });
  });

  group('formatDistanceMeters', () {
    test('1km 以上は km 表記（小数1桁）', () {
      expect(formatDistanceMeters(1234), '1.2km');
      expect(formatDistanceMeters(1000), '1.0km');
    });

    test('1km 未満は m 表記（四捨五入）', () {
      expect(formatDistanceMeters(349.6), '350m');
      expect(formatDistanceMeters(0), '0m');
    });
  });

  group('日付・時刻', () {
    final d = DateTime(2026, 6, 5, 9, 7);

    test('formatDate は yyyy/MM/dd', () {
      expect(formatDate(d), '2026/06/05');
    });

    test('formatDateTime は yyyy/MM/dd HH:mm', () {
      expect(formatDateTime(d), '2026/06/05 09:07');
    });

    test('formatTimeHm は HH:mm', () {
      expect(formatTimeHm(d), '09:07');
    });

    test('formatMonthDay は M/dd（月はゼロ埋めなし）', () {
      expect(formatMonthDay(d), '6/05');
      expect(formatMonthDay(DateTime(2026, 11, 3)), '11/03');
    });
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
