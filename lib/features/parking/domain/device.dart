import 'package:google_maps_flutter/google_maps_flutter.dart';

enum DeviceStatus { idle, detecting, awaitingAuth, measuring, completed, offline }

class Device {
  final String id;
  final String storeId;
  final String parkingLotId;
  final LatLng position;
  final DeviceStatus status;
  final String nfcCode;

  const Device({
    required this.id,
    required this.storeId,
    required this.parkingLotId,
    required this.position,
    required this.status,
    required this.nfcCode,
  });

  Device copyWith({DeviceStatus? status}) => Device(
        id: id,
        storeId: storeId,
        parkingLotId: parkingLotId,
        position: position,
        status: status ?? this.status,
        nfcCode: nfcCode,
      );
}
