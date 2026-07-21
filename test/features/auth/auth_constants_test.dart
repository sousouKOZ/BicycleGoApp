import 'package:bicycle_go/features/auth/auth_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('password policy', () {
    test('requires at least 8 characters', () {
      expect(isPasswordPolicyCompliant('abc1234'), isFalse);
    });

    test('requires a letter and a digit', () {
      expect(isPasswordPolicyCompliant('abcdefgh'), isFalse);
      expect(isPasswordPolicyCompliant('12345678'), isFalse);
      expect(isPasswordPolicyCompliant('abcd1234'), isTrue);
    });
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
