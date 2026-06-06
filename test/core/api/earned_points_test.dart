import 'package:bicycle_go/core/api/supabase_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('earnedPointsFromTransactions', () {
    test('earn トランザクションの delta を返す', () {
      final txs = [
        {'kind': 'earn', 'delta': 10},
      ];
      expect(earnedPointsFromTransactions(txs), 10);
    });

    test('earn 以外（exchange/adjust）は集計に含めない', () {
      final txs = [
        {'kind': 'earn', 'delta': 10},
        {'kind': 'exchange', 'delta': -50},
        {'kind': 'adjust', 'delta': 3},
      ];
      expect(earnedPointsFromTransactions(txs), 10);
    });

    test('複数の earn は合算する', () {
      final txs = [
        {'kind': 'earn', 'delta': 10},
        {'kind': 'earn', 'delta': 5},
      ];
      expect(earnedPointsFromTransactions(txs), 15);
    });

    test('空リストは 0', () {
      expect(earnedPointsFromTransactions(const []), 0);
    });

    test('null は 0（埋め込み無し）', () {
      expect(earnedPointsFromTransactions(null), 0);
    });

    test('List 以外の予期しない型は 0', () {
      expect(earnedPointsFromTransactions('oops'), 0);
      expect(earnedPointsFromTransactions(42), 0);
    });

    test('delta 欠落・null は 0 として扱う', () {
      final txs = [
        {'kind': 'earn'},
        {'kind': 'earn', 'delta': null},
        {'kind': 'earn', 'delta': 7},
      ];
      expect(earnedPointsFromTransactions(txs), 7);
    });

    test('delta が num(double) でも int 化する', () {
      final txs = [
        {'kind': 'earn', 'delta': 10.0},
      ];
      expect(earnedPointsFromTransactions(txs), 10);
    });
  });
}
