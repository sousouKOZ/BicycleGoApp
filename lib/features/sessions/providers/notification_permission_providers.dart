import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_service.dart';

enum NotificationGateStatus {
  unknown,
  granted,
  denied,
}

class NotificationPermissionNotifier
    extends StateNotifier<NotificationGateStatus> {
  NotificationPermissionNotifier() : super(NotificationGateStatus.unknown);

  /// プラットフォームに権限をリクエストし、結果を反映する。
  Future<NotificationGateStatus> request() async {
    final ok = await NotificationService.instance.requestPermissions();
    state = ok ? NotificationGateStatus.granted : NotificationGateStatus.denied;
    return state;
  }

  /// 既存セッションが notifications を予約済みなら granted とみなす簡易マーク。
  void markGranted() {
    state = NotificationGateStatus.granted;
  }

  void markDenied() {
    state = NotificationGateStatus.denied;
  }
}

final notificationPermissionProvider =
    StateNotifierProvider<NotificationPermissionNotifier, NotificationGateStatus>(
  (_) => NotificationPermissionNotifier(),
);
