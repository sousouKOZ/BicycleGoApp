import 'package:flutter/material.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/coupons/presentation/coupon_list_page.dart';

class Routes {
  static const home = '/';
  static const coupons = '/coupons';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => HomeShell(),
        coupons: (_) => CouponListPage(),
      };
}
