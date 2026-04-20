import 'package:flutter_riverpod/flutter_riverpod.dart';

/// プロトタイプ用の固定ユーザID。
/// バックエンド接続時は認証Tokenから解決する。
final currentUserIdProvider = Provider<String>((ref) => 'user-proto-001');
