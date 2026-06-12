import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/device.dart';

final mockDevices = <Device>[
  Device(
    id: 'd-p1-01',
    storeId: 's1',
    parkingLotId: 'p1',
    position: const LatLng(34.7025, 135.4959),
    status: DeviceStatus.idle,
    nfcCode: 'NFC-UMEDA-01',
  ),
  Device(
    id: 'd-p2-01',
    storeId: 's2',
    parkingLotId: 'p2',
    position: const LatLng(34.7072, 135.5050),
    status: DeviceStatus.idle,
    nfcCode: 'NFC-NAKAZAKI-01',
  ),
  Device(
    id: 'd-p3-01',
    storeId: 's3',
    parkingLotId: 'p3',
    position: const LatLng(34.7050, 135.5120),
    status: DeviceStatus.idle,
    nfcCode: 'NFC-OGIMACHI-01',
  ),
  Device(
    id: 'd-p4-01',
    storeId: 's4',
    parkingLotId: 'p4',
    position: const LatLng(34.7078, 135.5134),
    status: DeviceStatus.idle,
    nfcCode: 'NFC-TENJIN-01',
  ),
  Device(
    id: 'd-p5-01',
    storeId: 's5',
    parkingLotId: 'p5',
    position: const LatLng(34.7000, 135.4930),
    status: DeviceStatus.idle,
    nfcCode: 'NFC-UNIVERSITY-01',
  ),
];
