import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/parking_lot.dart';
import '../../../core/domain/parking_session.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../nfc/presentation/nfc_lock_sheet.dart';
import '../../points/providers/points_providers.dart';
import '../data/parking_mock_data.dart';

/// NFC 認証シートを開き、成功したらポイント残高を更新して案内スナックバーを出す。
///
/// 認証後の画面遷移は呼び出し元の文脈で変わる（詳細シートを閉じる / ナビを終了する）ため、
/// ここでは行わずセッションを返すだけにしている。null は認証中止・失敗。
Future<ParkingSession?> runParkingAuth(
  BuildContext context,
  WidgetRef ref,
  ParkingLot parking,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final device = mockDevices.firstWhere(
    (d) => d.parkingLotId == parking.id,
    orElse: () => mockDevices.first,
  );

  final session = await showAppBottomSheet<ParkingSession?>(
    context,
    builder: (_) => NfcLockSheet(
      parkingId: parking.id,
      parkingName: parking.name,
      deviceId: device.id,
    ),
  );
  if (session == null) return null;

  // 付与はサーバ(issue_coupons)が15分後に行う。ここでは残高表示を最新化するだけ。
  ref.read(pointsProvider.notifier).refresh();

  final earnSec = ParkingSession.earnThreshold.inSeconds;
  final earnLabel = earnSec >= 60 ? '${earnSec ~/ 60}分' : '$earnSec秒';
  messenger.showSnackBar(
    SnackBar(content: Text('認証完了！$earnLabel後にクーポンが届きます')),
  );
  return session;
}
