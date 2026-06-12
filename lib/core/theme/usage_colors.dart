import 'package:flutter/material.dart';

import '../domain/parking_lot.dart';
import 'app_colors.dart';

/// 稼働率段階（[UsageLevel]）→ 表示色のマッピング。
/// 閾値判定は domain 側（[ParkingLot.usageLevel]）に集約されている。
extension UsageLevelColor on UsageLevel {
  Color get color {
    switch (this) {
      case UsageLevel.high:
        return AppColors.danger;
      case UsageLevel.mid:
        return AppColors.warning;
      case UsageLevel.low:
        return AppColors.success;
    }
  }
}
