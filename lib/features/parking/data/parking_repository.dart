import '../domain/parking_lot.dart';
import 'parking_mock_data.dart';

class ParkingRepository {
  Future<List<ParkingLot>> fetchParkingLots() async {
    // プロト：読み込み感のため少し待つ
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return mockParkingLots;
  }
}
