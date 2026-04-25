import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// 位置情報の利用可否をUI向けに集約したステータス。
enum LocationGateStatus {
  /// まだ確認していない（初回起動直後）。
  unknown,

  /// 利用可能（whileInUse / always）。
  granted,

  /// 拒否されたが再リクエスト可能。
  denied,

  /// 「次回から確認しない」相当。設定アプリからの変更が必要。
  deniedForever,

  /// 端末の位置情報サービス自体がオフ。
  serviceDisabled,
}

class LocationPermissionNotifier extends StateNotifier<LocationGateStatus> {
  LocationPermissionNotifier() : super(LocationGateStatus.unknown);

  /// 現在の状態を再評価する（リクエストはしない）。
  Future<LocationGateStatus> refresh() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = LocationGateStatus.serviceDisabled;
      return state;
    }
    state = _map(await Geolocator.checkPermission());
    return state;
  }

  /// 拒否状態であれば再度リクエストする。
  Future<LocationGateStatus> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = LocationGateStatus.serviceDisabled;
      return state;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    state = _map(permission);
    return state;
  }

  /// 端末設定アプリ（アプリ詳細）を開く。
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// 端末の位置情報設定を開く（Android）。
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  LocationGateStatus _map(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationGateStatus.granted;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationGateStatus.denied;
      case LocationPermission.deniedForever:
        return LocationGateStatus.deniedForever;
    }
  }
}

final locationPermissionProvider =
    StateNotifierProvider<LocationPermissionNotifier, LocationGateStatus>(
  (_) => LocationPermissionNotifier(),
);
